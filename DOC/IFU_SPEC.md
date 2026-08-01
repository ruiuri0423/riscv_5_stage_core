# IFU (Instruction Fetch Unit) Design Specification

| 項目 | 內容 |
|---|---|
| 版本 | **v2.0**(架構改版:雙 Queue 配對取代 skid + 配對暫存器;redirect 改採 **drain-then-flush**;outstanding 由 credit 記帳改為 queue 空間綁定) |
| 對應實作 | `RTL/Four_Stage_Hart/InstructionFetch.v` @ `fa7bf55`、`RTL/Four_Stage_Hart/SyncQueue.v` |
| 狀態 | 控制結構定案;開放項目見 `DOC/TODO.md` §1 |
| 適用架構 | 四級管線 IF / ID / EX / WB;EX 單一佔用、變動延遲 |
| 相關文件 | `DOC/TODO.md`(待辦)、`DOC/BPU_NOTES.md`(BPU 討論記錄)、`DOC/IDU_SPEC.md` |

**v1.2 → v2.0 主要差異**

| 面向 | v1.2 | v2.0 |
|---|---|---|
| 對外緩衝 | 1-deep skid buffer + 預測配對暫存器 | 雙 SyncQueue(`cmd_q` / `data_q`),配對由 FIFO 位置保證 |
| Outstanding | credit = 1 記帳,含同拍重疊 | 由 `cmd_q` 空間綁定,上限 = queue 深度(現為 2) |
| In-flight 丟棄 | `discard` 記帳,邊丟邊抓 | **drain-then-flush**:等 outstanding 歸零才 flush |
| Redirect 通道 | 單一 `redirect_*`(BPU 來源) | `ex2if_*` / `tr2if_*` 雙通道,TRAP 優先 |
| BPU 回應 | 查詢後一拍回(暫存器) | **同拍組合回應** |
| `ghist` | 選配欄位 | 移除 |

---

## 1. Overview

### 1.1 職責範圍

IFU 負責且僅負責下列四件事:

1. 決定下一個取指位址(next-PC 決策)。
2. 透過 AXI AR / R channel 對指令記憶體發出讀取請求並接收回應。
3. 維持「取指請求」與「回應資料」的配對,並將指令連同預測 metadata 交付 ID。
4. 接受 redirect 請求,於安全時點清除投機路徑並自新位址重新取指。

下列功能明確**不屬於** IFU:預測儲存體與預測決策(BHT / BTB / RAS,屬 BPU)、誤預測裁決(於 EX 解析)、管線 flush 的執行(ID / EX 各自處理)、trap 的裁決與 CSR 更新(屬 Trap 單元)。

### 1.2 設計原則

1. **介面全面 ready/valid 化**。
   - 原因:舊架構以全域 freeze 訊號(`nop_insert | ~lsu_ready | csr_hazard`)直接拉線進 IF,每新增一個 stall 來源就得動到取指邏輯,且形成跨模組長組合路徑。
   - 做法:下游所有 stall 原因統一收斂於 `if2id_ready` 一隻訊號,由 ID 端聚合;IFU 僅依握手協議動作。
   - 結果:IFU 不需要知道下游為何停,stall 來源增減不影響 IFU;反壓路徑可控,時序收斂容易。

2. **`ARADDR` 為純暫存器輸出,不含任何 mux**。
   - 原因:舊架構於回應拍查表,表讀出 → taken 判斷 → next-pc mux → 記憶體位址全部擠在同一拍,為 mem interface 的時序瓶頸。
   - 做法:`ARADDR = pc`,直接取 `pc` 暫存器;所有來源選擇(redirect / 預測 / 順序)一律收斂在 `pc` 的次態 `pc_p` 上,即 mux 位於暫存器**之前**而非之後。
   - 結果:AXI 位址端口零組合邏輯,對外時序最乾淨;BPU 表讀出落在 register-to-register 的 `pc → pc_p → pc` 路徑上,不觸及端口(時序預算見 `DOC/TODO.md` BPU-2)。

3. **配對關係由結構保證,不由記帳保證**。
   - 原因:v1.2 以「配對暫存器 + credit 記帳」維持請求與資料的對應,在 ID 反壓、變動延遲、flush 三者交互時角落極多——已實際發生過 credit 同拍還原導致 outstanding 超標、以及配對暫存器被第二筆 R 蓋掉兩類錯誤。
   - 做法:改用兩個等深度 FIFO,AR-time 的 metadata 進 `cmd_q`、R-time 的資料進 `data_q`,同拍一起 pop(§4)。第 N 筆請求恆對應第 N 筆資料。
   - 結果:配對正確性由 FIFO 的順序性直接保證,不需要任何記帳;outstanding 上限亦由 `cmd_q` 空間自然綁定,credit 邏輯整組消失。

