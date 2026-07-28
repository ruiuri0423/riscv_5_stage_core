# IFU (Instruction Fetch Unit) Design Specification

| 項目 | 內容 |
|---|---|
| 版本 | v1.1(v1.0 → v1.1:移除 skid buffer,RespBuffer 簡化;見 §5.3) |
| 狀態 | 介面凍結,待實作 |
| 適用架構 | 四級管線 IF / ID / EX / WB;EX 單一佔用、變動延遲 |
| 相關文件 | `DOC/BPU_NOTES.md`(BPU 討論記錄;正式 BPU spec 另立) |

---

## 1. Overview

### 1.1 職責範圍

IFU 負責且僅負責下列三件事:

1. 決定下一個取指位址(next-PC 決策)。
2. 透過 AXI AR/R channel 對指令記憶體發出讀取請求並接收回應。
3. 將取回的指令連同預測 metadata 交付 ID。

下列功能明確**不屬於** IFU:預測儲存體與預測決策(BHT/BTB/RAS,屬 BPU)、
誤預測裁決(屬 BPU,於 EX 解析)、管線 flush 的執行(ID/EX 各自處理)。

### 1.2 設計原則

1. **介面全面 ready/valid 化**。
   - 原因:舊架構以全域 freeze 訊號(`nop_insert | ~lsu_ready | csr_hazard`)直接拉線
     進 IF,每新增一個 stall 來源就得動到取指邏輯,且形成跨模組長組合路徑。
   - 做法:下游所有 stall 原因統一收斂於 `if2id_ready` 一隻訊號,由 ID 端聚合;
     IFU 僅依握手協議動作。
   - 結果:IFU 不需要知道下游為何停,stall 來源增減不影響 IFU;
     反壓路徑可控,時序收斂容易。

2. **`ARADDR` 組合路徑僅一層 mux**。
   - 原因:舊架構於回應拍查表,表讀出 → taken 判斷 → next-pc mux → 記憶體位址
     全部擠在同一拍,為 mem interface 的時序瓶頸。
   - 做法:next-pc 的三個來源(redirect / 預測 / 順序)全數改為暫存器輸出(§4)。
   - 結果:位址路徑僅剩一層優先權 mux,查表移出關鍵路徑。

3. **不依賴時序巧合**。
   - 原因:舊架構「flush 脈波拍」與「錯誤路徑指令回應拍」的對齊依賴記憶體固定
     1 拍回應;換上 AXI 變動延遲後此前提不成立,錯誤路徑指令可能在 flush 結束後
     才返回並被誤當有效指令執行。
   - 做法:in-flight 請求以顯式的 `discard` 記帳處理(§5.2)。
   - 結果:任何 R 延遲下,錯誤路徑指令都不會進入管線。

---

## 2. Block Diagram

```
                                  ┌─────────────────────────────┐
                                  │            BPU              │
                                  │  (policy + Bht/Btb/Ras)     │
                                  └───┬───────▲───────────┬─────┘
                             pred_vld │       │ query_vld │ redirect_vld
                             pred_pc  │       │ query_pc  │ redirect_pc
                                      │       │           │ redirect_cause
                                      ▼       │           ▼      ▲ redirect_ready
      ┌───────────────────────────────────────┴──────────────────┴──────┐
      │                              IFU                                │
      │  ┌──────────┐   ┌───────────────────┐   ┌────────────────────┐  │
      │  │  NextPc  │──▶│     FetchAxi      │──▶│    RespBuffer      │  │
      │  │ pc_q/mux │   │ AR/R FSM          │   │ 1-deep skid        │  │
      │  │          │   │ ar_pending        │   │ + pred pairing     │  │
      │  │          │   │ discard           │   │                    │  │
      │  └──────────┘   └───┬───────▲───────┘   └─────────┬──────────┘  │
      └─────────────────────┼───────┼─────────────────────┼─────────────┘
                    AR: ARVALID/ARADDR   R: RVALID/RDATA  │ if2id_vld/payload
                        ARREADY ▲            RRESP        ▼ if2id_ready ▲
                  ┌─────────────┴──────────────┐    ┌──────────────────┴───┐
                  │   Inst. Memory (AXI slave) │    │         IDU          │
                  └────────────────────────────┘    └──────────────────────┘
```

