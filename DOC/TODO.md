# Four-Stage Hart 待辦清單

| 項目 | 內容 |
|---|---|
| 適用範圍 | `RTL/Four_Stage_Hart/` 四級管線 hart(IF / ID / EX / WB) |
| 最後更新 | IFU review @ `fa7bf55`(Queue 架構 + drain-then-flush) |
| 相關文件 | `DOC/IFU_SPEC.md`、`DOC/IDU_SPEC.md`、`DOC/BPU_NOTES.md`、`DOC/IDU_NOTES.md` |

**優先度定義**

| 等級 | 意義 |
|---|---|
| **P0** | 影響功能正確性,或為其他模組動工前必須先拍板的介面 contract |
| **P1** | 影響效能、介面一致性或可驗證性,不影響單模組正確性 |
| **P2** | 優化、程式碼風格、文件同步 |

---

## 1. IFU

| # | P | 項目 | 狀態 |
|---|---|---|---|
| IFU-1 | P0 | `if2id_valid` 未於 flush 當拍遮蔽 | 開放 |
| IFU-2 | P1 | 穩態吞吐僅 2/3 IPC | 開放 |
| IFU-3 | P1 | 取指位址範圍檢查(簡化 PMA) | 開放 |
| IFU-4 | P2 | `arvalid` 改以 redirect *pending* 遮蔽 | 開放 |
| IFU-5 | P2 | `if2id_hsk` 為 implicit wire | 開放 |
| IFU-6 | P2 | `pc` 暫存器無非同步 reset | 開放 |
| IFU-7 | P2 | 檔頭註解過時 | 開放 |
| IFU-8 | P2 | `aclk_if` / `arstn_if` 端口未使用 | 開放 |

### IFU-1 `if2id_valid` 未於 flush 當拍遮蔽(P0)

現況 `if2id_valid = cmd_q_rok & data_q_rok`,未含 flush 條件。drain 結束、flush 成立的那一拍,兩個 queue 內仍留有錯誤路徑指令且 `rok` 皆為 1,若 `if2id_ready` 同時為高,該指令會完成握手交付 ID。

此時 IDU 的 `flush` 輸入亦於同拍為高,因此**只要 IDU 實作為「同一時脈邊 flush 優先於 if2id 握手」就不會出錯**——但這使 IFU 的正確性依賴對面模組的實作細節,與使用者原本「flush 後不讓任何訊號向後傳輸」的設計意圖不符。

建議修法(擇一):

- IFU 端自足:`if2id_valid = cmd_q_rok & data_q_rok & ~tr2if_flush_valid & ~ex2if_flush_valid`;
- 或維持現況,將 IDU 的 flush 優先權明文寫入 IDU spec(見 IDU-1)。

推薦前者,成本為一個 AND gate,且與 `arvalid` 的遮蔽方式一致。

### IFU-2 穩態吞吐僅 2/3 IPC(P1)

`SyncQueue` 的 `rok` / `wok` 均由**已暫存**的 `cnt` 產生,代表:

- 寫入的 entry 需下一拍才可讀(`rok` 慢一拍);
- 釋放的 slot 需下一拍才可寫(`wok` 慢一拍)。

兩者各吃掉一個 queue 深度。要在記憶體讀取延遲 `L` 下維持 1 IPC,需

```
DEPTH >= L + 2
```

目前 `DEPTH = 2`、`L = 1`,差一格,穩態呈現 3 拍交付 2 筆(2/3 IPC)。修法擇一:

- **加深**:兩個 queue 同步改為 `DEPTH = 3`(`L = 1`);`L` 若增加需同步放大。
- **前視**:`SyncQueue` 的 `rok` / `wok` 改由 `sync_q_cnt_n` 產生,或加寫入直通(write-through bypass),可省下一格深度。

註:`cmd_q` 與 `data_q` 深度須相同——ID 反壓時兩者會同步堆積至滿。

### IFU-3 取指位址範圍檢查(簡化 PMA)(P1)

BPU 為快取結構,aliasing 或訓練中的 entry 可能吐出任意 `npc`,使 IFU 對非法位址發出 AR。目前完全依賴 interconnect 回 `DECERR`(PLAT-1)。

建議於 IFU 內加一組位址範圍比較器:落在合法指令記憶體範圍外時**不發 AR**,直接於 `cmd_q` / `data_q` 各寫入一筆 `fault = 1` 的 entry,走既有的 instruction access fault 路徑。以目前規劃(FFFF 區段)僅需比較位址高位。收益:最常見的非法位址來源在源頭轉為 precise trap,不依賴 bus 行為。

### IFU-4 `arvalid` 改以 redirect *pending* 遮蔽(P2)

現況遮蔽條件為 `flush_valid`(= 已被接受的那一拍)。drain 等待期間仍會持續發出錯誤路徑的 AR,這些取指注定作廢,且會延長 drain window 的到來。改為以 `(ex2if_valid & ex2if_flush) | (tr2if_valid & tr2if_flush)` 遮蔽即可提早收斂。正確性不受影響,純屬優化。