4. **不依賴時序巧合;flush 只在安全時點發生**。
   - 原因:舊架構「flush 脈波拍」與「錯誤路徑指令回應拍」的對齊依賴記憶體固定 1 拍回應;換上 AXI 變動延遲後此前提不成立。
   - 做法:採 drain-then-flush——redirect 的 `ready` 定義為「bus 上已無 in-flight 交易」,flush 僅在該條件成立時發生(§5)。
   - 結果:清除動作發生時,不存在任何可能稍後返回的舊路徑資料,新舊路徑不會在 queue 內交錯。

---

## 2. 平台假設

### 2.1 AXI-Lite 讀取子集

單 beat、無 burst、無 ID。未來接 I-Cache 需 burst 時升級為完整 AXI4,channel 結構不變。

### 2.2 時脈與重置

`aclk_if` / `arstn_if` 與 `clk_if` / `rstn_if` 同步(現行計畫為同一時脈域),實作僅使用後者。

### 2.3 每筆 AR 必有 R 回應(關鍵假設)

- 原因:drain-then-flush 以「outstanding 歸零」作為 flush 條件,其**活性完全依賴此假設**。AXI 協定沒有任何取消已發出交易的機制,一筆 AR 若永遠等不到 R,drain 將永遠無法完成,且 hart 內部無邏輯可以自解。
- 做法:要求 interconnect 對未映射位址由 default slave 回 `DECERR`;SoC 層可另加 timeout bridge 對「slave 活著但不回話」代回 `SLVERR`。IFU 內部另建議加設位址範圍檢查,在源頭攔下明顯非法的取指位址(`DOC/TODO.md` IFU-3)。
- 結果:未映射取指轉為 `fault` bit 隨管線傳遞,於 EX commit 產生 instruction access fault trap,走正常 redirect 路徑;deadlock 只在平台違反本假設時才可能發生。

> 註:此類 bus 層死鎖的最後防線是 watchdog,而 watchdog 的有效輸出是 **reset request 而非 interrupt**——interrupt 需取指 handler,而取指走的正是卡死的 master。詳見 `DOC/TODO.md` PLAT-3。

---

## 3. Block Diagram

```
                                ┌──────────────────────────────┐
                                │             BPU              │
                                │   (policy + Bht/Btb/Ras)     │
                                └──▲──────────────────┬────────┘
                    if2bp_query/pc  │                  │ hit / taken / npc
                                    │                  │ (同拍組合回應)
      ┌─────────────────────────────┴──────────────────▼────────────────┐
      │                              IFU                                │
      │   ┌──────────┐                    ┌──────────────────────────┐  │
      │   │  NextPc  │─── pc ────┬───────▶│  cmd_q  (SyncQueue)      │  │
      │   │  pc_p    │           │  wen=  │  {pc, npc, taken, hit}   │──┼─┐
      │   │  mux     │           │ ar_hsk └──────────────────────────┘  │ │
      │   └────▲─────┘           │                                      │ │ 同拍
      │        │                 │        ┌──────────────────────────┐  │ │ pop
      │        │ tr>ex>pred>seq  │  wen=  │  data_q (SyncQueue)      │  │ │
      │        │                 │  r_hsk │  {inst, fault}           │──┼─┤
      │   ┌────┴─────┐           │        └──────────────────────────┘  │ │
      │   │ Drain    │           │                                      │ │
      │   │ ongoing_ │           │  ongoing_cmd = cmd_cnt > data_cnt    │ │
      │   │ cmd      │           │                                      │ │
      │   └────▲─────┘           │                                      │ │
      └────────┼─────────────────┼──────────────────────────────────────┘ │
       ex2if_* │          AR ▼   │   ▲ R                    if2id_* ◀─────┘
       tr2if_* │      ARVALID/ADDR   RVALID/RDATA/RRESP
               │      ARREADY        RREADY = data_q_wok
         ┌─────┴──────┐   ┌──────────────────────┐   ┌────────────────────┐
         │  EX / TRAP │   │ Inst. Mem (AXI slave)│   │        IDU         │
         └────────────┘   └──────────────────────┘   └────────────────────┘
```

