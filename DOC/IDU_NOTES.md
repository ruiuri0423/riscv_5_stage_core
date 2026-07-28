# IDU Discussion Notes(討論記錄)

> 定位:**ID 階段(decoder / regfile / forwarding / hazard)討論結論的記錄,供查閱**。
> 正式 design spec 另行發起撰寫時再整理。
> 相關文件:`DOC/IFU_SPEC.md`(IF 介面已凍結)、`DOC/BPU_NOTES.md`。

---

## 1. 現行 forwarding 拓撲

- 捕捉點在 **RegisterTop 運算元暫存器的 D 端**(`RegisterTop.v:118-124`):
  forward mux 選擇「RF 讀出值 vs 前遞值」,選中值於捕捉當拍寫入 `rs1_data/rs2_data`,
  下一拍成為 ALU 輸入。與教科書 MIPS(mux 在 EX 的 ALU 輸入端、組合同拍)不同 ——
  此拓撲的 forward 來源**只能是已打拍的結果**,是距離1 必吃 1 bubble 的根本原因。
- Consumer 在 decode-in(`dec_rs1_p/dec_rs2_p`,組合切割),producer 三個可能位置:
  decode-out(`dec_rd`)、EX(`alu_rd`)、WB(`wb_rd`)。

### 四 case 行為模型(已逐項對 code 驗證)

| Case | 條件 | 行為 | Code |
|---|---|---|---|
| 1 | EX 完成、非 load、撞 consumer 的 rs | forward `alu_out`(CSR 時 `alu_csr_out`)進捕捉點,下一拍為 ALU in | `ForwardUnit.v:34-35,42-46` |
| 2 | EX 為 load、撞 rs | insert nop,`nop_insert_hold` 撐到 `lsu_mem_rvld` | `:36-37,52-67` |
| 3 | decode-out 撞 decode-in 的 rs(任何 producer) | 1 bubble(NOP 插入 decode-out);load 版接力進 case 2 | `:49-52` |
| 4 | WB 撞 rs | forward `wb_rd_data`(距離3 與 read-during-write) | `:39-46` |

- 優先權:EX > WB(新者勝)。
- 距離1 時序:`IF(I_n) > ID(I_{n-1})` → 插 NOP → `IF(I_n) > ID(NOP) > EX(I_{n-1})`
  → 下一拍 `ID(I_n, operand=forward(EX 結果)) > EX(NOP)`。
  本質:**插 NOP 把距離1 人工拉開成距離2**,使 producer 結果先落進暫存器。
- Case 2 收尾(**以實機波形驗證定案**;先前版本記載有誤,已更正):
  load 於其 EX 拍結尾即移入 `lsu_*` 暫存器(該拍 `lsu_ready` 仍為 1,
  `alu_*` 同拍前進為 bubble),等待期間 `alu_mem_read=0`,
  stall 由 `nop_insert_hold & ~lsu_mem_rvld` 獨力維持;
  `lsu_mem_rvld` 拍該項天然失效 → `nop_insert` **當拍落下**、`rs1_ren` 回高,
  consumer 於同拍結尾經 **WB forward** 收下 `wb_rd_data`(與 RF 寫入同拍)並前進。
  註:記憶體側 `mem_rvld` 較 LSU 側 `lsu_mem_rvld` 早一拍(CoreBus 對 data 回應打拍)。

### 正確性結論

窮舉 producer 位置 × consumer 需求,每格有 forward 或 interlock,**無正確性漏洞**
(x0 由 `rd_wen` 排除;store 非 producer;CSR 經 `alu_csr_out`/`lsu_out` 併入一般路徑)。

## 2. 現行設計的效能缺口(刻意不做的兩條 path)

| 缺的 path | 現況替代 | 補上效益 | 不補理由 |
|---|---|---|---|
| 消費點組合 forward(教科書式 EX 輸入端 mux,來源含 `alu_out_nxt` / 當拍載入資料) | 捕捉點在暫存器 D 端,forward 來源限已打拍結果 | 距離1 零 bubble;load-use 的 consumer 可提前一拍進 EX | 組合鏈變長(運算/載入資料 → mux → EX 輸入),現行一致選「多等一拍」 |

(原記載的「load 資料早釋放」獨立缺口經波形驗證不存在 —— WB forward 於
`lsu_mem_rvld` 拍即生效;僅存的差距與距離1 bubble 同根因,合併為上列單一項。)

## 3. 偽 stall(現行 RTL 效能 bug,已確認)

