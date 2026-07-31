# BPU Discussion Notes(討論記錄)

> 定位:**BPU 相關討論的結論記錄,供查閱**。正式 design spec 另行發起撰寫時再整理。
> 相關文件:`DOC/IFU_SPEC.md`(IFU 介面已凍結,其中 BPU query/resp、redirect 介面即
> BPU 的對外邊界)。

---

## 1. 模組切分:policy 與 storage 分層

- BPU 拆兩層:**policy**(gshare 雜湊、taken 決策、spec/arch 管理、訓練、redirect 產生)
  與 **prediction table storage**(純儲存體,無決策)。
- 檔案粒度(暫定):`RTL/BPU/BpuTop.v` + `Bht.v` / `Btb.v` / `Ras.v`;
  RAS 的 spec/arch 雙份 = `Ras.v` 實例化兩次,policy 在 BpuTop。
- 好處:換預測演算法只動 policy;Table 可獨立驗證、未來可換 SRAM 實作。

## 2. 預測查詢時序(issue 拍查表)

- 查表用「AR issue 當拍的 `ARADDR`」,與記憶體存取**平行**進行,結果打一拍,
  於下一發 issue 的 next-pc mux 使用 —— taken 預測零 bubble,
  且 `ARADDR` 組合路徑上不含表讀出邏輯(mem i/f 時序瓶頸解除)。
- query/resp 皆 **無 ready**:FF 表讀口恆可用;讀寫同拍碰撞讀到舊值,無害;
  誤預測當拍的並行查詢屬錯誤路徑,隨 discard 一併作廢,無「等表更新」需求。
  Caveat:表改單口 SRAM 時需重新引入 stall。
- redirect 被接受當拍,pending 中的預測回應一併作廢(與 in-flight fetch 同一清理域)。

## 3. 誤預測裁決:metadata 隨管線走,單一比較

- 預測 metadata `{pred_taken, pred_npc, ghist}` 由 IFU 放進 payload,
  經 ID 打拍對齊送到 EX;**ID 不消費,只轉運**。
- `pred_npc` ≜ 該指令之後 IFU **實際發出**的下一個取指位址(taken → `pred_pc`;
  not-taken → pc+4)。裁決塌縮為單一 32-bit 比較:

  ```
  actual_npc = branch & taken ? pc + imm  :
               jal            ? pc + imm  :
               jalr           ? rs1 + imm : pc + 4;
  mispredict  = (actual_npc != pred_npc);
  redirect_pc = actual_npc;
  ```

  方向錯 / target 錯 / 非分支被誤標 taken(BTB alias)一式涵蓋 ——
  舊架構以 `inst_pc` 反推造成的三類 bug(JALR flush 公式、`alu_pc` 歸零跳 0x4、
  taken 分支 target 未驗)結構上不再存在。
- `pred_taken` 非裁決必需(可由 `pred_npc != pc+4` 反推),帶 1 bit 的理由:
  訓練策略要區分「BTB miss 未預測」vs「有預測」(初見 taken 分支 → allocate BTB entry)、
  mispredict rate 統計、debug 可視性。
- metadata 候選欄位 `pred_hit`(1 bit,= 查表當拍的 `tag_valid`):
  history 事件對齊為「有預測才 shift」時,arch 端 shift 條件的依據(見 §6)。
- 替代方案「BPU 內部 in-flight queue 配對」被否決:queue 須鏡射管線全部流動控制
  (stall/bubble/flush),重複記帳易失步;payload 方案由既有管線暫存器免費對齊。

## 4. `ghist`(gshare history 快照)—— 選配,傾向保留

- gshare 鐵律:訓練必須命中「預測當拍查的那顆 counter」,即需要預測當拍的 history。
- **方式 A(現行做法,`BranchPredict.v:40-41`)**:解析時用 arch history 重建 index。
  在「in-order、單發射、依序解析、誤預測沖掉較年輕指令」前提下**精確成立**:
  指令能走到解析 ⇒ 較老的 in-flight 分支全猜對 ⇒ 預測方向 == 真實方向 ⇒
  spec@predict == arch@resolve(需事件定義一致,見 §5)。
- **方式 B(ghist 快照)**:預測當拍把 `bht_queue_spec` 存進 metadata,解析直接用。
- 結論:在本核 in-order 架構下方式 A 正確、`ghist` 冗餘;保留它買到的是
  (a) 正確性不依賴 in-order 推理鏈(多發射/亂序解析/flush 語意改變時仍成立)
  (b) BPU resolve 自包含。成本 4 bits 管線暫存器。**正式 spec 時拍板**。

## 5. Speculative / Architectural 雙份狀態

- 分工:**spec 版供預測查詢與即時投機更新;arch 版只吃解析確認的結果,
  兼任恢復 checkpoint**(注意:不是「spec 訓練、arch 預測」,方向別記反)。
- 為何投機更新:預測→解析間有 2~3 拍窗口;
  - ghist:tight loop 中同一分支連續迭代落在窗口內,不投機 shift 則 index 不動,
    gshare 退化、迭代模式無法分辨;
  - RAS:短 leaf function 的 `ret` 常在 `call` 解析前就被取指,
    不投機 push 則 pop 到舊頂端。
- 為何 2-bit counter **不做** spec 版:飽和慢變,晚訓練/讀舊值影響極小,
  且投機訓練需可回退的 undo,不划算。
- **恢復規則(ghist / RAS 通用)**:`spec := architectural ⊕ 觸發恢復指令自身的效果`
  (現行 code 參照:`BranchPredict.v:59-60` history 重建、`:139-166` RAS flush 分支)。
  觸發源含 mispredict flush 與未來 trap flush。
