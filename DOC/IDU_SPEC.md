# IDU (Instruction Decode Unit) Design Specification

| 項目 | 內容 |
|---|---|
| 版本 | v0.1(草案:指令集範圍與介面定義;波形與細部行為後續補齊) |
| 狀態 | 介面討論中 |
| 適用架構 | 四級管線 IF / ID / EX / WB;EX 單一佔用、變動延遲 |
| 相關文件 | `DOC/IFU_SPEC.md` v1.2(IF→ID 介面之對側)、`DOC/IDU_NOTES.md`(討論記錄) |

---

## 1. Overview

### 1.1 職責範圍

IDU 負責且僅負責:

1. 指令解碼:產生指令屬性(純組合,不含任何管線控制)與 `illegal` 判定。
2. Register File 的持有:讀口供 operand 解析、寫口由 WB 驅動(同一組訊號兼作 `ex_fwd`)。
3. Operand 解析:方案 **A2**(預存 + latch/fire 兩次 patch),RAW forward 於 ID 內完成。
4. 以 valid/ready 介面向 EX 交付**全暫存器化**的 payload。

不屬於 IDU:誤預測裁決(BPU)、CSR 讀改寫(EX 的 CSR 單元)、
exception 的發起與 CSR 狀態機(trap 單元,EX 側)。

### 1.2 設計原則(已拍板)

1. **管線控制由介面解決,輸出全擋 register**:
   ID→EX payload 為暫存器輸出;bubble = `id2ex_vld=0`(不清資料欄位)、
   stall = 暫存器 hold、flush = 只殺 valid bit。不存在「插 NOP」的動作。
2. **指令屬性與管線控制分離**:decoder 屬性訊號 = `f(inst)` 純組合,
   永不摻入 gating;現行 `dec_rs_collide` 偽 stall 與 combo-loop 問題隨此淘汰。
3. **RAW 處理只有一種機制**:`ex_fwd` 單源比較(EX 執行中的 producer 由
   EX-busy 反壓天然擋住,無 interlock 偵測邏輯)。

---

## 2. 支援指令集

### 2.1 完整支援(解碼 + 執行)

| 類別 | 指令 | 數量 |
|---|---|---|
| RV32I Reg-Reg | `ADD SUB SLL SLT SLTU XOR SRL SRA OR AND` | 10 |
| RV32I Reg-Imm | `ADDI SLTI SLTIU XORI ORI ANDI SLLI SRLI SRAI` | 9 |
| RV32I Upper | `LUI AUIPC` | 2 |
| RV32I Jump | `JAL JALR` | 2 |
| RV32I Branch | `BEQ BNE BLT BGE BLTU BGEU` | 6 |
| RV32I Load | `LB LH LW LBU LHU` | 5 |
| RV32I Store | `SB SH SW` | 3 |
| Zicsr | `CSRRW CSRRS CSRRC CSRRWI CSRRSI CSRRCI` | 6 |
| SYSTEM(新增) | `ECALL EBREAK MRET` | 3 |

- SYSTEM 三條為本版**新增解碼**(現行 core 未解碼):decoder 產生
  `ecall / ebreak / mret` 旗標隨 payload 進 EX,由 trap 單元消費;
  屬性上三者皆為「無 rd 寫入、無記憶體存取」的控制事件。
- 配套的 trap CSR(`mstatus mie mip mtvec mepc mcause mtval`)屬
  **EX/CSR 單元規格範圍**,本文件僅界定解碼義務;現行已有的
  `mvendorid marchid mimpid mhartid mconfigptr mscratch` 維持。

### 2.2 特例行為

| 指令 | 行為 | 理由 |
|---|---|---|
| `FENCE`(MISC-MEM funct3=000) | 解碼為 NOP(合法指令,無屬性) | 單 hart、in-order、無 cache,記憶體順序天然保證 |
| `FENCE.I`(funct3=001) | `illegal` | Zifencei 未實作;I-Cache 導入時再定義 |
| `WFI` | 解碼為 NOP(可選) | spec 允許 WFI 實作為 NOP;中斷導入前無等待對象 |