| 子模組 | 職責 |
|---|---|
| `NextPc` | next-pc 優先權選擇、`pc_q` 維護(吸收原 `PcGen`) |
| `FetchAxi` | AR/R 握手 FSM、`ar_pending` 與 `discard` 記帳 |
| `RespBuffer` | R beat 捕捉、1-deep skid、預測 metadata 配對、IF→ID 握手 |

---

## 3. Interface

### 3.1 AXI AR / R Channel(instruction memory master)

| Signal | Dir | Width | 說明 |
|---|---|---|---|
| `ARVALID` | out | 1 | 讀取請求 valid;拉高後至 `ARREADY` 前位址保持穩定 |
| `ARREADY` | in  | 1 | slave 可接受請求 |
| `ARADDR`  | out | 32 | 取指位址(word aligned) |
| `ARPROT`  | out | 3 | 常數 `3'b100`(instruction access) |
| `RVALID`  | in  | 1 | 回應 valid |
| `RREADY`  | out | 1 | `= if2id_ready \| discard`(§5.3;組合,AXI 允許 RREADY 依賴 RVALID) |
| `RDATA`   | in  | 32 | 指令 |
| `RRESP`   | in  | 2 | slave 回報之存取結果;非 `OKAY` 記為 fetch fault(§5.6) |

**協議規則**

- Issue 事件 ≜ `ARVALID & ARREADY`;`pc_q` 僅在此事件更新。
- 單 beat、無 burst、無 ID;未來 I-Cache 需 burst 時升級完整 AXI4,channel 結構不變。
- **Outstanding = 1,且允許「接受 R」與「發下一筆 AR」同拍重疊**:
  - 原因:嚴格的「R 接受後下一拍才能發 AR」會使取指節奏變為每兩拍一次,
    1-cycle memory 下頻寬直接減半;而完全不限 outstanding 則使 discard 與
    預測配對的記帳複雜化,與 EX 單一佔用的整體設計哲學不符。
  - 做法:

    ```
    r_accept = RVALID & RREADY                // 本拍 R beat 完成握手
    ARVALID  = ~ar_pending | r_accept
    ```

    `ar_pending` 採 credit=1 記帳:AR 握手置 1、對應 R beat 握手清 0、
    兩事件同拍發生時維持 1。下游反壓經由「R beat 未被接受 → `r_accept` 不成立
    → 不發新 AR」自然傳遞,無需額外條件。
  - 結果:穩態下每拍皆可取指(頻寬不損);in-flight 恆 ≤ 1,
    discard 記帳退化為 1 bit。註:`RVALID → ARVALID` 為一條組合路徑,
    `RVALID` 為 slave 暫存器輸出、`ARADDR` 全暫存,無組合迴圈。

### 3.2 Inst. Interface(IF → ID)

| Signal | Dir | Width | 說明 |
|---|---|---|---|
| `if2id_vld`   | out | 1 | payload 有效(skid 非空或 R beat passthrough) |
| `if2id_ready` | in  | 1 | ID 可接受;下游所有 stall 原因的唯一匯流點 |
| `pc`          | out | 32 | 指令自身位址(AUIPC / JAL / branch target / resolve 共用) |
| `inst`        | out | 32 | 指令 |
| `pred_taken`  | out | 1 | 該指令被 BPU 預測為 taken |
| `pred_npc`    | out | 32 | 該指令之後 IFU 實際發出的下一個取指位址 |
| `ghist`       | out | 4 | 查表當拍的 speculative history 快照(選配,BPU spec 拍板) |
| `pred_hit`    | out | 1 | 查表當拍 BTB tag hit(選配,BPU spec 拍板) |
| `fault`       | out | 1 | `RRESP != OKAY`(預留,trap 機制完成前 ID 不動作) |

**預測 metadata 隨管線傳遞**

- 原因:誤預測裁決在 EX 進行,需要「當初預測了什麼」;此資訊僅存在於預測當拍。
  舊架構以解析當下回頭讀 IF 活狀態(`inst_pc`)反推,造成 JALR flush 判斷式錯誤、
  非分支誤標 taken 時跳往錯誤位址、taken 分支 target 未驗證三類 bug,
  且在 stall / 變動延遲下時間軸根本對不上。
- 做法:預測當拍將結果拍成快照,放進 payload 隨指令經 ID 打拍傳至 EX;
  ID 不消費、僅轉運。`pred_npc` 定義為「預測路徑上實際發出的下一個取指位址」
  (taken 時為預測目標、not-taken 時為 pc+4)。