| 區塊 | 職責 |
|---|---|
| `NextPc` | `pc_p` 優先權 mux 與 `pc` 暫存器;`ARADDR` 直接取 `pc` |
| `cmd_q` | AR 時點的 metadata FIFO:`{pc, npc, taken, hit}`,寫入事件 = AR 握手 |
| `data_q` | R 時點的資料 FIFO:`{inst, fault}`,寫入事件 = R 握手 |
| `Drain` | `ongoing_cmd = cmd_cnt > data_cnt`,即 bus 上的 outstanding 數;為 redirect 的 `ready` 條件 |

兩個 queue 均為 `SyncQueue`(counter 型同步 FIFO,`OUT_REG = 0`),深度相同。

---

## 4. Interface

### 4.1 AXI-Lite AR / R Channel(instruction memory master)

| Signal | Dir | Width | 說明 |
|---|---|---|---|
| `m_axi_arvalid_if` | out | 1 | `= (state == POWER_ON) & cmd_q_wok & ~tr2if_flush_valid & ~ex2if_flush_valid` |
| `m_axi_arready_if` | in | 1 | slave 可接受請求 |
| `m_axi_araddr_if` | out | 32 | `= pc`(純暫存器輸出,word aligned) |
| `m_axi_arprot_if` | out | 3 | 常數 `3'b101`:instruction access、privileged、secure |
| `m_axi_rvalid_if` | in | 1 | 回應 valid |
| `m_axi_rready_if` | out | 1 | `= data_q_wok`(純暫存器輸出) |
| `m_axi_rdata_if` | in | 32 | 指令 |
| `m_axi_rresp_if` | in | 2 | 非 `OKAY` 記為 fetch fault(§8) |

**協議規則**

- Issue 事件 ≜ `ARVALID & ARREADY`;`pc` 於此事件(或 flush 事件)更新。
- `ARVALID` 拉高後至 `ARREADY` 前,`ARADDR` 恆穩定:`ARADDR = pc`,而 `pc` 僅在 `ar_hsk` 或 flush 時更新,兩者皆與 `ARVALID` 高但未被接受的狀態互斥(flush 當拍 `ARVALID` 被遮蔽)。
- Reset 期間 `ARVALID = 0`:由 `state == SLEEP` 保證(§7)。

**Outstanding 上限 = `cmd_q` 深度**

- 原因:v1.2 的 credit=1 記帳在「AR 握手與 R 握手同拍」時需要特例處理,實作中已發生 credit 誤還原導致實際 outstanding 超標的錯誤;且 credit 深度與緩衝深度是兩套彼此耦合的記帳。
- 做法:取消 credit,直接以 `cmd_q_wok` 作為 `ARVALID` 的必要條件。由於 R 必晚於其 AR,恆有 `data_cnt <= cmd_cnt <= DEPTH`,bus 上的 outstanding = `cmd_cnt - data_cnt <= DEPTH`。
- 結果:記帳邏輯消失,outstanding 上限成為 queue 深度的自然推論;深度可依記憶體延遲自由調整(§9),不需同步修改任何控制邏輯。

### 4.2 Instruction Interface(IF → ID)

| Signal | Dir | Width | 說明 |
|---|---|---|---|
| `if2id_valid` | out | 1 | `= cmd_q_rok & data_q_rok`(兩 queue 皆非空 ⇒ 該筆指令的 metadata 與資料皆已到齊) |
| `if2id_ready` | in | 1 | ID 可接受;下游所有 stall 原因的唯一匯流點 |
| `if2id_pc` | out | 32 | 指令自身位址(AUIPC / JAL / branch target / resolve 共用) |
| `if2id_inst` | out | 32 | 指令 |
| `if2id_taken` | out | 1 | 該指令被 BPU 預測為 taken |
| `if2id_npc` | out | 32 | 該指令之後 IFU 實際發出的下一個取指位址 |
| `if2id_hit` | out | 1 | 查表當拍 BTB tag hit(訓練事件定義所需,見 `DOC/BPU_NOTES.md` §6) |
| `if2id_fault` | out | 1 | `RRESP != OKAY` |

Payload 全部為 queue 記憶體的組合切片(`OUT_REG = 0`),握手後才 pop,不存在交付舊值的可能。

Queue 內的位元配置:

```
cmd_q_wdata  = {araddr, if2bp_npc, if2bp_taken, if2bp_hit}     // 寬度 2*ADDR + 2
data_q_wdata = {rdata, (rresp != OKAY)}                        // 寬度 DATA + 1
```

