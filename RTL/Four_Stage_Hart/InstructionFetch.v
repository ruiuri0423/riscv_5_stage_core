/* Instruction Fetch Unit (IFU) - port shell only.
   Generated from RISCV_design.xlsx, sheet "Instruction Fetch". */

module InstructionFetch #(
   parameter  ADDR_WIDTH = 32
  ,parameter  DATA_WIDTH = 32
  ,parameter  INST_WIDTH = 32
  ,parameter  PROT_WIDTH = 3
  ,parameter  RESP_WIDTH = 2
  ,parameter CAUSE_WIDTH = 2
)(
  // AXI-Lite (read-only master, outstanding = 1)
   output wire                   m_axi_arvalid_if
  , input wire                   m_axi_arready_if
  ,output wire [ ADDR_WIDTH-1:0] m_axi_araddr_if
  ,output wire [ PROT_WIDTH-1:0] m_axi_arprot_if
  , input wire                   m_axi_rvalid_if
  ,output wire                   m_axi_rready_if
  , input wire [ DATA_WIDTH-1:0] m_axi_rdata_if
  , input wire [ RESP_WIDTH-1:0] m_axi_rresp_if
  // IFU to IDU
  ,output wire                   if2id_valid
  , input wire                   if2id_ready
  ,output wire [ ADDR_WIDTH-1:0] if2id_pc
  ,output wire [ INST_WIDTH-1:0] if2id_inst
  ,output wire                   if2id_taken
  ,output wire [ ADDR_WIDTH-1:0] if2id_npc
  ,output wire                   if2id_hit
  ,output wire                   if2id_fault      // instruction fetch error
  // IFU to BPU (query / response)
  ,output wire                   if2bp_query
  ,output wire [ ADDR_WIDTH-1:0] if2bp_pc
  , input wire                   if2bp_taken
  , input wire [ ADDR_WIDTH-1:0] if2bp_npc
  , input wire                   if2bp_hit
  // EXUs to IFU (redirection, flush 2nd priority)
  , input wire                   ex2if_valid
  ,output wire                   ex2if_ready
  , input wire                   ex2if_flush
  , input wire [ ADDR_WIDTH-1:0] ex2if_pc
  , input wire [CAUSE_WIDTH-1:0] ex2if_cause
  // TRAP to IFU (redirection, flush 1st priority)
  , input wire                   tr2if_valid
  ,output wire                   tr2if_ready
  , input wire                   tr2if_flush
  , input wire [ ADDR_WIDTH-1:0] tr2if_pc
  , input wire [CAUSE_WIDTH-1:0] tr2if_cause
  // CFG
  , input wire [ ADDR_WIDTH-1:0] r_BOOT_ADDR
  // clock & reset (aclk/arstn synchronous to clk/rstn in current plan)
  , input wire                   clk_if
  , input wire                   aclk_if
  , input wire                   rstn_if
  , input wire                   arstn_if
);

endmodule