- 結果:EX 端 BPU 以單一 32-bit 比較 `actual_npc != pred_npc` 完成裁決,
  一式涵蓋方向錯、target 錯、非分支誤標三種情況,且 `redirect_pc = actual_npc`
  順帶取得;上述三類 bug 結構上不再存在。

`pred_taken` 非裁決必需,保留供 BTB allocate 策略與 mispredict 統計使用。
`ghist` / `pred_hit` 之取捨屬 BPU 範疇,見 `DOC/BPU_NOTES.md` §4 / §6。

### 3.3 BPU Interface(query / response)

| Signal | Dir | Width | 說明 |
|---|---|---|---|
| `query_vld` | out | 1 | = AR issue 事件 |
| `query_pc`  | out | 32 | = `ARADDR` |
| `pred_vld`  | in  | 1 | 查詢後一拍回,兼作 taken:1 = 預測 taken |
| `pred_pc`   | in  | 32 | taken 時之預測目標 |

**Issue 拍查表(而非回應拍)**

- 原因:見 §1.2 原則 2 —— 回應拍查表使表讀出邏輯落在位址關鍵路徑上。
- 做法:AR issue 當拍以 `ARADDR` 送查詢;查表所需輸入僅位址位元與 history,
  與記憶體存取平行進行;BPU 將結果打一拍後回覆。
- 結果:預測仍導向緊接著的下一發(taken 零 bubble),但 next-pc mux 的
  預測輸入為暫存器輸出。

**Query / response 皆不設 ready**

- 原因:表為 FF 實作,讀取埠恆可用;唯一可能「等待」的情境是誤預測當拍
  同時有新查詢 —— 但該查詢屬錯誤路徑,結果將隨 discard 一併作廢,
  等表更新沒有意義。
- 做法:兩方向皆純 valid;讀寫同拍碰撞時讀取端取得舊值(FF 表天然行為)。
- 結果:介面簡化、無握手死角。Caveat:表改為單埠 SRAM 時需重新引入 stall。

**預測結果的產生與消費**:結果於查詢後一拍就緒(不等 R);
其兩個消費點 —— 導向下一發 AR、併入 payload —— 均被 outstanding=1 自然同步至
R beat(下一發 AR 需等 `r_accept`;payload 需與指令資料會合)。
1-cycle memory 下產生與消費同拍,R 延遲拉長時結果於配對暫存器等待,行為不變。

### 3.4 Redirection Interface(→ IFU)

| Signal | Dir | Width | 說明 |
|---|---|---|---|
| `redirect_vld`   | in  | 1 | 來源 hold 至被接受(valid-held) |
| `redirect_pc`    | in  | 32 | 恢復位址 |
| `redirect_cause` | in  | 2 | `00`=MISPREDICT / `01`=TRAP / `10`=MRET / `11`=保留 |
| `redirect_ready` | out | 1 | = 該位址完成 AR issue 之拍 |

**Valid-held 語意取代 hold 暫存器**

- 原因:舊架構為了在管線凍結期間不遺失 redirect,於 IF 內設置五顆 `*_hold`
  暫存器,清除/捕捉條件與 freeze 訊號交纏,分析成本高。
- 做法:改由來源端(BPU)持續拉住 `redirect_vld` 直到 IFU 以 `redirect_ready`
  回應;「保持到被消費」為 valid/ready 協議之內建語意。
- 結果:hold 暫存器全數移除;凍結任意長度皆不遺失請求。

**cause 欄位**:redirect 對 IFU 而言動作皆相同(丟棄投機路徑、自新位址取指),
cause 供未來多來源仲裁(TRAP > MISPREDICT)與 debug/trace 使用,IFU 本身不解讀。
現階段僅 BPU(MISPREDICT)一個來源直連;trap 單元加入時於 IFU 內增設
`RedirectArb` 子模組合流,IFU 主體不變。非 BPU 來源之 redirect 須同步通知 BPU
(spec 狀態恢復,見 `DOC/BPU_NOTES.md` §5)。

### 3.5 其他

| Signal | Dir | Width | 說明 |
|---|---|---|---|
| `boot_addr` | in | 32 | `pc_q` reset 值 |
| `CLK` / `RSTN` | in | 1 | 時脈 / 非同步低有效重置 |

---

## 4. Next-PC 決策