**預測 metadata 隨管線傳遞**

- 原因:誤預測裁決在 EX 進行,需要「當初預測了什麼」;此資訊僅存在於預測當拍。舊架構以解析當下回頭讀 IF 活狀態(`inst_pc`)反推,造成 JALR flush 判斷式錯誤、非分支誤標 taken 時跳往錯誤位址、taken 分支 target 未驗證三類 bug,且在 stall / 變動延遲下時間軸根本對不上。
- 做法:預測結果於 AR 握手當拍寫入 `cmd_q`,隨指令經 ID 打拍傳至 EX;ID 不消費、僅轉運。`if2id_npc` 定義為「預測路徑上實際發出的下一個取指位址」(taken 時為預測目標、not-taken 時為 `pc + 4`)。
- 結果:EX 端以單一 32-bit 比較 `actual_npc != pred_npc` 完成裁決,一式涵蓋方向錯、target 錯、非分支誤標三種情況,且 `redirect_pc = actual_npc` 順帶取得;上述三類 bug 結構上不再存在。

`if2id_taken` 非裁決必需,保留供 BTB allocate 策略與 mispredict 統計使用。`if2id_hit` 供 BPU 訓練的事件定義對齊使用。

### 4.3 BPU Interface(query / response)

| Signal | Dir | Width | 說明 |
|---|---|---|---|
| `if2bp_query` | out | 1 | `= ar_hsk`;僅為 strobe,供 BPU 更新 speculative 狀態 |
| `if2bp_pc` | out | 32 | `= ARADDR`(= `pc`) |
| `if2bp_hit` | in | 1 | BTB tag hit |
| `if2bp_taken` | in | 1 | 方向預測 |
| `if2bp_npc` | in | 32 | hit & taken 時之預測目標 |

**Issue 拍查表、同拍組合回應**

- 原因:回應拍查表會使表讀出邏輯落在位址關鍵路徑上(v1.2 原則);而查詢後打一拍再回,則預測結果會落後於它要導向的那一發 AR,需要額外的對齊機制。
- 做法:以 `pc` 為索引直接組合讀出,結果於同拍被兩處消費——`pc_p` 的預測輸入,以及 `cmd_q` 的寫入資料。`if2bp_query` 不參與讀出路徑,僅通知 BPU「這一拍的查詢確實發出了」。
- 結果:預測導向緊接著的下一發 AR(taken 零 bubble),且預測結果與其指令天然同筆寫入 `cmd_q`,配對零成本。代價是 `pc → BPU 表 → pc_p → pc` 成為 IFU 最長路徑,因此 BPU 儲存體須為 FF 實作;此路徑不觸及 `ARADDR`,對外時序不受影響。

**Query / response 皆不設 ready**:表為 FF 實作,讀取埠恆可用。Caveat:表改為單埠 SRAM 時本節設計失效,需重新引入等待機制。

### 4.4 Redirection Interface(EX / Trap → IFU)

| Signal | Dir | Width | 說明 |
|---|---|---|---|
| `ex2if_valid` | in | 1 | 來源 hold 至被接受(valid-held) |
| `ex2if_ready` | out | 1 | `= !ongoing_cmd`(drain 完成) |
| `ex2if_flush` | in | 1 | 1 = 本次 redirect 需清除投機路徑 |
| `ex2if_pc` | in | 32 | 恢復位址 |
| `ex2if_cause` | in | 2 | `00`=MISPREDICT / `01`=TRAP / `10`=MRET / `11`=保留 |
| `tr2if_*` | in/out | 同上 | Trap 通道,欄位定義相同 |

```
ex2if_flush_valid = ex2if_valid & ex2if_ready & ex2if_flush
tr2if_flush_valid = tr2if_valid & tr2if_ready & tr2if_flush
```

**雙通道與優先權**:Trap 優先於 mispredict。兩者同拍成立時 `pc_p` 取 `tr2if_pc`,而 `ex2if_ready` 仍回 1——即 EX 的請求被一併吸收。此為**刻意行為**:trap 會清除包含該誤預測指令在內的整條投機路徑,其 redirect 已無意義,吸收後 EX 不需重送。

**`cause` 欄位**:redirect 對 IFU 而言動作皆相同(清空 queue、自新位址取指),`cause` 供 debug / trace 與未來多來源仲裁使用,IFU 本身不解讀。非 EX 來源之 redirect 須同步通知 BPU 做 spec 狀態恢復(見 `DOC/BPU_NOTES.md` §5)。