### IFU-5 ~ IFU-8(P2)

- **IFU-5**:`if2id_hsk` 未宣告,靠 implicit wire 成立(1-bit 故功能正確,lint 會報)。建議補宣告並於檔頭加 `` `default_nettype none ``。
- **IFU-6**:`pc` 的 always block 僅有 `posedge clk_if`,無 `negedge rstn_if`。目前由 `state == SLEEP` 載入 `r_BOOT_ADDR` 保證功能正確,但與全案 reset 風格不一致,lint / DFT 會挑。
- **IFU-7**:檔頭仍寫 "port shell only" 與 "outstanding = 1",與現行實作不符。
- **IFU-8**:`aclk_if` / `arstn_if` 端口存在但未使用(現行計畫為 AXI 與 core 同步)。決定移除,或保留並於 spec 註明綁接方式。

---

## 2. BPU

| # | P | 項目 | 狀態 |
|---|---|---|---|
| BPU-1 | P0 | BPU 正式 design spec | 未起案 |
| BPU-2 | P0 | 查表須為**同拍組合**回應,並納入時序預算 | 開放 |
| BPU-3 | P1 | `ghist` 已移除,`id2bp_ghist` 殘留待清除 | 開放 |

### BPU-1 BPU 正式 design spec(P0)

待拍板事項見 `DOC/BPU_NOTES.md` §11:history event 定義、counter 型式、BTB index / tag 寬度(FFFF 區段 ⇒ tag 12 bits)、儲存體介面、`ext_flush` 處理、訓練規則表。由使用者發起時撰寫。

### BPU-2 查表須為同拍組合回應(P0)

IFU 的 `pc_p` 於**同一拍**消費 `if2bp_hit / taken / npc`(`pc_p = if2bp_taken_valid ? if2bp_npc : araddr + 4`),因此 BPU 的查詢回應必須是以 `if2bp_pc` 為輸入的純組合讀出,不得打拍。`if2bp_query` 僅為 strobe(供 BPU 更新 speculative 狀態),不參與讀出路徑。

連帶時序約束:`pc → BPU 表讀出 → pc_p mux → pc` 為 IFU 最長的 register-to-register 路徑,BPU 儲存體因此須為 FF 實作。此路徑**不觸及 `ARADDR`**(`ARADDR = pc` 為純暫存器輸出),故不影響 AXI 端口時序。改用單埠 SRAM 時本約束失效,需重新設計。

### BPU-3 `ghist` 殘留清除(P1)

`if2id` 已移除 `ghist`,但 `id2bp_ghist` 仍存在於 `InstructionDecoder.v:40`、`ExecutionUnits.v:51`、`HartTop.v:127/268/326`。IDU 已無 ghist 輸入來源,此線無法被驅動。需連同 xlsx(DOC-4)一併清除。

---

## 3. IDU

| # | P | 項目 | 狀態 |
|---|---|---|---|
| IDU-1 | P0 | flush 與 `if2id` 握手的同拍優先權 contract | 開放 |
| IDU-2 | P1 | `if2id_ready` 聚合條件定義 | 開放 |
| IDU-3 | P1 | 偽 stall 機制確認淘汰 | 開放 |

- **IDU-1**:同一時脈邊 `flush = 1` 與 `if2id_valid & if2id_ready = 1` 可能同時成立(見 IFU-1)。IDU 須明定 flush 優先於握手寫入(`if (flush) id_valid <= 0; else if (hsk) id_valid <= 1;`)。若採 IFU-1 的 IFU 端修法,本項降為防禦性規範。
- **IDU-2**:`if2id_ready` 為下游所有 stall 原因的唯一匯流點,其聚合條件(EX 反壓、CSR/BPU 送出條件)需於 `DOC/IDU_SPEC.md` 定案。
- **IDU-3**:舊架構的 I/J/U-type 偽 stall(`rs1_p` / `rs2_p` 原始欄位造成的假 collide)在新架構以 EX 反壓取代,不應再出現;實作時確認未沿用。背景見 `DOC/IDU_NOTES.md`。

---

## 4. EX / Trap

| # | P | 項目 | 狀態 |
|---|---|---|---|
| EX-1 | P0 | Redirect valid-held contract | 開放 |
| EX-2 | P0 | Redirect pending 期間 EX 不得 commit | 開放 |
| EX-3 | P1 | `id2ex_op` / unit_sel 編碼、`FAULT_WIDTH` 定案 | 開放 |
| EX-4 | P1 | Trap 單元 design spec | 未起案 |

### EX-1 Redirect valid-held contract(P0)

IFU 的 `ex2if_ready` / `tr2if_ready` = `!ongoing_cmd`,redirect 可能被反壓數拍(等 in-flight AR 排空)。因此 EX / Trap 端一旦拉起 `*_valid`,須**保持到 `ready` 回應為止**,期間 `pc` / `cause` / `flush` 不得變動。此為 drain-then-flush 成立的前提,須明文寫進 EX 與 Trap 的 spec。

### EX-2 Redirect pending 期間 EX 不得 commit(P0)

drain 等待期間 IFU 仍會將錯誤路徑指令交付 ID,ID 也會續往 EX 發送。這些指令**不得造成任何架構狀態改變**(RF 寫入、CSR 寫入、記憶體存取)。Contract:EX 自偵測到 mispredict / trap 起即壓住 `id2ex_ready`,直到 flush 被 IFU 接受。此條不落實,drain 機制在 hart 層級不安全。

### EX-3 / EX-4

- **EX-3**:`OP_WIDTH = 8`、`FAULT_WIDTH = 4` 目前為佔位值,待 EX spec 定案編碼後回填至各 shell 與 xlsx。
- **EX-4**:Trap 單元 spec(mtvec / mepc / mcause 機制)。`DOC/` 目前僅有 unprivileged spec PDF,privileged spec 未收錄;需使用者補入後方能引用原文。

---

## 5. 共通元件 / 平台假設

| # | P | 項目 | 狀態 |
|---|---|---|---|
| PLAT-1 | P0 | Interconnect 須保證每筆 AR 必有 R 回應 | 待確認 |
| CMN-1 | P1 | `SyncQueue` 前視版 `rok` / `wok`(若採 IFU-2 前視方案) | 開放 |
| CMN-2 | P2 | `AxiMemSlave` sim model | 開放 |
| CMN-3 | P2 | `SkidBuffer` 通用元件 | 降級 |
| PLAT-2 | P2 | Bus timeout bridge | SoC 層 |
| PLAT-3 | P2 | Watchdog 定位與 reset domain | SoC 層 |

### PLAT-1 每筆 AR 必有 R 回應(P0)

drain-then-flush 以「等 outstanding 歸零」為 flush 條件,其**活性(liveness)完全依賴此假設**。未映射位址須由 interconnect 的 default slave 回 `DECERR`;若無 default slave 且 slave 不回應,AXI 協定無任何取消交易的機制,drain 將永遠等不完而死鎖,且 hart 內部無法自解。

此為平台層假設,已寫入 `DOC/IFU_SPEC.md` §2.3,須向 SoC 整合端確認。

### CMN-2 / CMN-3

- **CMN-2**:`AxiMemSlave` —— `MemoryModel` 的 AXI wrapper(sim 用),需可調 R latency 與可注入 `DECERR`,用於驗證 IFU-2 的吞吐公式與 fault 路徑。
- **CMN-3**:IFU 對外緩衝已由 `data_q` 取代 skid buffer(`RREADY = data_q_wok` 為純暫存器輸出,資料落入 queue 記憶體),原「對外設 skid」的邊界原則以 queue 形式落實。通用 `SkidBuffer` 元件僅在 LSU AXI 端口需要時再評估。

### PLAT-2 / PLAT-3(SoC 層,記錄備查)

- **PLAT-2**:交易逾時由 interconnect 代回 `SLVERR` 並隔離故障 slave,對付「slave 活著但不回話」。
- **PLAT-3**:Watchdog 對 bus 死鎖的有效手段是 **reset request 而非 interrupt**——interrupt 需 fetch handler,而 fetch 走的正是卡死的 master,遞迴無解。Reset 範圍須涵蓋 interconnect,或於邊界放 reset isolation,否則 reset 釋放後 master 會收到不屬於它的 R beat。

---

## 6. 驗證

| # | P | 項目 | 狀態 |
|---|---|---|---|
| VER-1 | P1 | IFU testbench | 開放 |
| VER-2 | P2 | `run_vcs` 腳本擴充 | 開放 |

**VER-1** 至少涵蓋:穩態吞吐(驗證 IFU-2 的 `DEPTH >= L+2` 公式)、drain-then-flush(含 R 與 redirect 同拍到達的角落)、ID 長時間反壓、`DECERR` → `fault` 傳遞、boot 位址載入、`tr2if` 與 `ex2if` 同拍競爭。

---

## 7. 文件 / 介面表同步

| # | P | 項目 | 狀態 |
|---|---|---|---|
| DOC-1 | P1 | xlsx "Instruction Fetch" sheet 更新為 Queue 架構 | 使用者 |
| DOC-2 | P1 | xlsx "Execution Units" sheet 補 `if2bp_*` 列 | 使用者 |
| DOC-3 | P1 | xlsx Instruction list 補 MRET、移除重複 SRL 列 | 使用者 |
| DOC-4 | P1 | xlsx 移除 `id2bp_ghist`(連動 BPU-3) | 使用者 |
| DOC-5 | — | `IFU_SPEC.md` 改寫至 v2.0 | **已完成** |
| DOC-6 | — | IFU 波形依 Queue 架構重繪 | **已完成** |

DOC-1 需反映:outstanding 由 credit 改為 queue 空間綁定(上限 = `cmd_q` 深度)、`ex2if` / `tr2if` 的 `ready` 語意為 drain 完成、`if2bp` 查詢為同拍組合回應。