```
next_pc = redirect_vld ? redirect_pc :
          pred_vld     ? pred_pc     : pc_q;     // pc_q reset 值 = boot_addr

AR issue 時:pc_q <= next_pc + 4
```

優先權由高至低:redirect(誤預測恢復,未來 trap 插於其上)→ 預測 taken → 順序。
三個輸入均為暫存器輸出,`ARADDR` 組合路徑僅此一層 mux(§1.2 原則 2 之落實)。

---

## 5. 功能行為

### 5.1 Outstanding 管理

見 §3.1 協議規則;`ar_pending` 為唯一狀態,credit=1 記帳。

### 5.2 In-flight 請求丟棄(discard)

- 原因:redirect 被接受當下,可能有一筆舊路徑的取指請求已發出而資料未返回;
  該筆資料若照常交付,錯誤路徑指令將進入管線。舊架構依賴固定 1 拍延遲
  使「錯誤指令回應拍」與「flush 脈波拍」重合而由 decoder 清除,
  AXI 變動延遲下此依賴失效。
- 做法:redirect 接受當拍,若 `ar_pending=1`(或同拍有尚未消費之 R beat),
  置起 `discard`;下一個 R beat 由 `RREADY = if2id_ready | discard` 強制收下
  但不對 `if2id` 呈現(`if2id_vld` 遮蔽),隨後清除 `discard`。
  同拍一併作廢配對暫存器中 pending 的預測結果(同一清理域)。
- 結果:任何 R 延遲下,錯誤路徑指令皆於 IFU 內攔截;
  ID/EX 的 flush 只需處理「已在管線中」的指令。

### 5.3 RespBuffer(無 skid buffer;v1.1 修訂)

- 原因:全核決策 —— **不新增 skid buffer**。核內介面種類多、payload 寬
  (`if2id` 約 105 bits),skid 需複製整份資料暫存器;而每個 stage 邊界
  原生就有一組管線暫存器(consumer 端)可作為儲存體;本核的 ready 鏈天然短
  (`wb_ready` 恆 1、`ex_ready` 為暫存器輸出),skid 打拍所省有限。
  R channel 的資料保持由 AXI 協議免費提供(slave 必須撐住 RVALID/RDATA
  直到 RREADY),IFU 無需自有回應暫存器。
- 做法:R beat 組合呈現至 `if2id`(payload 由 RDATA + 配對暫存器組成),
  ID 於 fire 當拍以自身管線暫存器捕捉;`RREADY = if2id_ready | discard`(組合)。
  ID 停等時 beat 於 R channel 上 hold,`r_accept` 不成立 → AR 自然節流(§3.1)。
- 結果:較 skid 版少一組寬暫存器與一個狀態,happy path 延遲相同;
  代價為 `if2id_ready → RREADY` 組合鏈穿出 AXI 口、stall 期間 beat 佔用匯流排
  —— 點對點指令口兩者皆無實害。**Skid 自「預設元件」降級為「定點工具」**:
  未來特定邊界 ready 鏈成為 critical path、或 interconnect 共享使匯流排
  佔用有代價時,於該邊界局部加入,介面不變。

### 5.4 預測配對

查表結果(§3.3)存於配對暫存器,與對應 R beat 會合後組成 payload 之
`pred_taken / pred_npc / ghist / pred_hit`;R 延遲 > 1 拍時隨 `ar_pending` 等待。

### 5.5 Reset 行為

`RSTN` 釋放後 `pc_q = boot_addr`、`ar_pending = 0`、skid 空、`discard = 0`,
首拍即可發出第一筆 AR。

### 5.6 Fetch Fault(RRESP)

- 原因:舊架構取指打到未映射位址時永遠等不到回應,PC 產生器 deadlock;
  且缺少 instruction access fault 的產生入口。
- 做法:`RRESP` 由 slave 端驅動(`00`=OKAY、`10`=SLVERR、`11`=DECERR);
  未映射位址由 interconnect / default slave 回 `DECERR`。IFU 將非 OKAY
  記為 payload 之 `fault` bit 傳遞,自身不做其他處置。
- 結果:協議保證每筆請求必有回應,deadlock 消失;`fault` 為未來 trap 機制的
  instruction access fault 來源,trap 完成前 ID 對此 bit 不動作。

---

## 6. 內部狀態