**Valid-held 語意取代 hold 暫存器**

- 原因:舊架構為了在管線凍結期間不遺失 redirect,於 IF 內設置五顆 `*_hold` 暫存器,清除 / 捕捉條件與 freeze 訊號交纏,分析成本高。
- 做法:改由來源端持續拉住 `*_valid` 直到 IFU 以 `*_ready` 回應;「保持到被消費」為 valid/ready 協議之內建語意。本設計中 `ready` 需等 drain 完成,反壓可達數拍,故來源端的 hold 責任是**強制性 contract**(`DOC/TODO.md` EX-1)。
- 結果:hold 暫存器全數移除;等待任意長度皆不遺失請求。

### 4.5 其他

| Signal | Dir | Width | 說明 |
|---|---|---|---|
| `r_BOOT_ADDR` | in | 32 | boot 位址,於 `SLEEP` 拍載入 `pc` |
| `clk_if` / `rstn_if` | in | 1 | 時脈 / 非同步低有效重置 |
| `aclk_if` / `arstn_if` | in | 1 | AXI 時脈 / 重置(現行計畫與上者同步,實作未使用) |

---

## 5. 請求 / 回應配對

配對由兩個等深度 FIFO 的順序性保證,不使用任何記帳:

| 事件 | 動作 |
|---|---|
| AR 握手 | `cmd_q` 寫入 `{pc, npc, taken, hit}` |
| R 握手 | `data_q` 寫入 `{inst, fault}` |
| `if2id` 握手 | 兩個 queue **同拍** pop(`cmd_q_ren = data_q_ren = if2id_hsk`) |
| flush | 兩個 queue **同拍**清空(`cnt` / `rptr` / `wptr` 歸零) |

由於 AR 順序即 R 順序(單 ID、無亂序),`cmd_q` 的第 N 筆恆對應 `data_q` 的第 N 筆。`if2id_valid = cmd_q_rok & data_q_rok` 的語意即「隊首那筆的 metadata 與資料都到齊了」。

ID 反壓時兩個 queue 各自堆積至滿,`ARVALID` 由 `cmd_q_wok` 自動關閉、`RREADY` 由 `data_q_wok` 自動關閉,反壓自然向上游傳遞,無需額外邏輯。

**結構不變式:`data_q` 永不溢位。** 由 `outstanding = cmd_cnt - data_cnt` 可得

```
data_cnt + outstanding == cmd_cnt <= DEPTH
```

即「已在 `data_q` 內的筆數」加上「在 bus 上的筆數」恆不超過深度——`data_q` 對所有 in-flight 的 R beat 恆有空位。因此 `RREADY` 雖會因 `data_q` 填滿而拉低(見 §11.3 T3–T5),**該時點必然沒有任何 in-flight 的 R**,R channel 實際上從不被真正反壓。

此不變式的前提是兩個 queue 深度相同。`RREADY = data_q_wok` 在此前提下等價於常數 1,保留寫法是防禦性的:深度若日後不對稱,行為自動維持正確。

---

## 6. Next-PC 決策

```verilog
pc_p = tr2if_flush_valid ? tr2if_pc  :          // 1. Trap redirect
       ex2if_flush_valid ? ex2if_pc  :          // 2. Mispredict redirect
       (if2bp_hit & if2bp_taken) ? if2bp_npc :  // 3. 預測 taken
                            pc + 'd4;           // 4. 順序

pc <= (state == SLEEP)                                ? r_BOOT_ADDR :
      (ar_hsk | tr2if_flush_valid | ex2if_flush_valid) ? pc_p : pc;
```

優先權由高至低:Trap → Mispredict → 預測 taken → 順序。

**更新事件**為 AR 握手**或** flush 成立。加入 flush 事件是關鍵——flush 當拍 `ARVALID` 被遮蔽故不會有 AR 握手,若只在 `ar_hsk` 更新,redirect 位址將無處可存,下一拍會從舊的錯誤路徑位址繼續取指。

`ARADDR = pc` 為純暫存器輸出,mux 位於暫存器之前(§1.2 原則 2)。

---

## 7. Redirect:Drain-then-Flush

### 7.1 機制

```verilog
ongoing_cmd = cmd_q_cnt > data_q_cnt;   // = bus 上的 outstanding 交易數
ex2if_ready = !ongoing_cmd;
tr2if_ready = !ongoing_cmd;
```

