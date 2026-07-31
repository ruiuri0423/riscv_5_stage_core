/* Instruction Decoder Unit (IDU) - port shell only.
   Generated from RISCV_design.xlsx, sheet "Instruction Decoder".
   Rows noted "Use ... directly (no actual inst.)" share the id2ex_* wires
   at the hart top and are NOT declared as separate ports here.
   OP_WIDTH / FAULT_WIDTH are placeholders until the EX spec fixes the
   encodings. */

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
  , input wire                     if2id_fault
  // IDU to EXUs
  ,output wire                     id2ex_valid
  , input wire                     id2ex_ready
  ,output wire [     OP_WIDTH-1:0] id2ex_op
  ,output wire                     id2ex_rd_we
  ,output wire [RF_ADDR_WIDTH-1:0] id2ex_rd_addr
  ,output wire [   DATA_WIDTH-1:0] id2ex_rs1_data
  ,output wire [   DATA_WIDTH-1:0] id2ex_rs2_data
  ,output wire [   DATA_WIDTH-1:0] id2ex_imm
  ,output wire [   ADDR_WIDTH-1:0] id2ex_pc
  ,output wire [  FAULT_WIDTH-1:0] id2ex_fault    // decoder error / ECALL / EBREAK
  // IDU to BPU (IFU metadata, transparent)
  ,output wire                     id2bp_taken
  ,output wire [   ADDR_WIDTH-1:0] id2bp_npc
  ,output wire [  GHIST_WIDTH-1:0] id2bp_ghist
  ,output wire                     id2bp_hit
  // IDU to CSR
  ,output wire                     id2csr_re
  ,output wire                     id2csr_we
  ,output wire [   DATA_WIDTH-1:0] id2csr_data
  // IDU to LSU
  ,output wire                     id2lsu_we
  // IDU to RF (combinational read)
  ,output wire [RF_ADDR_WIDTH-1:0] id2rf_rs1_addr
  ,output wire [RF_ADDR_WIDTH-1:0] id2rf_rs2_addr
  , input wire [   DATA_WIDTH-1:0] id2rf_rs1_data
  , input wire [   DATA_WIDTH-1:0] id2rf_rs2_data
  // EXUs to IDU (forward)
  , input wire                     ex2id_valid
  ,output wire                     ex2id_ready
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

endmodule