| 狀態 | 寬度 | 說明 |
|---|---|---|
| `pc_q` | 32 | 順序路徑位址;AR issue 時更新為 `next_pc + 4`;reset = `boot_addr` |
| `ar_pending` | 1 | credit=1 記帳:AR 握手置 1、R beat 握手清 0、同拍重疊維持 1 |
| `discard` | 1 | 見 §5.2 |
| `pred_hold` | 1+32(+5) | 與 in-flight fetch 配對之預測結果(§5.4) |

---

## 7. 波形

### 7.1 穩態連續取指(含一次 taken 預測,零 bubble)

![steady](./waveform/ifu_steady.svg)

- T0–T2:順序取指 `A → A+4 → A+8`;每拍 AR issue 同拍以該位址查表。
- T2 查 `A+8` 命中且判 taken → T3 `pred_vld=1`、`pred_pc=T`,next-pc mux 選 `T`;
  順序路徑本亦於 T3 發下一筆,故 taken 預測零 bubble。
- `A+8` 之 R beat 於 T3 返回,與其預測配對:payload `pred_taken=1`、`pred_npc=T`。
- 標註 `1T lookup`:查表結果打一拍,`ARADDR` 組合路徑不含表讀出邏輯。

### 7.2 誤預測 redirect 與 in-flight 丟棄

![redirect](./waveform/ifu_redirect.svg)

- T0–T1:錯誤路徑 `X1 / X2` 取指中;`X1` 於 T1 交付 ID(由 flush 於 ID/EX 清除)。
- T2:`redirect_vld=1`、`redirect_pc=Rpc`、cause=MISPREDICT;redirect 於 mux
  最高優先 → 同拍 AR issue `Rpc`、`redirect_ready=1`。
- 同拍 `X2` 之 R beat 到達 → `discard` 丟棄、`if2id_vld=0`:`X2` 不進 ID。
- T3 起恢復路徑正常交付;誤預測 penalty = 2 拍(1-cycle memory)。

### 7.3 ID 反壓與 AXI 節流(無 skid)

![backpressure](./waveform/ifu_backpressure.svg)

- T1:`I(A)` 到達但 `if2id_ready=0` → `RREADY=0`,beat 由 slave 依 AXI 規則
  hold 於 R channel(RVALID/RDATA 保持穩定);`ar_pending=1` 且 `r_accept`
  不成立 → `ARVALID=0`,AR 自然節流。
- T1–T2:`I(A)` 持續 hold;`if2id_vld` 隨 RVALID 呈現,ID 未收。
- T3:`if2id_ready=1` → `RREADY=1`,`I(A)` 完成握手、ID 同拍捕捉;
  `r_accept` 成立 → **同拍**發出 AR `B`(§3.1 重疊規則)。
- T4 起恢復穩態 back-to-back(`I(B)`、`I(C)`…每拍交付)。
  反壓全程無資料遺失、無重複交付、無額外緩衝。

---

## 8. 設計決策摘要

| # | 決策 | 摘要 |
|---|---|---|
| 1 | 預測 metadata 隨管線走 | 裁決輸入全為打拍對齊的快照,不回讀 IF 活狀態(§3.2) |
| 2 | Issue 拍查表 | 查表移出位址關鍵路徑,taken 零 bubble(§3.3) |
| 3 | BPU query/resp 無 ready | 讀埠恆可用;錯誤路徑查詢必作廢(§3.3) |
| 4 | Redirect valid-held + cause | hold 暫存器移除;trap/mret 預留同通道(§3.4) |
| 5 | Outstanding=1 含同拍重疊 | 頻寬不損、記帳 1 bit(§3.1) |
| 6 | 全核不設 skid buffer(v1.1) | 邊界僅一組管線暫存器;AXI 保持行為為免費儲存;skid 降級為定點工具(§5.3) |
| 7 | RRESP → fault bit | 未映射取指不再 deadlock;trap 入口預留(§5.6) |

---

## 9. 依賴與待辦

- [ ] ID 介面定義(`if2id_ready` 聚合條件、ID→EX payload)—— 下一階段
- [ ] BPU 規格 —— 討論記錄與待拍板事項見 `DOC/BPU_NOTES.md`
- [ ] `AxiMemSlave`:MemoryModel 之 AXI wrapper(sim 用;含 RVALID hold 行為)
- [ ] Trap 單元接入:`RedirectArb`(TRAP > MISPREDICT)、BPU 通知、`fault` 消費

---

*波形以 [RetroWave](https://github.com/ruiuri0423/retrowave) 產生,檔案位於 `DOC/waveform/`。*