- 原因:redirect 被接受時若 bus 上尚有已發出、未返回的舊路徑 AR,清空 queue 後該筆 R 仍會返回並寫入已清空的 `data_q`,與 redirect 之後才進 `cmd_q` 的新 entry 配對——結果是「新路徑的 PC / 預測 metadata」配上「舊路徑的指令」,交付 ID 的是一筆完全錯誤且無法被下游識別的指令。這是 v1.2 的 `discard` 記帳想解決的問題,但記帳版本在多筆 in-flight、flush 與 R 同拍、queue 滿等組合下角落極多。
- 做法:把「等待 in-flight 排空」直接做成 redirect channel 的反壓。`cmd_cnt` 於 AR 握手加、`data_cnt` 於 R 握手加,兩者於 `if2id` 握手同時減,故其差值恆等於 bus 上的 outstanding 數。`ready` 僅在差值為 0 時拉高,即**flush 只可能發生在 bus 上沒有任何 in-flight 交易的時點**。
- 結果:flush 當下不存在任何可能稍後返回的資料,清空即乾淨;不需要 `discard` 計數、不需要區分新舊 R beat。代價是 redirect 需等待最多一次記憶體延遲的時間,計入 mispredict penalty。

### 7.2 配套條件

三者缺一則機制不成立:

1. **drain 期間 `ARVALID` 遮蔽**:`ARVALID` 含 `~tr2if_flush_valid & ~ex2if_flush_valid`,確保 flush 當拍不發出新 AR——否則該筆 AR 已上 bus 而其 `cmd_q` entry 被同拍的 flush 清掉,配對再度錯位。
2. **drain 期間 `RREADY` 維持**:`RREADY = data_q_wok` 與 redirect 無關,R 照常接收,outstanding 才會下降,drain 才會結束。
3. **來源端 valid-held**:見 §4.4 與 `DOC/TODO.md` EX-1。

### 7.3 正確性論證

**(a) flush 當拍必無 in-flight。** `flush_valid` 需 `ready = !ongoing_cmd`,即 `cmd_cnt == data_cnt`(皆為暫存值),代表所有已發出的 AR 都已收到 R 並寫入 `data_q`。

**(b) R 與 redirect 同拍到達不會漏。** 該拍 `cmd_cnt > data_cnt`(暫存值尚未計入本拍的 R)⇒ `ready = 0` ⇒ redirect 多等一拍;下一拍計數追平,flush 成立,而剛寫入的那筆錯誤路徑 entry 被 queue flush 一併清除。

**(c) flush 與 AR 握手互斥。** `flush_valid` 成立當拍 `ARVALID` 被遮蔽,故不存在同拍的 `ar_hsk`,`pc` 的更新來源無歧義。

**(d) drain window 必然出現(活性)。** `cmd_q` 深度將 in-flight 上限鎖在 `DEPTH`,滿了即停發 AR;在平台假設 §2.3 下 R 必然持續返回,`data_cnt` 必然追平 `cmd_cnt`。ID 若持續反壓,兩個 queue 填滿後同樣得到 `cmd_cnt == data_cnt` 的 window。唯一等不到的情況是平台違反 §2.3。

### 7.4 已知限制

`if2id_valid` 目前未含 flush 條件,flush 當拍仍可能將錯誤路徑指令交付 ID,正確性轉而依賴 IDU 的「同一時脈邊 flush 優先於握手寫入」。詳見 `DOC/TODO.md` IFU-1 / IDU-1。

drain 等待期間 IFU 仍持續交付錯誤路徑指令給 ID(這些指令必須不造成任何架構狀態改變),對應 contract 見 `DOC/TODO.md` EX-2。

---

## 8. Boot 與 Fetch Fault

### 8.1 Boot

```
SLEEP ──(任一時脈邊)──▶ POWER_ON
```

`state` 於 reset 為 `SLEEP`,釋放後第一個時脈邊即轉 `POWER_ON`,同一邊 `pc <= r_BOOT_ADDR`。因此 `state == POWER_ON` 的首拍 `pc` 已等於 boot 位址,可立即發出第一筆 AR。`SLEEP` 期間 `ARVALID = 0`,滿足 AXI「reset 期間 VALID 必須為低」的規則。

### 8.2 Fetch Fault(RRESP)

