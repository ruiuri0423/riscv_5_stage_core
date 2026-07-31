/* Execution Units (EXU: ALU / BPU / LSU / CSR) - port shell only.
   Generated from RISCV_design.xlsx, sheet "Execution Units".
   Rows noted "Use ... directly (no actual inst.)" share the id2ex_* wires
   at the hart top and are NOT declared as separate ports here.
   CSR unit lives inside EXU; the trap unit is external (see TrapUnit.v),
   hence tr2csr_* are inputs and csr2tr_* are outputs of this module. */

module ExecutionUnits #(
   parameter    ADDR_WIDTH = 32
  ,parameter    DATA_WIDTH = 32
  ,parameter RF_ADDR_WIDTH = 5
  ,parameter   GHIST_WIDTH = 4
  ,parameter      OP_WIDTH = 8   // TBD by EX spec ("ex. units")
  ,parameter   FAULT_WIDTH = 4   // TBD by trap spec ("faults")
  ,parameter   CAUSE_WIDTH = 2
  // AXI4 (LSU master)
  ,parameter      ID_WIDTH = 4
  ,parameter     LEN_WIDTH = 8
  ,parameter    SIZE_WIDTH = 4
  ,parameter   BURST_WIDTH = 2
  ,parameter    LOCK_WIDTH = 1
  ,parameter   CACHE_WIDTH = 4
  ,parameter    PROT_WIDTH = 3
  ,parameter     QOS_WIDTH = 4
  ,parameter  REGION_WIDTH = 4
  ,parameter    USER_WIDTH = 32
  ,parameter    STRB_WIDTH = 4
  ,parameter    RESP_WIDTH = 2
)(
  // IDU to EXUs
    input wire                     id2ex_valid
  ,output wire                     id2ex_ready
  , input wire [     OP_WIDTH-1:0] id2ex_op
  , input wire                     id2ex_rd_we
  , input wire [RF_ADDR_WIDTH-1:0] id2ex_rd_addr
  , input wire [   DATA_WIDTH-1:0] id2ex_rs1_data
  , input wire [   DATA_WIDTH-1:0] id2ex_rs2_data
  , input wire [   DATA_WIDTH-1:0] id2ex_imm      // for CSR, msb padded with 0
  , input wire [   ADDR_WIDTH-1:0] id2ex_pc
  , input wire [  FAULT_WIDTH-1:0] id2ex_fault    // decoder error / ECALL / EBREAK
  // IDU to BPU (IFU metadata, transparent)
  , input wire                     id2bp_taken
  , input wire [   ADDR_WIDTH-1:0] id2bp_npc
  , input wire [  GHIST_WIDTH-1:0] id2bp_ghist
  , input wire                     id2bp_hit
  // IDU to CSR
  , input wire                     id2csr_re
  , input wire                     id2csr_we
  , input wire [   DATA_WIDTH-1:0] id2csr_data
  // IDU to LSU
  , input wire                     id2lsu_we
  // TRAP to CSR
  , input wire                     tr2csr_valid
  ,output wire                     tr2csr_ready
  , input wire                     tr2csr_we
  , input wire [   ADDR_WIDTH-1:0] tr2csr_mepc
  , input wire [   DATA_WIDTH-1:0] tr2csr_mtval
  , input wire [   DATA_WIDTH-1:0] tr2csr_mcause
  , input wire [   DATA_WIDTH-1:0] tr2csr_mstatus
  // CSR to TRAP
  ,output wire                     csr2tr_MIE
  ,output wire [   DATA_WIDTH-1:0] csr2tr_mie
  ,output wire [   DATA_WIDTH-1:0] csr2tr_mip
  ,output wire [   ADDR_WIDTH-1:0] csr2tr_mepc
  ,output wire [   ADDR_WIDTH-1:0] csr2tr_mtvec
  // EXUs to RF (writeback)
  ,output wire                     ex2rf_valid
  , input wire                     ex2rf_ready
  ,output wire                     ex2rf_rd_we
  ,output wire [RF_ADDR_WIDTH-1:0] ex2rf_rd_addr
  ,output wire [   DATA_WIDTH-1:0] ex2rf_rd_data
  // EXUs to TRAP
  ,output wire                     ex2tr_valid
  , input wire                     ex2tr_ready
  ,output wire [   ADDR_WIDTH-1:0] ex2tr_pc
  ,output wire [   ADDR_WIDTH-1:0] ex2tr_npc
  ,output wire [  FAULT_WIDTH-1:0] ex2tr_faults   // misaligned / access fault
  // EXUs to IFU (redirection)
  ,output wire                     ex2if_valid
  , input wire                     ex2if_ready
  ,output wire                     ex2if_flush
  ,output wire [   ADDR_WIDTH-1:0] ex2if_pc
  ,output wire [  CAUSE_WIDTH-1:0] ex2if_cause
  // EX to ID (forward)
  ,output wire                     ex2id_fwd_valid
  , input wire                     ex2id_fwd_ready
  ,output wire                     ex2id_fwd_we
  ,output wire [RF_ADDR_WIDTH-1:0] ex2id_fwd_rd
  ,output wire [   DATA_WIDTH-1:0] ex2id_fwd_data
  // AXI4 (LSU master)
  , input wire                     m_axi_awready_lsu
  ,output wire                     m_axi_awvalid_lsu
  ,output wire [   ADDR_WIDTH-1:0] m_axi_awaddr_lsu
  ,output wire [   PROT_WIDTH-1:0] m_axi_awprot_lsu
  ,output wire [     ID_WIDTH-1:0] m_axi_awid_lsu
  ,output wire [    LEN_WIDTH-1:0] m_axi_awlen_lsu
  ,output wire [   SIZE_WIDTH-1:0] m_axi_awsize_lsu
  ,output wire [  BURST_WIDTH-1:0] m_axi_awburst_lsu
  ,output wire [   LOCK_WIDTH-1:0] m_axi_awlock_lsu
  ,output wire [  CACHE_WIDTH-1:0] m_axi_awcache_lsu
  ,output wire [    QOS_WIDTH-1:0] m_axi_awqos_lsu
  ,output wire [ REGION_WIDTH-1:0] m_axi_awregion_lsu
  ,output wire [   USER_WIDTH-1:0] m_axi_awuser_lsu
  , input wire                     m_axi_wready_lsu
  ,output wire                     m_axi_wvalid_lsu
  ,output wire [   DATA_WIDTH-1:0] m_axi_wdata_lsu
  ,output wire [   STRB_WIDTH-1:0] m_axi_wstrb_lsu
  ,output wire                     m_axi_wlast_lsu
  ,output wire [   USER_WIDTH-1:0] m_axi_wuser_lsu
  ,output wire                     m_axi_bready_lsu
  , input wire                     m_axi_bvalid_lsu
  , input wire [   RESP_WIDTH-1:0] m_axi_bresp_lsu
  , input wire [     ID_WIDTH-1:0] m_axi_bid_lsu
  , input wire [   USER_WIDTH-1:0] m_axi_buser_lsu
  , input wire                     m_axi_arready_lsu
  ,output wire                     m_axi_arvalid_lsu
  ,output wire [   ADDR_WIDTH-1:0] m_axi_araddr_lsu
  ,output wire [   PROT_WIDTH-1:0] m_axi_arprot_lsu
  ,output wire [     ID_WIDTH-1:0] m_axi_arid_lsu
  ,output wire [    LEN_WIDTH-1:0] m_axi_arlen_lsu
  ,output wire [   SIZE_WIDTH-1:0] m_axi_arsize_lsu
  ,output wire [  BURST_WIDTH-1:0] m_axi_arburst_lsu
  ,output wire [   LOCK_WIDTH-1:0] m_axi_arlock_lsu
  ,output wire [  CACHE_WIDTH-1:0] m_axi_arcache_lsu
  ,output wire [    QOS_WIDTH-1:0] m_axi_arqos_lsu
  ,output wire [ REGION_WIDTH-1:0] m_axi_arregion_lsu
  ,output wire [   USER_WIDTH-1:0] m_axi_aruser_lsu
  ,output wire                     m_axi_rready_lsu
  , input wire                     m_axi_rvalid_lsu
  , input wire [   DATA_WIDTH-1:0] m_axi_rdata_lsu
  , input wire [   RESP_WIDTH-1:0] m_axi_rresp_lsu
  , input wire [     ID_WIDTH-1:0] m_axi_rid_lsu
  , input wire                     m_axi_rlast_lsu
  , input wire [   USER_WIDTH-1:0] m_axi_ruser_lsu
  // clock & reset (aclk/arstn synchronous to clk/rstn in current plan)
  , input wire                     clk_ex
  , input wire                     aclk_ex
  , input wire                     rstn_ex
  , input wire                     arstn_ex
);

endmodule