### 2.3 非法編碼(`illegal` 判定)

`illegal = NOT(§2.1 ∪ §2.2 合法編碼)`,檢查清單:

| 檢查項 | 內容 |
|---|---|
| 編碼長度 | `inst[1:0] != 2'b11`(C 擴充未實作) |
| 全 0 / 全 1 | spec 明文定義為 illegal |
| 未知 major opcode | 不屬已定義之 opcode |
| funct3 缺口 | BRANCH `010/011`;LOAD `011/110/111`;STORE `≥011`;JALR `≠000` |
| funct7 全檢 | OP 僅 `0000000`/`0100000`(後者限 SUB/SRA);OP-IMM 移位同理;**含 M 擴充 `0000001` 一律 illegal** |
| SYSTEM funct3=000 | 僅 ECALL(imm=0)/EBREAK(imm=1)/MRET(imm=0x302)合法,其餘 illegal |

行為:`illegal=1` 時所有執行屬性強制無效(`rd_wen=0`、無單元選擇),
旗標隨 payload 進 EX 交 trap 單元(mcause=2、mtval=inst);
trap 單元完成前等效 NOP retire,不產生任何副作用
(修正現行「寫 0 進 rd」「`is_LS` 幽靈存取」兩類未定義行為)。

---

## 3. Block Diagram

```
              if2id(valid/ready + payload)          ex_fwd = RF write port
                        │                          {vld, rd, data}(WB 驅動)
      ┌─────────────────▼──────────────────────────────▲────────┐
      │                        IDU                     │        │
      │  ┌──────────┐  ┌─────────┐  ┌──────────────────┴─────┐  │
      │  │ Decoder  │  │ RegFile │  │    OperandResolve      │  │
      │  │ 純組合屬性│  │ 32x32 FF│  │ A2:latch patch +      │  │
      │  │ + illegal│  │ 讀2寫1  │  │     fire patch         │  │
      │  └────┬─────┘  └────┬────┘  └───────────┬────────────┘  │
      │       └─────────────┴───────┬───────────┘               │
      │                    ┌────────▼─────────┐                 │
      │                    │  Output Register │  ← 全欄位暫存器  │
      │                    │  + valid bit     │     (原則 1)    │
      │                    └────────┬─────────┘                 │
      └─────────────────────────────┼───────────────────────────┘
                                    ▼ id2ex(valid/ready + payload)
                          flush(redirect 廣播)→ 只殺 valid
```

---

## 4. Interface

### 4.1 IF → ID(`if2id`;定義見 `IFU_SPEC.md` §3.2,此處為對側)

`vld / ready` + payload `{pc, inst, pred_taken, pred_npc, ghist, pred_hit, fault}`。
`if2id_ready = ~out_vld | id2ex_ready`(輸出暫存器可載入即 ready;flush 拍照常可收,
內容隨 valid 清除)。

### 4.2 ID → EX(`id2ex`)

| Signal | Width | 說明 |
|---|---|---|
| `id2ex_vld`   | 1 | payload 有效;flush 清除 |
| `id2ex_ready` | 1 | EX 可接受(EX 非 busy) |
| **datapath** | | |
| `pc`        | 32 | 指令位址(AUIPC/JAL/branch target/BPU resolve 共用) |
| `rs1_data`  | 32 | 已解析 operand(A2;CSRRxI 時為 zero-extended zimm) |
| `rs2_data`  | 32 | 已解析 operand(store data 亦由此供給) |
| `imm`       | 32 | 立即值(LSU 位址、branch/jal target、ALU imm 運算) |
| `rd`        | 5  | 目的暫存器 |
| `rd_wen`    | 1  | 寫回致能(x0 / illegal / branch / store 為 0) |
| **execution attributes** | | |
| `alu_op`    | enc | ALU 功能選擇(編碼於 EX spec 定案) |
| `unit_sel`  | enc | ALU / LSU / CSR / NONE(NOP、FENCE) |
| `ls_store`  | 1  | load=0 / store=1 |
| `ls_size`   | 2  | byte / half / word |
| `ls_sign`   | 1  | load 符號延伸 |
| `csr_addr`  | 12 | CSR 位址 |
| `csr_op`    | 2  | RW / RS / RC |
| **branch class(BPU resolve/training 用)** | | |
| `is_branch` | 1  | 條件分支 |
| `is_jal` / `is_jalr` | 2 | |
| `is_call` / `is_ret` | 2 | link-reg 分類(JAL rd=x1/x5;JALR 四情境)於 ID 組合判定 |
| **BPU metadata(IF 透傳,ID 不消費)** | | |
| `pred_taken` | 1 | |
| `pred_npc`   | 32 | |
| `ghist`      | 4 | 選配,BPU spec 拍板 |
| `pred_hit`   | 1 | 選配,BPU spec 拍板 |
| **trap events** | | |
| `illegal` / `ecall` / `ebreak` / `mret` | 4 | trap 單元消費;trap 前等效 NOP |
| `fault`     | 1  | IF 端 fetch fault 透傳 |