- 原因:舊架構取指打到未映射位址時永遠等不到回應,PC 產生器 deadlock;且缺少 instruction access fault 的產生入口。
- 做法:`RRESP` 由 slave 端驅動(`00`=OKAY、`10`=SLVERR、`11`=DECERR);未映射位址由 interconnect / default slave 回 `DECERR`。IFU 將非 OKAY 記為 `data_q` 內的 `fault` bit 隨指令傳遞,自身不做其他處置。
- 結果:協議保證每筆請求必有回應,deadlock 消失(§2.3);`fault` 於 EX commit 轉為 instruction access fault trap,經 `tr2if` 通道 redirect 至 `mtvec`。

---

## 9. 效能

### 9.1 深度與吞吐

`SyncQueue` 的 `rok` / `wok` 均由**已暫存**的 `cnt` 產生,因此:寫入的 entry 需下一拍才可讀、釋放的 slot 需下一拍才可寫,兩者各消耗一格深度。在記憶體讀取延遲 `L` 下維持 1 IPC 的條件為

```
DEPTH >= L + 2
```

現況 `DEPTH = 2`、`L = 1`,差一格,穩態呈現 **3 拍交付 2 筆(2/3 IPC)**:

| 拍 | `cmd_cnt` | `data_cnt` | AR | R | `if2id` pop |
|---|---|---|---|---|---|
| T4 | 1 | 0 | A3 | R(A2) | ✗(`data_rok` 暫存值為 0) |
| T5 | 2 | 1 | ✗(`wok = 0`) | R(A3) | ✓ |
| T6 | 1 | 1 | A4 | — | ✓ |
| T7 | 1 | 0 | A5 | R(A4) | ✗ |

改善方式擇一,見 `DOC/TODO.md` IFU-2:兩個 queue 同步加深至 `L + 2`;或將 `rok` / `wok` 改由 `cnt_n` 前視(可省一格深度)。

### 9.2 Redirect Penalty

自 `*_valid` 拉起至恢復路徑第一筆指令交付 ID,約為

```
drain 等待(≤ L 拍) + 1 拍 flush + L 拍取指延遲 + 1 拍 queue 讀出
```

`L = 1` 時典型為 4 拍。drain 等待是本架構相對 `discard` 方案多付的成本,換得的是新舊路徑資料不會交錯。若要壓縮,可採 `DOC/TODO.md` IFU-4(以 redirect *pending* 而非 accepted 遮蔽 `ARVALID`),讓 drain window 提早到來。

---

## 10. 內部狀態

| 狀態 | 寬度 | 說明 |
|---|---|---|
| `state` | 1 | `SLEEP` / `POWER_ON`;僅用於 boot 載入與 `ARVALID` 遮蔽 |
| `pc` | 32 | 取指位址暫存器;`ARADDR` 直接取用 |
| `cmd_q` | (2·ADDR+2) × DEPTH | AR 時點 metadata FIFO |
| `data_q` | (DATA+1) × DEPTH | R 時點資料 FIFO |

IFU 本身不再持有任何記帳暫存器(`ar_pending`、`discard`、`pred_hold` 於 v2.0 全數移除),outstanding 資訊由兩個 queue 的 `cnt` 差值推得。

---

## 11. 波形

### 11.1 穩態連續取指(顯示 2/3 IPC 節奏)

![steady](./waveform/ifu_steady.svg)

- T0–T1:`cmd_q` 未滿,連續發出 A0 / A1;R(A0) 於 T1 返回寫入 `data_q`。
- T1:`data_cnt` 暫存值仍為 0 ⇒ `if2id_valid = 0`,寫入的 entry 下一拍才可讀(標註 `rok is registered: +1T`,即 §9.1 兩格損耗之一)。
- T2:`cmd_cnt = 2` ⇒ `cmd_q_wok = 0` ⇒ `ARVALID = 0`,**AR 節流一拍**(§9.1 損耗之二);同拍交付 A0。
- T4:發出 A3 的同拍 BPU 組合回應 `taken = 1`、`npc = T`,`pc` 於本拍末更新為 `T`(taken 零 bubble——下一次 AR 即為 `T`),同時該預測隨 A3 一併寫入 `cmd_q`。
- T6:A3 交付 ID,`if2id_taken = 1`、`if2id_npc = T` 隨之送出(標註 `prediction rides cmd_q`),供 EX 以單一比較完成裁決。
- T3–T7:穩態呈 3 拍週期,每 3 拍交付 2 筆(2/3 IPC,§9.1)。

### 11.2 Drain-then-Flush Redirect