- **非 BPU 來源的 redirect(TRAP/MRET)必須同時通知 BPU**(`ext_flush` 輸入):
  否則 spec 狀態殘留被沖掉路徑的更新,污染後續預測。
  屬預測準確度(效能)問題,非功能正確性 —— 預測永遠會被驗證。
- RAS 深度 4,巢狀超過 4 層擠掉最舊返回位址,深層返回退回 BTB target —— 容量取捨,接受。

## 6. History 事件定義必須 spec/arch 一致(現行不一致,新設計修掉)

- 現行:spec 版僅於 **BTB hit** 時 shift(`pc_taken/pc_n_taken` 含 `tag_valid`);
  arch 版對**所有**解析分支無條件 shift(`alu_branch`,含 BTB miss 初見分支與 jal/jalr)。
- 後果:BTB miss 分支使 spec/arch 悄悄失步,至下次 flush 才重新同步;
  §4 方式 A 的等式也依賴事件定義一致。
- 新設計:兩邊採同一事件定義。**對齊方向只有一邊可行**:
  - 「有預測(BTB hit)才算事件」——可行:spec 端維持現狀;arch 端於解析時需知道
    「該分支 fetch 當拍是否 BTB hit」,由 metadata 多帶 1 bit(`pred_hit` = 查表當拍的
    `tag_valid`)提供。BTB miss 初見分支不進 history,解析後 allocate,之後即為 hit,
    事件集合暖機後收斂。
  - 「所有分支都算事件」——不可行:fetch 當拍無法辨識 BTB miss 的分支
    (未解碼,唯一辨識手段即 BTB hit;此即現行 spec 僅 hit 才 shift 的原因);
    解析時將漏失 bit 插回 spec history 中段會破壞順序。
- 方式 A(arch 重建)的成立前提:解析順序==預測順序、一次解析一條、
  誤預測沖掉所有較年輕分支 —— 單發射 in-order 天然滿足;
  亂序解析 / 選擇性 flush 出現時等式破裂(此為 §4 ghist 傾向保留的核心理由)。

## 7. Call / Return 分類(RAS hint)

- 依 RISC-V 慣例由 `rd`/`rs1` 是否為 link register(x1/x5)判定:
  JAL rd=link → push;JALR 四情境:rd=link,rs1≠link → push;rd≠link,rs1=link → pop;
  rd=rs1=link 且 rd≠rs1 → pop-then-push;rd=rs1=link 且相等 → push。
  (現行 `ALUTop.v:159-178` 的 Case 1-4,對照 spec 正確。)
- 新架構中此分類移入 BPU(資訊在 decode 已齊,放 EX datapath 無時序理由);
  訓練所需的 branch class 由 decode 提供。

## 8. BTB index / tag 位元配置

- 現行實例參數(`InstFetch.v:63-69` 覆寫):`BTB_WIDTH=4, TAG_WIDTH=6`
  → index `pc[3:0]`、tag `pc[9:4]`,僅覆蓋 `pc[9:0]`。
  - index 含恆為 0 的 `pc[1:0]`:16 entries 實際只用 4 個 → index 應自 `pc[2]` 起。
  - tag 不足:系統映射固定於 `0xFFFF_xxxx` 的前提下,閉合條件為
    index+tag 覆蓋 `pc[15:0]` 的變動位元 → tag 需 `pc[15:4]` = 12 bits
    (若僅保證 4KB 指令空間內無 alias,最少 `pc[11:4]` = 8 bits)。
  - 不變量:**`TAG_WIDTH = 有效位址位寬 − index 位數 − 2`**;
    module 預設參數(10+22=32 全覆蓋)本符合 cache 語意,是實例覆寫打破了它。
- alias 誤中的後果鏈(已由 §3 的 `pred_npc` 裁決結構性擋住錯誤執行;
  但 alias 端仍應修以免效能坑):非分支誤中 taken → 每次執行必 flush,
  且該指令不訓練 BTB,錯誤 entry 永不修正。
- `BTB_DEPTH=1023` 預設值為 `1024` 之 typo(深度須為 `2**BTB_WIDTH`)。

## 9. BHT counter 行為(觀察,非 bug)

- 現行 2-bit counter 為「跳變式」:WEAKLY_* 猜錯直接跳到對側 STRONGLY_*
  (`BranchPredict.v:79-83`),非標準飽和式(WT→WNT 漸變)。合法變體,hysteresis 較弱。
  新設計採標準飽和式或維持,spec 時拍板。

## 10. 已落地的現行 code 修正(branch `claude/core-readme-rtl-architecture-iku6pj`)

- `ab14112`:spec RAS "pop then push" 條件修正(`~pc_call & pc_return` → `pc_call & pc_return`);
  `pc_call/pc_return` 補 `tag_valid & pc_vld & ~pc_freeze` gating
  (BTB alias 與 stall 期間重複 push/pop 造成的 spec RAS 污染)。

## 11. 待正式 spec 拍板的清單

- [ ] `ghist` 保留與否(§4)
- [ ] history 事件定義(§6)
- [ ] BHT counter 樣式(§9)
- [ ] BTB index/tag 最終位寬與 `BTB_DEPTH` 修正(§8)
- [ ] Bht/Btb/Ras 儲存層讀寫口介面定義
- [ ] `ext_flush`(trap 來源 flush 通知)介面(§5)
- [ ] 訓練規則總表(何時 allocate BTB、counter 更新、RAS push/pop、history shift)
