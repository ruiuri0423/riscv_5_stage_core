/* Instruction Decoder Unit (IDU) - port shell only.
   Generated from RISCV_design.xlsx, sheet "Instruction Decoder".
   Rows noted "Use ... directly (no actual inst.)" share the id2ex_* wires
   at the hart top and are NOT declared as separate ports here.
   OP_WIDTH / FAULT_WIDTH are placeholders until the EX spec fixes the
   encodings. */
 `include "DEF_DEC.vh"

module InstructionDecoder #(
   parameter    ADDR_WIDTH = 32
  ,parameter    DATA_WIDTH = 32
  ,parameter    INST_WIDTH = 32
  ,parameter RF_ADDR_WIDTH = 5
  ,parameter   GHIST_WIDTH = 4
  ,parameter      OP_WIDTH = 8   // TBD by EX spec ("ex. units")
  ,parameter   FAULT_WIDTH = 4   // TBD by trap spec ("faults")
)(
  // IFU to IDU
    input wire                     if2id_valid
  ,output wire                     if2id_ready
  , input wire [   ADDR_WIDTH-1:0] if2id_pc
  , input wire [   INST_WIDTH-1:0] if2id_inst
  , input wire                     if2id_taken
  , input wire [   ADDR_WIDTH-1:0] if2id_npc
  , input wire                     if2id_hit
  , input wire [  GHIST_WIDTH-1:0] if2id_ghist
  , input wire                     if2id_fault
  // IDU to EXUs
  ,output wire                     id2ex_valid
  , input wire                     id2ex_ready
  ,output reg  [     OP_WIDTH-1:0] id2ex_op
  ,output reg                      id2ex_rd_we
  ,output reg  [RF_ADDR_WIDTH-1:0] id2ex_rd_addr
  ,output wire [   DATA_WIDTH-1:0] id2ex_rs1_data
  ,output wire [   DATA_WIDTH-1:0] id2ex_rs2_data
  ,output reg  [   DATA_WIDTH-1:0] id2ex_imm
  ,output reg  [   ADDR_WIDTH-1:0] id2ex_pc
  ,output reg  [  FAULT_WIDTH-1:0] id2ex_fault    // decoder error / ECALL / EBREAK
  // IDU to BPU (IFU metadata, transparent)
  ,output reg                      id2bp_taken
  ,output reg  [   ADDR_WIDTH-1:0] id2bp_npc
  ,output reg  [  GHIST_WIDTH-1:0] id2bp_ghist
  ,output reg                      id2bp_hit
  // IDU to CSR
  ,output reg                      id2csr_re
  ,output reg                      id2csr_we
  ,output reg  [   DATA_WIDTH-1:0] id2csr_data
  // IDU to LSU
  ,output reg                      id2lsu_we
  // IDU to RF (combinational read)
  ,output wire [RF_ADDR_WIDTH-1:0] id2rf_rs1_addr
  ,output wire [RF_ADDR_WIDTH-1:0] id2rf_rs2_addr
  , input wire [   DATA_WIDTH-1:0] id2rf_rs1_data
  , input wire [   DATA_WIDTH-1:0] id2rf_rs2_data
  // EXUs to IDU (forward)
  , input wire                     ex2id_fwd_valid
  ,output wire                     ex2id_fwd_ready
  , input wire                     ex2id_fwd_we
  , input wire [RF_ADDR_WIDTH-1:0] ex2id_fwd_rd
  , input wire [   DATA_WIDTH-1:0] ex2id_fwd_data
  // flush = (ex2if_valid & ex2if_ready & ex2if_flush)
  //       | (tr2if_valid & tr2if_ready & tr2if_flush)
  , input wire                     flush
  // clock & reset
  , input wire                     clk_id
  , input wire                     rstn_id
);

localparam OPCODE_WIDTH = 7;
localparam FUNCT3_WIDTH = 3;
localparam FUNCT7_WIDTH = 7;

wire [ OPCODE_WIDTH-1:0] opcode;
wire [RF_ADDR_WIDTH-1:0] rd_addr;
wire [ FUNCT3_WIDTH-1:0] funct3;
wire [RF_ADDR_WIDTH-1:0] rs1_addr;
wire [RF_ADDR_WIDTH-1:0] rs2_addr;
wire [ FUNCT7_WIDTH-1:0] funct7;
wire [   DATA_WIDTH-1:0] imm;

// One-hot instruction decode (46 instructions, RV32I + Zicsr)
wire                     is_addi;    //  1
wire                     is_slti;    //  2
wire                     is_sltiu;   //  3
wire                     is_andi;    //  4
wire                     is_ori;     //  5
wire                     is_xori;    //  6
wire                     is_slli;    //  7
wire                     is_srli;    //  8
wire                     is_srai;    //  9
wire                     is_lui;     // 10
wire                     is_auipc;   // 11
wire                     is_add;     // 12
wire                     is_slt;     // 13
wire                     is_sltu;    // 14
wire                     is_and;     // 15
wire                     is_or;      // 16
wire                     is_xor;     // 17
wire                     is_sll;     // 18
wire                     is_srl;     // 19
wire                     is_sub;     // 20
wire                     is_sra;     // 21
wire                     is_jal;     // 22
wire                     is_jalr;    // 23
wire                     is_beq;     // 24
wire                     is_bne;     // 25
wire                     is_blt;     // 26
wire                     is_bltu;    // 27
wire                     is_bge;     // 28
wire                     is_bgeu;    // 29
wire                     is_load_sb; // 30 LB
wire                     is_load_sh; // 31 LH
wire                     is_load_sw; // 32 LW
wire                     is_load_ub; // 33 LBU
wire                     is_load_uh; // 34 LHU
wire                     is_store_sb;// 35 SB
wire                     is_store_sh;// 36 SH
wire                     is_store_sw;// 37 SW
wire                     is_fence;   // 38
wire                     is_ecall;   // 39
wire                     is_ebreak;  // 40
wire                     is_csrrw;   // 41
wire                     is_csrrs;   // 42
wire                     is_csrrc;   // 43
wire                     is_csrrwi;  // 44
wire                     is_csrrsi;  // 45
wire                     is_csrrci;  // 46

wire                     r_type;
wire                     i_type;
wire                     s_type;
wire                     b_type;
wire                     u_type;
wire                     j_type;

wire                     if2id_hsk;
wire                     id2ex_hsk; 
wire                     id2ex_upd;

reg                      id2ex_valid_p;

reg  [RF_ADDR_WIDTH-1:0] rs1_addr_q;
reg  [RF_ADDR_WIDTH-1:0] rs2_addr_q;

wire [   DATA_WIDTH-1:0] id2ex_rs1_data_p;
reg  [   DATA_WIDTH-1:0] id2ex_rs1_data_q;
wire [   DATA_WIDTH-1:0] id2ex_rs2_data_p;
reg  [   DATA_WIDTH-1:0] id2ex_rs2_data_q;

wire                     ex2id_fwd_rs1_hit_p;
wire                     ex2id_fwd_rs2_hit_p;
wire                     ex2id_fwd_rs1_hit_q;
wire                     ex2id_fwd_rs2_hit_q;

//-----------------------------------------------------------------------------
// IFU to IDU
//-----------------------------------------------------------------------------
assign if2id_ready = (~id2ex_valid | id2ex_ready) & ~flush;
assign if2id_hsk   =   if2id_valid & if2id_ready;

//-----------------------------------------------------------------------------
// IDU to EXUs
//-----------------------------------------------------------------------------
assign id2ex_valid      = id2ex_valid_p & ~flush;
assign id2ex_hsk        = id2ex_valid & id2ex_ready;
assign id2ex_upd        = if2id_hsk;
assign id2ex_rs1_data_p = ex2id_fwd_rs1_hit_p ? ex2id_fwd_data : id2rf_rs1_data;
assign id2ex_rs2_data_p = ex2id_fwd_rs2_hit_p ? ex2id_fwd_data : id2rf_rs2_data;
assign id2ex_rs1_data   = ex2id_fwd_rs1_hit_q ? ex2id_fwd_data : id2ex_rs1_data_q;
assign id2ex_rs2_data   = ex2id_fwd_rs2_hit_q ? ex2id_fwd_data : id2ex_rs2_data_q;

always @(posedge clk_id or negedge rstn_id)
  begin
    if (!rstn_id)
      id2ex_valid_p <= 1'b0;
    else if (flush)
      id2ex_valid_p <= 1'b0;
    else
      case (id2ex_valid_p)
        1'b0: id2ex_valid_p <= if2id_hsk & ~id2ex_hsk;
        1'b1: id2ex_valid_p <= if2id_hsk | ~id2ex_hsk;
      endcase
  end

always @(posedge clk_id or negedge rstn_id)
  begin
    if (!rstn_id)
      begin
        id2ex_op         <= 'd0;
        id2ex_rd_we      <= 'd0;
        id2ex_rd_addr    <= 'd0;
        id2ex_rs1_data_q <= 'd0;
        id2ex_rs2_data_q <= 'd0;
        id2ex_imm        <= 'd0;
        id2ex_pc         <= 'd0;
        id2ex_fault      <= 'd0;
      end
    else if (flush)
      begin
        id2ex_op         <= 'd0;
        id2ex_rd_we      <= 'd0;
        id2ex_rd_addr    <= 'd0;
        id2ex_rs1_data_q <= 'd0;
        id2ex_rs2_data_q <= 'd0;
        id2ex_imm        <= 'd0;
        id2ex_pc         <= 'd0;
        id2ex_fault      <= 'd0;
      end
    else if (id2ex_upd)
      begin
        id2ex_op         <= 'd0;
        id2ex_rd_we      <=(i_type | r_type | u_type | j_type) & (rd_addr != 5'd0);
        id2ex_rd_addr    <= rd_addr;
        id2ex_rs1_data_q <= id2ex_rs1_data_p;
        id2ex_rs2_data_q <= id2ex_rs2_data_p;
        id2ex_imm        <= imm;
        id2ex_pc         <= if2id_pc;
        id2ex_fault      <= if2id_fault; // TODO : decoder error / ECALL / EBREAK
      end
  end

always @(posedge clk_id or negedge rstn_id)
  begin
    if (!rstn_id)
      begin
        rs1_addr_q <= 'd0;
        rs2_addr_q <= 'd0;
      end
    else if (flush)
      begin
        rs1_addr_q <= 'd0;
        rs2_addr_q <= 'd0;
      end
    else if (id2ex_upd)
      begin
        rs1_addr_q <= rs1_addr;
        rs2_addr_q <= rs2_addr;
      end
  end

//-----------------------------------------------------------------------------
// IFU to RF
//-----------------------------------------------------------------------------
assign id2rf_rs1_addr = rs1_addr;
assign id2rf_rs2_addr = rs2_addr;

//-----------------------------------------------------------------------------
// EXU forward to IDU
//-----------------------------------------------------------------------------
assign ex2id_fwd_ready     = id2ex_upd | id2ex_hsk; 
assign ex2id_fwd_rs1_hit_p = ex2id_fwd_valid & ex2id_fwd_ready & ex2id_fwd_we & (ex2id_fwd_rd == rs1_addr  );
assign ex2id_fwd_rs2_hit_p = ex2id_fwd_valid & ex2id_fwd_ready & ex2id_fwd_we & (ex2id_fwd_rd == rs1_addr  );
assign ex2id_fwd_rs1_hit_q = ex2id_fwd_valid & ex2id_fwd_ready & ex2id_fwd_we & (ex2id_fwd_rd == rs1_addr_q);
assign ex2id_fwd_rs2_hit_q = ex2id_fwd_valid & ex2id_fwd_ready & ex2id_fwd_we & (ex2id_fwd_rd == rs2_addr_q);

//-----------------------------------------------------------------------------
// Decoder Error / ECALL / EBREAK detection
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// IDU to BPU
//-----------------------------------------------------------------------------
always @(posedge clk_id or negedge rstn_id) 
  begin
    if (!rstn_id)
      begin
        id2bp_taken <= 'd0;
        id2bp_npc   <= 'd0;
        id2bp_ghist <= 'd0;
        id2bp_hit   <= 'd0;
      end
    else if (flush)
      begin
        id2bp_taken <= 'd0;
        id2bp_npc   <= 'd0;
        id2bp_ghist <= 'd0;
        id2bp_hit   <= 'd0;
      end
    else if (id2ex_upd)
      begin
        id2bp_taken <= if2id_taken;
        id2bp_npc   <= if2id_npc;
        id2bp_ghist <= if2id_ghist;
        id2bp_hit   <= if2id_hit;
      end
  end

//-----------------------------------------------------------------------------
// IDU to CSR
//-----------------------------------------------------------------------------
always @(posedge clk_id or negedge rstn_id)
  begin
    if (!rstn_id)
      begin
        id2csr_re   <= 'd0;
        id2csr_we   <= 'd0;
        id2csr_data <= 'd0;
      end
    else if (flush)
      begin
        id2csr_re   <= 'd0;
        id2csr_we   <= 'd0;
        id2csr_data <= 'd0;
      end
    else if (id2ex_upd)
      begin
        id2csr_re   <= ~((is_csrrw | is_csrrwi) & (rd_addr == 4'd0));
        id2csr_we   <= ~((is_csrrs | is_csrrc | is_csrrsi | is_csrrci) & (rd_addr == 4'd0));
        id2csr_data <=  ( is_csrrw  | is_csrrs  | is_csrrc ) ? id2ex_rs1_data_p  :
                        ( is_csrrwi | is_csrrsi | is_csrrci) ? {27'd0, imm[4:0]} : 32'd0;
      end              
  end                  
                       
//-----------------------------------------------------------------------------
// IDU to LSU
//-----------------------------------------------------------------------------
always @(posedge clk_id or negedge rstn_id) 
  begin
    if (!rstn_id)
      id2lsu_we <= 1'b0;
    else if (flush)
      id2lsu_we <= 1'b0;
    else if (id2ex_upd)
      id2lsu_we <= is_store_sb | is_store_sh | is_store_sw;
  end

//-----------------------------------------------------------------------------
// decoder logics
//-----------------------------------------------------------------------------
assign opcode   = if2id_inst[ 6: 0];
assign rd_addr  = if2id_inst[11: 7];
assign funct3   = if2id_inst[14:12];
assign rs1_addr = if2id_inst[19:15];
assign rs2_addr = if2id_inst[24:20];
assign funct7   = if2id_inst[31:25];

// --- per-instruction decode -------------------------------------------------
// OP-IMM
assign is_addi  = (opcode == `INST_OP_IMM) & (funct3 == `FUNCT_ADDI );
assign is_slti  = (opcode == `INST_OP_IMM) & (funct3 == `FUNCT_SLTI );
assign is_sltiu = (opcode == `INST_OP_IMM) & (funct3 == `FUNCT_SLTIU);
assign is_andi  = (opcode == `INST_OP_IMM) & (funct3 == `FUNCT_ANDI );
assign is_ori   = (opcode == `INST_OP_IMM) & (funct3 == `FUNCT_ORI  );
assign is_xori  = (opcode == `INST_OP_IMM) & (funct3 == `FUNCT_XORI );
assign is_slli  = (opcode == `INST_OP_IMM) & (funct3 == `FUNCT_SLLI ) & (funct7  == 7'b0000000);
assign is_srli  = (opcode == `INST_OP_IMM) & (funct3 == `FUNCT_SRLI ) & (funct7  == 7'b0000000);
assign is_srai  = (opcode == `INST_OP_IMM) & (funct3 == `FUNCT_SRAI ) & (funct7  == 7'b0100000);
// LUI / AUIPC
assign is_lui   = (opcode == `INST_LUI  );
assign is_auipc = (opcode == `INST_AUIPC);
// OP
assign is_add   = (opcode == `INST_OP) & (funct3 == `FUNCT_ADD ) & (funct7 == 7'b0000000);
assign is_sub   = (opcode == `INST_OP) & (funct3 == `FUNCT_SUB ) & (funct7 == 7'b0100000);
assign is_sll   = (opcode == `INST_OP) & (funct3 == `FUNCT_SLL ) & (funct7 == 7'b0000000);
assign is_slt   = (opcode == `INST_OP) & (funct3 == `FUNCT_SLT ) & (funct7 == 7'b0000000);
assign is_sltu  = (opcode == `INST_OP) & (funct3 == `FUNCT_SLTU) & (funct7 == 7'b0000000);
assign is_xor   = (opcode == `INST_OP) & (funct3 == `FUNCT_XOR ) & (funct7 == 7'b0000000);
assign is_srl   = (opcode == `INST_OP) & (funct3 == `FUNCT_SRL ) & (funct7 == 7'b0000000);
assign is_sra   = (opcode == `INST_OP) & (funct3 == `FUNCT_SRA ) & (funct7 == 7'b0100000);
assign is_or    = (opcode == `INST_OP) & (funct3 == `FUNCT_OR  ) & (funct7 == 7'b0000000);
assign is_and   = (opcode == `INST_OP) & (funct3 == `FUNCT_AND ) & (funct7 == 7'b0000000);
// JAL / JALR
assign is_jal   = (opcode == `INST_JAL );
assign is_jalr  = (opcode == `INST_JALR) & (funct3 == `FUNCT_JALR);
// BRANCH
assign is_beq   = (opcode == `INST_BRANCH) & (funct3 == `FUNCT_BEQ );
assign is_bne   = (opcode == `INST_BRANCH) & (funct3 == `FUNCT_BNE );
assign is_blt   = (opcode == `INST_BRANCH) & (funct3 == `FUNCT_BLT );
assign is_bltu  = (opcode == `INST_BRANCH) & (funct3 == `FUNCT_BLTU);
assign is_bge   = (opcode == `INST_BRANCH) & (funct3 == `FUNCT_BGE );
assign is_bgeu  = (opcode == `INST_BRANCH) & (funct3 == `FUNCT_BGEU);
// LOAD / STORE (per access size; _s* = sign-extended, _u* = zero-extended)
assign is_load_sb  = (opcode == `INST_LOAD ) & (funct3 == `FUNCT_LB );
assign is_load_sh  = (opcode == `INST_LOAD ) & (funct3 == `FUNCT_LH );
assign is_load_sw  = (opcode == `INST_LOAD ) & (funct3 == `FUNCT_LW );
assign is_load_ub  = (opcode == `INST_LOAD ) & (funct3 == `FUNCT_LBU);
assign is_load_uh  = (opcode == `INST_LOAD ) & (funct3 == `FUNCT_LHU);
assign is_store_sb = (opcode == `INST_STORE) & (funct3 == `FUNCT_SB );
assign is_store_sh = (opcode == `INST_STORE) & (funct3 == `FUNCT_SH );
assign is_store_sw = (opcode == `INST_STORE) & (funct3 == `FUNCT_SW );
// MISC-MEM
assign is_fence = (opcode == `INST_MISC_MEM) & (funct3 == 3'b000);
// SYSTEM
assign is_ecall  = (opcode == `INST_SYSTEM) & (funct3 == 3'b000) & (if2id_inst[31:20] == `FUNCT_ECALL );
assign is_ebreak = (opcode == `INST_SYSTEM) & (funct3 == 3'b000) & (if2id_inst[31:20] == `FUNCT_EBREAK);
assign is_csrrw  = (opcode == `INST_SYSTEM) & (funct3 == `FUNCT_CSRRW );
assign is_csrrs  = (opcode == `INST_SYSTEM) & (funct3 == `FUNCT_CSRRS );
assign is_csrrc  = (opcode == `INST_SYSTEM) & (funct3 == `FUNCT_CSRRC );
assign is_csrrwi = (opcode == `INST_SYSTEM) & (funct3 == `FUNCT_CSRRWI);
assign is_csrrsi = (opcode == `INST_SYSTEM) & (funct3 == `FUNCT_CSRRSI);
assign is_csrrci = (opcode == `INST_SYSTEM) & (funct3 == `FUNCT_CSRRCI);

// --- format decode (OR of the one-hot terms) --------------------------------
assign r_type   = is_add   | is_sub   | is_sll   | is_slt   | is_sltu
                | is_xor   | is_srl   | is_sra   | is_or    | is_and  ;
assign i_type   = is_addi    | is_slti    | is_sltiu   | is_andi  | is_ori
                | is_xori    | is_slli    | is_srli    | is_srai  | is_jalr
                | is_load_sb | is_load_sh | is_load_sw
                | is_load_ub | is_load_uh
                | is_fence   | is_ecall   | is_ebreak
                | is_csrrw   | is_csrrs   | is_csrrc
                | is_csrrwi  | is_csrrsi  | is_csrrci;
assign s_type   = is_store_sb | is_store_sh | is_store_sw;
assign b_type   = is_beq   | is_bne   | is_blt   | is_bltu  | is_bge   | is_bgeu ;
assign u_type   = is_lui   | is_auipc ;
assign j_type   = is_jal   ;

assign imm      = i_type ? `I_TYPE_IMM :
                  s_type ? `S_TYPE_IMM :
                  b_type ? `B_TYPE_IMM :
                  u_type ? `U_TYPE_IMM :
                  j_type ? `J_TYPE_IMM : 32'b0;
endmodule 