- `ForwardUnit.v:49-50` 的 `dec_rs_collide` 未以「該指令是否真的讀 rs」gate。
- `TypeDecoder.v:66-96` 證實 `rs1_p/rs2_p` 為**無條件欄位切割**(type 判斷只改 `imm_p`,
  唯一歸零條件是 `inst_vld=0`):I-type 的 `rs2_p` = imm[4:0]、U/J-type 兩欄皆 imm 位元。
- 後果:`add x5,..` 後接 `addi x6,x7,5`(imm=5 → rs2_p=5=x5)→ 偽 bubble。
  I-type 高頻,累積損失可觀。正確性不受影響(誤 forward 被 `rs2_sel` imm 路徑蓋掉)。
- **修法陷阱**:不可直接用 `rs1_ren/rs2_ren` gate —— 它們由含 `~nop_insert` 的
  type 訊號組成(`TypeDecoder.v:55-61`),回接 ForwardUnit 會形成
  `nop_insert → type → ren → collide → nop_insert` 組合迴圈。
  正確做法:另拉純 opcode 直出的訊號:

  ```verilog
  wire rs1_used = is_OP | is_OP_IMM | is_LOAD | is_STORE | is_BRANCH | is_JALR | is_SYSTEM;
  wire rs2_used = is_OP | is_STORE  | is_BRANCH;
  ```

- 狀態:**未修**;於新架構中自然消失(`dec_rs_collide` 不存在)。是否先修現行 code 待決。

## 4. 新架構(四級)的 forwarding 設計

### 4.1 機制塌縮

EX 單一佔用 + valid/ready 之後:

```
現行:EX forward + WB forward + 距離1 NOP + load stall/hold + csr_hazard   (5 種機制)
新:  ex_fwd 一組比較 + EX-busy 反壓(握手免費提供)                        (1 種機制)
```

| Producer 位置 | ID 需要做的事 |
|---|---|
| EX 內(執行中) | 不用偵測 —— EX busy,`id2ex` 握手天然擋住 consumer |
| EX 結果暫存器(=WB) | `rs == ex_fwd.rd` 命中 → 取 `ex_fwd.data` |
| 已退休(RF) | 正常 RF 讀 |

Back-to-back ALU RAW:1 bubble → **0 bubble**;load-use 等待 = load 佔用 EX 的長度;
`csr_hazard` 消失(CSR 讀改寫於 EX 內原子完成)。§2 兩條缺 path 一條內建、一條消失。

### 4.2 `ex_fwd` 介面(單源,無仲裁)

```
ex_fwd = { vld,        // WB 級指令有效且 rd_wen(store/branch 不拉)
           rd  [4:0],
           data[31:0] } // ALU 結果 / load 對齊資料 / CSR 舊值,收斂後不分來源
```

- 「仲裁」退化為 EX 內部的**完成收斂 mux**:單一佔用保證每拍最多一個單元完成,
  無同拍競爭。tap 點即 **EX/WB 邊界暫存器本身**(listener 比喻),
  ID 只讀其 Q 端 + 兩個 5-bit 比較器,對 EX 內部組合路徑零負載。
- CSR / ALU / LSU 在此介面上**不再是特例**(收斂進暫存器前差異已被抹平)。
- 若 `ex_fwd` 與 RF 寫入口為同一組訊號,read-during-write bypass 被同一比較順便涵蓋。
- Stale-hit 無害:WB 退休後暫存器殘值與 RF 內容相同(單一佔用保證無更年輕的同 rd
  producer 越過此暫存器);實作仍建議 `vld` 僅於 WB 級有效時拉高,語意乾淨。

### 4.3 運算元解析時點(規格語言)

> `id2ex` payload 的 operand 欄位在**握手成立當拍**完成解析:
> `op = (ex_fwd.vld && ex_fwd.rd == rs) ? ex_fwd.data : rf[rs]`
> EX 收到的永遠是已解析的最終值,EX 內部不含任何 forward 邏輯。

- mux 物理位置(ID 輸出組合 vs EX 輸入暫存器 D 端)實作自由,規格只鎖「解析在 fire 當拍」。
- 若 ID 預存 RF 讀值,mux 必須蓋在預存暫存器 Q 端之後(等待期間預存值會過期);
  FF regfile 組合讀 + fire 當拍解析則無此問題。

### 4.4 Operand 存放的兩個候選方案(待拍板)