### 4.3 EX/WB → ID(`ex_fwd`,兼 RegFile 寫入口)

| Signal | Width | 說明 |
|---|---|---|
| `ex_fwd_vld`  | 1  | WB 級指令有效且 `rd_wen`(store/branch 不拉) |
| `ex_fwd_rd`   | 5  | |
| `ex_fwd_data` | 32 | ALU 結果 / load 對齊資料 / CSR 舊值,EX 收斂後不分來源 |

同一組訊號同拍並聯驅動:RegFile 寫入口、operand 的 latch/fire patch 比較。

### 4.4 Flush

`flush` 輸入(redirect 之廣播,cause 不解讀):清除 output register 的 valid bit,
資料欄位不動(don't-care)。與 IF 端 discard、EX 端 flush 同一事件源。

### 4.5 其他

`CLK` / `RSTN`。

---

## 5. 功能行為(拍板事項的落實)

### 5.1 Operand 解析(A2)

- **Latch patch**(進入 output register 當拍):
  `op <= (ex_fwd_vld && ex_fwd_rd == rs) ? ex_fwd_data : rf[rs]`
  —— 擋 read-during-write(RF 寫在拍尾、讀在拍中,同拍寫不可見)。
- **Fire patch**(`id2ex` 握手成立當拍,mux 於 output register Q 端):
  等待期間唯一可能過期化預存值的 producer(佔用 EX 者)完成時恰於
  `ex_fwd` 上,fire 當拍必命中 —— 兩次 patch 即完備,毋須連續刷新。
- 通用規則:**operand 最終值以 fire 當拍的 `ex_fwd` 比對為準**。
- CSRRWI/RSI/RCI:`rs1_data` 於解析時代換為 zero-extended zimm,
  EX 的 CSR 單元不區分暫存器/立即值變體。

### 5.2 RAW 與 stall

無任何 RAW 偵測/interlock 邏輯:producer 在 EX 內 → `id2ex_ready=0` 天然擋;
producer 在 WB → `ex_fwd` patch;更老 → RF。
(現行 `nop_insert / dec_rs_collide / csr_hazard` 機制全數淘汰,
偽 stall 問題隨之消失 —— 不於現行 code 修正。)

### 5.3 Valid-bit 控制

Output register:載入 = `if2id_vld & (~out_vld | id2ex_ready) & ~flush`;
清除 = flush 或被取走且無新資料;保持 = 其餘。資料欄位僅於載入時更新。

---

## 6. 待辦

- [ ] `alu_op` / `unit_sel` 編碼(與 EX spec 一併定案)
- [ ] 波形:back-to-back RAW 零 bubble、load 佔用 EX 反壓、flush、CSRRxI zimm 代換
- [ ] `is_call/is_ret` 四情境真值表(自 `ALUTop.v:159-178` 移植,BPU spec 交叉引用)
- [ ] trap 單元介面(ecall/ebreak/mret/illegal/fault 的消費側)—— EX spec 範圍