![redirect](./waveform/ifu_redirect.svg)

- T0–T1:錯誤路徑 X0 / X1 取指中。
- T2:EX 拉起 `ex2if_valid`(mispredict);此時 `cmd_cnt(2) > data_cnt(1)` ⇒ `ongoing_cmd = 1` ⇒ `ex2if_ready = 0`,**redirect 被反壓**;同拍 X0 仍交付 ID(由 ID 的 flush 清除)。
- T3:R(X1) 已於 T2 返回,計數追平 ⇒ `ongoing_cmd = 0` ⇒ `ex2if_ready = 1`,`flush_valid` 成立:兩 queue 清空、`ARVALID` 遮蔽、`pc <= Rpc`。同拍 `if2id_valid` 仍為高(標註 `IFU-1: not masked`),此即 §7.4 的已知限制。
- T4 起:自 `Rpc` 重新取指;T6 交付恢復路徑第一筆指令。penalty = 4 拍。

### 11.3 ID 反壓

![backpressure](./waveform/ifu_backpressure.svg)

- T2:`if2id_ready = 0`,`data_q` 收下 R(A1) 後填滿;`cmd_q` 早於 T2 已滿 ⇒ `ARVALID = 0`。
- T3–T5:`data_q_wok = 0` ⇒ `RREADY = 0`(純暫存器輸出)。注意此期間 `RVALID` 恆為低——依 §5 的結構不變式,`data_q` 滿的時點必然沒有 in-flight 的 R,故 `RREADY` 拉低不會真的擋住任何 beat。
- T5:`if2id_ready` 回高,A0 交付,兩 queue 各釋放一格。
- T6 起:`ARVALID` / `RREADY` 回高,恢復取指。全程無資料遺失、無重複交付。

---

## 12. 設計決策摘要

| # | 決策 | 摘要 |
|---|---|---|
| 1 | 雙 Queue 配對取代記帳 | 配對由 FIFO 順序性保證,credit / `discard` / 配對暫存器全數移除(§1.2-3、§5) |
| 2 | Outstanding = queue 深度 | `ARVALID` 由 `cmd_q_wok` 綁定,深度可自由調整(§4.1) |
| 3 | Drain-then-flush | flush 只發生在 outstanding = 0 的時點,新舊路徑不交錯(§7) |
| 4 | `ARADDR` 為純暫存器輸出 | mux 置於暫存器之前,對外端口零組合邏輯(§1.2-2、§6) |
| 5 | BPU 同拍組合查表 | taken 零 bubble、預測與指令天然同筆入 queue;代價為 BPU 須 FF 實作(§4.3) |
| 6 | Redirect 雙通道 + valid-held | TRAP > MISPREDICT;同拍時 EX 請求被吸收;hold 暫存器移除(§4.4) |
| 7 | `RRESP` → `fault` bit | 未映射取指不再 deadlock;instruction access fault 入口(§8.2) |
| 8 | 對外緩衝由 `data_q` 承擔 | `RREADY` 為純暫存器輸出、資料落入 queue 記憶體;v1.2「對外設 skid」原則以 queue 形式落實,獨立 SkidBuffer 元件不再需要(§5) |

---

## 13. 跨模組 Contract(必須落實)

| # | 對象 | 內容 | 追蹤 |
|---|---|---|---|
| C1 | EX / Trap | `*_valid` 拉起後須保持至 `*_ready` 回應,期間 `pc` / `cause` / `flush` 不得變動 | `TODO.md` EX-1 |
| C2 | EX | 自偵測到 mispredict / trap 起壓住 `id2ex_ready`,直到 flush 被接受;drain 期間流入的錯誤路徑指令不得改變架構狀態 | `TODO.md` EX-2 |
| C3 | IDU | 同一時脈邊 `flush` 優先於 `if2id` 握手寫入 | `TODO.md` IDU-1 |
| C4 | BPU | 查表須為以 `if2bp_pc` 為輸入的同拍組合讀出,儲存體為 FF | `TODO.md` BPU-2 |
| C5 | 平台 | 每筆 AR 必有 R 回應(未映射位址回 `DECERR`) | `TODO.md` PLAT-1 |

---

## 14. 待辦

IFU 開放項目集中於 `DOC/TODO.md` §1(IFU-1 ~ IFU-8),跨模組項目見同文件 §2 ~ §7。

---

*波形以 [RetroWave](https://github.com/ruiuri0423/retrowave) 產生,檔案位於 `DOC/waveform/`。*