| 方案 | 做法 | 取捨 |
|---|---|---|
| A1 fire 當拍組合解析 | ID 不預存 operand 值;fire 當拍組合 `RF讀 + ex_fwd patch` | 無過期問題;fire 拍路徑較長(RF mux + 比較 + mux) |
| A2 預存 + 兩次 patch | 進 ID 時讀 RF 預存(**latch 當拍以 ex_fwd patch** 擋 read-during-write);fire 當拍再 patch 一次蓋過期值 | fire 拍路徑短;同一組比較器、兩個 mux(預存暫存器 D 端與 Q 端) |

A2 正確性論證 —— 兩次即足夠、不需等待期間連續刷新,對應 producer 三個年齡層:

| Producer 狀態(以 latch 拍為基準) | 由誰供值 |
|---|---|
| 更早已退休(RF 已寫完) | RF 組合讀 |
| 正在 WB(與 latch 同拍) | **latch 時 patch**(read-during-write:RF 寫在拍尾、讀在拍中,同拍寫不可見) |
| 還在 EX(等待期間才完成) | **fire 時 patch**(單一佔用保證它完成時恰在邊界暫存器,fire 當拍必命中) |

通用規格語言:**無論預存與否,operand 最終值以 fire 當拍的 `ex_fwd` 比對為準**。

### 4.5 已決策:skid 邊界原則 —— 對外設、in-hart 不設

- **對外介面(bus / SRAM / Cache 端口)設 skid**:外部資料無法無成本 hold
  (同步 SRAM / cache 讀出不捕捉即流失,hold 佔住 cache pipeline 即 stall 他人);
  端口打拍為乾淨的時序隔離面;共享 interconnect 時避免 beat 佔用通道。
- **In-hart stage 邊界(IF→ID、ID→EX、EX→WB)不設**:介面多、payload 寬,
  skid 需複製整份資料暫存器;邊界原生已有一組管線暫存器(consumer 端);
  核內 ready 鏈天然短(`wb_ready` 恆 1、`ex_ready` 為暫存器輸出),允許組合穿越。
- IFU 對外 AXI R 端口維持 1-deep skid,見 `IFU_SPEC.md` v1.2 §5.3;
  LSU 的 AXI 端口屆時複用同一元件。

### 4.6 演進路徑備查:non-blocking load 與 scoreboard

現行計畫(EX 單一佔用)下,「記錄 ID 已 issue 的 rd」的 buffer(scoreboard)
為零收益 —— in-flight producer ≤ 2,資訊已存在於管線暫存器,且不相依指令同樣
進不了 busy 的 EX。真正的入場時機為放寬單一佔用(non-blocking load:
load 等待期間放行不相依 ALU 指令),屆時完整帳單:
busy 追蹤、WAW 擋捕、forward 多源化(單源優雅性消失)、WB 口仲裁、flush 記帳。
ROB 為更後一級(亂序完成後依序退休、精確例外),本核視野外。
待四級架構量測 IPC 確認 load 阻塞為主要損失後再議。

## 5. 現行 Decoder 完整度盤點(2026-07 掃描)

### 5.1 指令解碼覆蓋(合法編碼)

| 類別 | 覆蓋 | 備註 |
|---|---|---|
| R-type ×10 | 10/10 | funct7 僅檢查 bit5 |
| I-type ALU ×9 | 9/9 | SLLI 未驗 funct7=0(接受非標準編碼) |
| LUI/AUIPC/JAL/JALR | 4/4 | |
| Branch ×6 | 6/6 | |
| Load ×5 / Store ×3 | 8/8 | |
| Zicsr ×6 | 6/6 | 含 rd=x0 不讀 / rs1=x0 不寫的 Table 7 條件(`FunctionDecoder.v:310-311`) |
| Immediates I/S/B/U/J | 5/5 | 位元組裝比對 spec 正確 |
| FENCE | 解碼後 NOP | 對無 cache 之 in-order core 功能上可接受 |
| ECALL/EBREAK(SYSTEM funct3=0) | 未解碼 → NOP | 已知缺口(README) |

### 5.2 非法編碼的行為(未定義區)

**無 illegal-instruction 偵測**,非法編碼的實際行為分三級:

1. 輕:未知 opcode → 不屬任何 type → 等效 NOP。
2. 中:SYSTEM 未定義 funct3 且 rd≠x0 → `rd_wen=1` 而無 ALU enable → **rd 被寫入 0**;
   funct7 僅查 bit5 → 未來 M 擴充編碼(funct7=0000001)會**默默解成基本指令**
   (MUL→ADD 等)。
3. 重:LOAD/STORE 的未定義 funct3 → `is_LS` 內層 case 無 default、**保持前值**
   (`FunctionDecoder.v:353-372`):若前一條為記憶體指令,非法指令會以新位址
   幽靈執行前一條的存取型態。

影響評估:合法程式碼不會踩到;但這是 trap/illegal-instruction exception 的前置債,
新 decoder 應至少補 `illegal` 旗標(交由未來 trap 單元),`is_LS` 補 default
(精確位置:**內層** case 的 if/else-if 鏈缺 else,外層 default 只涵蓋非 LOAD/STORE)。

**`illegal` 旗標檢查清單**(`illegal = NOT(合法 RV32I ∪ Zicsr 編碼)`):

| 檢查項 | 內容 |
|---|---|
| 編碼長度 | `inst[1:0] != 2'b11`(未實作 C 擴充) |
| 全 0 / 全 1 | spec 明文定義為 illegal |
| 未知 major opcode | 不屬已解碼的 11 個 opcode |
| funct3 缺口 | BRANCH 010/011;LOAD 011/110/111;STORE ≥011;JALR ≠000;SYSTEM 100 |
| funct7 全檢 | OP 僅 `0000000` / `0100000`(後者限 ADD→SUB、SRL→SRA);OP-IMM 移位同理;其餘含 M 擴充 `0000001` 一律 illegal |
| SYSTEM funct3=000 | ECALL(imm=0)/EBREAK(imm=1)實作前標 illegal;其餘 imm 值 illegal |

行為:decoder 只標旗標不處置;`illegal=1` 強制 rd_wen/mem/branch 屬性無效(等效 NOP),
trap 單元完成後據此發 illegal-instruction exception(mcause=2、mtval=inst)。
CSR 位址不存在之檢查屬 CSR 單元職責,另計。

### 5.3 死碼/懸空(清理項)

- `dec_type_vld`、registered `funct7/funct3/opcode` 輸出於 CoreTop 懸空。
- ForwardUnit 的 `dec_rs1/dec_rs2` 輸入 port 宣告未使用(body 只用 `dec_rs*_p`)。
- 註解掉的 `inst_type` 輸出、`FUNCT_NOP` 定義未使用。
- 寬度 lint(`4'd0` 比 5-bit 訊號)—— 已決議留 lint 階段。

### 5.4 機制面(與 §1-§3 交叉)

- type gating 訊號(`r_type_inst` 等)同時承擔「類型判斷」與「pipeline 控制」
  (`~nop_insert & ~alu_flush & ~csr_hazard & ~dec_freeze`)雙重職責 ——
  §3 的 combo-loop 陷阱源自於此;新 decoder 應把「指令屬性」(純組合、無 gating)
  與「管線控制」(valid/ready)分離。
- **分離準則的落實方式**(已確認):控制對象從「資料內容」換成「valid bit」——

  ```
  屬性(純組合):attr = f(inst)                    // 永不 gate、永不清零
  控制(握手):  out_vld — 載入:in_vld & out_ready & ~flush
                          清除:flush / 被取走且無新資料
                          保持:~out_ready(stall)
  資料暫存器:   僅載入時更新,其餘保持;valid=0 時內容為 don't-care
  ```

  Bubble = `out_vld=0`(不再清零欄位製造 NOP);stall = 暫存器 hold;
  flush = 只殺 valid。現行「清成全 0 = NOP」的做法與其優先權糾纏全數淘汰。

## 6. 待拍板清單

- [ ] 偽 stall 是否於現行 code 修正(§3),或隨新架構淘汰
- [ ] 新 ID 的 `id_ready` 聚合條件(目前推導:`ex_ready` 一項 + flush 清 valid)
- [ ] ID→EX payload 欄位定義(含已定案的 operand 解析規則 §4.3)
- [ ] `illegal` 旗標與非法編碼行為定義(§5.2;與 trap 規劃連動)
- [ ] 新 decoder 的「指令屬性 / 管線控制」分離(§5.4)
- [ ] Operand 存放方案:A1(fire 當拍組合解析)vs A2(預存 + 兩次 patch)(§4.4)
- [x] ID→EX 緩衝:skid 邊界原則 —— 對外介面設、in-hart 不設;
      ID→EX 為 in-hart,單一管線暫存器 + 組合 ready(§4.5)
- [x] Scoreboard / ROB:現階段不做,列為 non-blocking load 演進路徑(§4.6)
