/* Four-Stage Hart Top - structural wiring only.
   Instantiates InstructionFetch / InstructionDecoder / ExecutionUnits /
   RegisterFile / TrapUnit per RISCV_design.xlsx interface sheets.
   The only combinational glue is the IDU flush term, whose definition
   comes from the Instruction Decoder sheet (S/N 51):
     flush = (ex2if_valid & ex2if_ready & ex2if_flush)
           | (tr2if_valid & tr2if_ready & tr2if_flush)
   Shared signals noted "no actual inst." in the sheets ride the id2ex_*
   wires and are fanned out inside ExecutionUnits. */

module HartTop #(
   parameter    ADDR_WIDTH = 32
  ,parameter    DATA_WIDTH = 32
  ,parameter    INST_WIDTH = 32
  ,parameter RF_ADDR_WIDTH = 5
  ,parameter   GHIST_WIDTH = 4
  ,parameter      OP_WIDTH = 8   // TBD by EX spec
  ,parameter   FAULT_WIDTH = 4   // TBD by trap spec
  ,parameter   CAUSE_WIDTH = 2
  // AXI
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
  // AXI-Lite instruction port (IFU master)
   output wire                    m_axi_arvalid_if
  , input wire                    m_axi_arready_if
  ,output wire [  ADDR_WIDTH-1:0] m_axi_araddr_if
  ,output wire [  PROT_WIDTH-1:0] m_axi_arprot_if
  , input wire                    m_axi_rvalid_if
  ,output wire                    m_axi_rready_if
  , input wire [  DATA_WIDTH-1:0] m_axi_rdata_if
  , input wire [  RESP_WIDTH-1:0] m_axi_rresp_if
  // AXI4 data port (LSU master)
  , input wire                    m_axi_awready_lsu
  ,output wire                    m_axi_awvalid_lsu
  ,output wire [  ADDR_WIDTH-1:0] m_axi_awaddr_lsu
  ,output wire [  PROT_WIDTH-1:0] m_axi_awprot_lsu
  ,output wire [    ID_WIDTH-1:0] m_axi_awid_lsu
  ,output wire [   LEN_WIDTH-1:0] m_axi_awlen_lsu
  ,output wire [  SIZE_WIDTH-1:0] m_axi_awsize_lsu
  ,output wire [ BURST_WIDTH-1:0] m_axi_awburst_lsu
  ,output wire [  LOCK_WIDTH-1:0] m_axi_awlock_lsu
  ,output wire [ CACHE_WIDTH-1:0] m_axi_awcache_lsu
  ,output wire [   QOS_WIDTH-1:0] m_axi_awqos_lsu
  ,output wire [REGION_WIDTH-1:0] m_axi_awregion_lsu
  ,output wire [  USER_WIDTH-1:0] m_axi_awuser_lsu
  , input wire                    m_axi_wready_lsu
  ,output wire                    m_axi_wvalid_lsu
  ,output wire [  DATA_WIDTH-1:0] m_axi_wdata_lsu
  ,output wire [  STRB_WIDTH-1:0] m_axi_wstrb_lsu
  ,output wire                    m_axi_wlast_lsu
  ,output wire [  USER_WIDTH-1:0] m_axi_wuser_lsu
  ,output wire                    m_axi_bready_lsu
  , input wire                    m_axi_bvalid_lsu
  , input wire [  RESP_WIDTH-1:0] m_axi_bresp_lsu
  , input wire [    ID_WIDTH-1:0] m_axi_bid_lsu
  , input wire [  USER_WIDTH-1:0] m_axi_buser_lsu
  , input wire                    m_axi_arready_lsu
  ,output wire                    m_axi_arvalid_lsu
  ,output wire [  ADDR_WIDTH-1:0] m_axi_araddr_lsu
  ,output wire [  PROT_WIDTH-1:0] m_axi_arprot_lsu
  ,output wire [    ID_WIDTH-1:0] m_axi_arid_lsu
  ,output wire [   LEN_WIDTH-1:0] m_axi_arlen_lsu
  ,output wire [  SIZE_WIDTH-1:0] m_axi_arsize_lsu
  ,output wire [ BURST_WIDTH-1:0] m_axi_arburst_lsu
  ,output wire [  LOCK_WIDTH-1:0] m_axi_arlock_lsu
  ,output wire [ CACHE_WIDTH-1:0] m_axi_arcache_lsu
  ,output wire [   QOS_WIDTH-1:0] m_axi_arqos_lsu
  ,output wire [REGION_WIDTH-1:0] m_axi_arregion_lsu
  ,output wire [  USER_WIDTH-1:0] m_axi_aruser_lsu
  ,output wire                    m_axi_rready_lsu
  , input wire                    m_axi_rvalid_lsu
  , input wire [  DATA_WIDTH-1:0] m_axi_rdata_lsu
  , input wire [  RESP_WIDTH-1:0] m_axi_rresp_lsu
  , input wire [    ID_WIDTH-1:0] m_axi_rid_lsu
  , input wire                    m_axi_rlast_lsu
  , input wire [  USER_WIDTH-1:0] m_axi_ruser_lsu
  // CFG
  , input wire [  ADDR_WIDTH-1:0] r_BOOT_ADDR
  // clock & reset (aclk/arstn synchronous to clk/rstn in current plan)
  , input wire                    clk
  , input wire                    aclk
  , input wire                    rstn
  , input wire                    arstn
);

// IFU to IDU
wire                     if2id_valid;
wire                     if2id_ready;
wire [   ADDR_WIDTH-1:0] if2id_pc;
wire [   INST_WIDTH-1:0] if2id_inst;
wire                     if2id_taken;
wire [   ADDR_WIDTH-1:0] if2id_npc;
wire                     if2id_hit;
wire                     if2id_fault;

// IFU to BPU (query / response)
wire                     if2bp_query;
wire [   ADDR_WIDTH-1:0] if2bp_pc;
wire                     if2bp_taken;
wire [   ADDR_WIDTH-1:0] if2bp_npc;
wire                     if2bp_hit;

// IDU to EXUs
wire                     id2ex_valid;
wire                     id2ex_ready;
wire [     OP_WIDTH-1:0] id2ex_op;
wire                     id2ex_rd_we;
wire [RF_ADDR_WIDTH-1:0] id2ex_rd_addr;
wire [   DATA_WIDTH-1:0] id2ex_rs1_data;
wire [   DATA_WIDTH-1:0] id2ex_rs2_data;
wire [   DATA_WIDTH-1:0] id2ex_imm;
wire [   ADDR_WIDTH-1:0] id2ex_pc;
wire [  FAULT_WIDTH-1:0] id2ex_fault;
wire                     id2bp_taken;
wire [   ADDR_WIDTH-1:0] id2bp_npc;
wire [  GHIST_WIDTH-1:0] id2bp_ghist;
wire                     id2bp_hit;
wire                     id2csr_re;
wire                     id2csr_we;
wire [   DATA_WIDTH-1:0] id2csr_data;
wire                     id2lsu_we;

// IDU to RF
wire [RF_ADDR_WIDTH-1:0] id2rf_rs1_addr;
wire [RF_ADDR_WIDTH-1:0] id2rf_rs2_addr;
wire [   DATA_WIDTH-1:0] id2rf_rs1_data;
wire [   DATA_WIDTH-1:0] id2rf_rs2_data;

// EXUs to IDU (forward)
wire                     ex2id_fwd_valid;
wire                     ex2id_fwd_ready;
wire                     ex2id_fwd_we;
wire [RF_ADDR_WIDTH-1:0] ex2id_fwd_rd;
wire [   DATA_WIDTH-1:0] ex2id_fwd_data;

// EXUs to RF
wire                     ex2rf_valid;
wire                     ex2rf_ready;
wire                     ex2rf_rd_we;
wire [RF_ADDR_WIDTH-1:0] ex2rf_rd_addr;
wire [   DATA_WIDTH-1:0] ex2rf_rd_data;

// EXUs to TRAP
wire                     ex2tr_valid;
wire                     ex2tr_ready;
wire [   ADDR_WIDTH-1:0] ex2tr_pc;
wire [   ADDR_WIDTH-1:0] ex2tr_npc;
wire [  FAULT_WIDTH-1:0] ex2tr_faults;

// EXUs to IFU (redirection, flush 2nd priority)
wire                     ex2if_valid;
wire                     ex2if_ready;
wire                     ex2if_flush;
wire [   ADDR_WIDTH-1:0] ex2if_pc;
wire [  CAUSE_WIDTH-1:0] ex2if_cause;

// TRAP to IFU (redirection, flush 1st priority)
wire                     tr2if_valid;
wire                     tr2if_ready;
wire                     tr2if_flush;
wire [   ADDR_WIDTH-1:0] tr2if_pc;
wire [  CAUSE_WIDTH-1:0] tr2if_cause;

// TRAP to CSR / CSR to TRAP
wire                     tr2csr_valid;
wire                     tr2csr_ready;
wire                     tr2csr_we;
wire [   ADDR_WIDTH-1:0] tr2csr_mepc;
wire [   DATA_WIDTH-1:0] tr2csr_mtval;
wire [   DATA_WIDTH-1:0] tr2csr_mcause;
wire [   DATA_WIDTH-1:0] tr2csr_mstatus;
wire                     csr2tr_MIE;
wire [   DATA_WIDTH-1:0] csr2tr_mie;
wire [   DATA_WIDTH-1:0] csr2tr_mip;
wire [   ADDR_WIDTH-1:0] csr2tr_mepc;
wire [   ADDR_WIDTH-1:0] csr2tr_mtvec;

// Flush broadcast (definition from Instruction Decoder sheet, S/N 51)
wire flush = (ex2if_valid & ex2if_ready & ex2if_flush)
           | (tr2if_valid & tr2if_ready & tr2if_flush);

InstructionFetch #(
   .ADDR_WIDTH  ( ADDR_WIDTH  )
  ,.DATA_WIDTH  ( DATA_WIDTH  )
  ,.INST_WIDTH  ( INST_WIDTH  )
  ,.PROT_WIDTH  ( PROT_WIDTH  )
  ,.RESP_WIDTH  ( RESP_WIDTH  )
  ,.CAUSE_WIDTH ( CAUSE_WIDTH )
) u_ifu (
   .m_axi_arvalid_if ( m_axi_arvalid_if )
  ,.m_axi_arready_if ( m_axi_arready_if )
  ,.m_axi_araddr_if  ( m_axi_araddr_if  )
  ,.m_axi_arprot_if  ( m_axi_arprot_if  )
  ,.m_axi_rvalid_if  ( m_axi_rvalid_if  )
  ,.m_axi_rready_if  ( m_axi_rready_if  )
  ,.m_axi_rdata_if   ( m_axi_rdata_if   )
  ,.m_axi_rresp_if   ( m_axi_rresp_if   )
  ,.if2id_valid      ( if2id_valid      )
  ,.if2id_ready      ( if2id_ready      )
  ,.if2id_pc         ( if2id_pc         )
  ,.if2id_inst       ( if2id_inst       )
  ,.if2id_taken      ( if2id_taken      )
  ,.if2id_npc        ( if2id_npc        )
  ,.if2id_hit        ( if2id_hit        )
  ,.if2id_fault      ( if2id_fault      )
  ,.if2bp_query      ( if2bp_query      )
  ,.if2bp_pc         ( if2bp_pc         )
  ,.if2bp_taken      ( if2bp_taken      )
  ,.if2bp_npc        ( if2bp_npc        )
  ,.if2bp_hit        ( if2bp_hit        )
  ,.ex2if_valid      ( ex2if_valid      )
  ,.ex2if_ready      ( ex2if_ready      )
  ,.ex2if_flush      ( ex2if_flush      )
  ,.ex2if_pc         ( ex2if_pc         )
  ,.ex2if_cause      ( ex2if_cause      )
  ,.tr2if_valid      ( tr2if_valid      )
  ,.tr2if_ready      ( tr2if_ready      )
  ,.tr2if_flush      ( tr2if_flush      )
  ,.tr2if_pc         ( tr2if_pc         )
  ,.tr2if_cause      ( tr2if_cause      )
  ,.r_BOOT_ADDR      ( r_BOOT_ADDR      )
  ,.clk_if           ( clk              )
  ,.aclk_if          ( aclk             )
  ,.rstn_if          ( rstn             )
  ,.arstn_if         ( arstn            )
);

InstructionDecoder #(
   .ADDR_WIDTH    ( ADDR_WIDTH    )
  ,.DATA_WIDTH    ( DATA_WIDTH    )
  ,.INST_WIDTH    ( INST_WIDTH    )
  ,.RF_ADDR_WIDTH ( RF_ADDR_WIDTH )
  ,.GHIST_WIDTH   ( GHIST_WIDTH   )
  ,.OP_WIDTH      ( OP_WIDTH      )
  ,.FAULT_WIDTH   ( FAULT_WIDTH   )
) u_idu (
   .if2id_valid     ( if2id_valid     )
  ,.if2id_ready     ( if2id_ready     )
  ,.if2id_pc        ( if2id_pc        )
  ,.if2id_inst      ( if2id_inst      )
  ,.if2id_taken     ( if2id_taken     )
  ,.if2id_npc       ( if2id_npc       )
  ,.if2id_hit       ( if2id_hit       )
  ,.if2id_fault     ( if2id_fault     )
  ,.id2ex_valid     ( id2ex_valid     )
  ,.id2ex_ready     ( id2ex_ready     )
  ,.id2ex_op        ( id2ex_op        )
  ,.id2ex_rd_we     ( id2ex_rd_we     )
  ,.id2ex_rd_addr   ( id2ex_rd_addr   )
  ,.id2ex_rs1_data  ( id2ex_rs1_data  )
  ,.id2ex_rs2_data  ( id2ex_rs2_data  )
  ,.id2ex_imm       ( id2ex_imm       )
  ,.id2ex_pc        ( id2ex_pc        )
  ,.id2ex_fault     ( id2ex_fault     )
  ,.id2bp_taken     ( id2bp_taken     )
  ,.id2bp_npc       ( id2bp_npc       )
  ,.id2bp_ghist     ( id2bp_ghist     )
  ,.id2bp_hit       ( id2bp_hit       )
  ,.id2csr_re       ( id2csr_re       )
  ,.id2csr_we       ( id2csr_we       )
  ,.id2csr_data     ( id2csr_data     )
  ,.id2lsu_we       ( id2lsu_we       )
  ,.id2rf_rs1_addr  ( id2rf_rs1_addr  )
  ,.id2rf_rs2_addr  ( id2rf_rs2_addr  )
  ,.id2rf_rs1_data  ( id2rf_rs1_data  )
  ,.id2rf_rs2_data  ( id2rf_rs2_data  )
  ,.ex2id_fwd_valid ( ex2id_fwd_valid )
  ,.ex2id_fwd_ready ( ex2id_fwd_ready )
  ,.ex2id_fwd_we    ( ex2id_fwd_we    )
  ,.ex2id_fwd_rd    ( ex2id_fwd_rd    )
  ,.ex2id_fwd_data  ( ex2id_fwd_data  )
  ,.flush           ( flush           )
  ,.clk_id          ( clk             )
  ,.rstn_id         ( rstn            )
);

ExecutionUnits #(
   .ADDR_WIDTH    ( ADDR_WIDTH    )
  ,.DATA_WIDTH    ( DATA_WIDTH    )
  ,.RF_ADDR_WIDTH ( RF_ADDR_WIDTH )
  ,.GHIST_WIDTH   ( GHIST_WIDTH   )
  ,.OP_WIDTH      ( OP_WIDTH      )
  ,.FAULT_WIDTH   ( FAULT_WIDTH   )
  ,.CAUSE_WIDTH   ( CAUSE_WIDTH   )
  ,.ID_WIDTH      ( ID_WIDTH      )
  ,.LEN_WIDTH     ( LEN_WIDTH     )
  ,.SIZE_WIDTH    ( SIZE_WIDTH    )
  ,.BURST_WIDTH   ( BURST_WIDTH   )
  ,.LOCK_WIDTH    ( LOCK_WIDTH    )
  ,.CACHE_WIDTH   ( CACHE_WIDTH   )
  ,.PROT_WIDTH    ( PROT_WIDTH    )
  ,.QOS_WIDTH     ( QOS_WIDTH     )
  ,.REGION_WIDTH  ( REGION_WIDTH  )
  ,.USER_WIDTH    ( USER_WIDTH    )
  ,.STRB_WIDTH    ( STRB_WIDTH    )
  ,.RESP_WIDTH    ( RESP_WIDTH    )
) u_exu (
   .id2ex_valid        ( id2ex_valid        )
  ,.id2ex_ready        ( id2ex_ready        )
  ,.id2ex_op           ( id2ex_op           )
  ,.id2ex_rd_we        ( id2ex_rd_we        )
  ,.id2ex_rd_addr      ( id2ex_rd_addr      )
  ,.id2ex_rs1_data     ( id2ex_rs1_data     )
  ,.id2ex_rs2_data     ( id2ex_rs2_data     )
  ,.id2ex_imm          ( id2ex_imm          )
  ,.id2ex_pc           ( id2ex_pc           )
  ,.id2ex_fault        ( id2ex_fault        )
  ,.if2bp_query        ( if2bp_query        )
  ,.if2bp_pc           ( if2bp_pc           )
  ,.if2bp_taken        ( if2bp_taken        )
  ,.if2bp_npc          ( if2bp_npc          )
  ,.if2bp_hit          ( if2bp_hit          )
  ,.id2bp_taken        ( id2bp_taken        )
  ,.id2bp_npc          ( id2bp_npc          )
  ,.id2bp_ghist        ( id2bp_ghist        )
  ,.id2bp_hit          ( id2bp_hit          )
  ,.id2csr_re          ( id2csr_re          )
  ,.id2csr_we          ( id2csr_we          )
  ,.id2csr_data        ( id2csr_data        )
  ,.id2lsu_we          ( id2lsu_we          )
  ,.tr2csr_valid       ( tr2csr_valid       )
  ,.tr2csr_ready       ( tr2csr_ready       )
  ,.tr2csr_we          ( tr2csr_we          )
  ,.tr2csr_mepc        ( tr2csr_mepc        )
  ,.tr2csr_mtval       ( tr2csr_mtval       )
  ,.tr2csr_mcause      ( tr2csr_mcause      )
  ,.tr2csr_mstatus     ( tr2csr_mstatus     )
  ,.csr2tr_MIE         ( csr2tr_MIE         )
  ,.csr2tr_mie         ( csr2tr_mie         )
  ,.csr2tr_mip         ( csr2tr_mip         )
  ,.csr2tr_mepc        ( csr2tr_mepc        )
  ,.csr2tr_mtvec       ( csr2tr_mtvec       )
  ,.ex2rf_valid        ( ex2rf_valid        )
  ,.ex2rf_ready        ( ex2rf_ready        )
  ,.ex2rf_rd_we        ( ex2rf_rd_we        )
  ,.ex2rf_rd_addr      ( ex2rf_rd_addr      )
  ,.ex2rf_rd_data      ( ex2rf_rd_data      )
  ,.ex2tr_valid        ( ex2tr_valid        )
  ,.ex2tr_ready        ( ex2tr_ready        )
  ,.ex2tr_pc           ( ex2tr_pc           )
  ,.ex2tr_npc          ( ex2tr_npc          )
  ,.ex2tr_faults       ( ex2tr_faults       )
  ,.ex2if_valid        ( ex2if_valid        )
  ,.ex2if_ready        ( ex2if_ready        )
  ,.ex2if_flush        ( ex2if_flush        )
  ,.ex2if_pc           ( ex2if_pc           )
  ,.ex2if_cause        ( ex2if_cause        )
  ,.ex2id_fwd_valid    ( ex2id_fwd_valid    )
  ,.ex2id_fwd_ready    ( ex2id_fwd_ready    )
  ,.ex2id_fwd_we       ( ex2id_fwd_we       )
  ,.ex2id_fwd_rd       ( ex2id_fwd_rd       )
  ,.ex2id_fwd_data     ( ex2id_fwd_data     )
  ,.m_axi_awready_lsu  ( m_axi_awready_lsu  )
  ,.m_axi_awvalid_lsu  ( m_axi_awvalid_lsu  )
  ,.m_axi_awaddr_lsu   ( m_axi_awaddr_lsu   )
  ,.m_axi_awprot_lsu   ( m_axi_awprot_lsu   )
  ,.m_axi_awid_lsu     ( m_axi_awid_lsu     )
  ,.m_axi_awlen_lsu    ( m_axi_awlen_lsu    )
  ,.m_axi_awsize_lsu   ( m_axi_awsize_lsu   )
  ,.m_axi_awburst_lsu  ( m_axi_awburst_lsu  )
  ,.m_axi_awlock_lsu   ( m_axi_awlock_lsu   )
  ,.m_axi_awcache_lsu  ( m_axi_awcache_lsu  )
  ,.m_axi_awqos_lsu    ( m_axi_awqos_lsu    )
  ,.m_axi_awregion_lsu ( m_axi_awregion_lsu )
  ,.m_axi_awuser_lsu   ( m_axi_awuser_lsu   )
  ,.m_axi_wready_lsu   ( m_axi_wready_lsu   )
  ,.m_axi_wvalid_lsu   ( m_axi_wvalid_lsu   )
  ,.m_axi_wdata_lsu    ( m_axi_wdata_lsu    )
  ,.m_axi_wstrb_lsu    ( m_axi_wstrb_lsu    )
  ,.m_axi_wlast_lsu    ( m_axi_wlast_lsu    )
  ,.m_axi_wuser_lsu    ( m_axi_wuser_lsu    )
  ,.m_axi_bready_lsu   ( m_axi_bready_lsu   )
  ,.m_axi_bvalid_lsu   ( m_axi_bvalid_lsu   )
  ,.m_axi_bresp_lsu    ( m_axi_bresp_lsu    )
  ,.m_axi_bid_lsu      ( m_axi_bid_lsu      )
  ,.m_axi_buser_lsu    ( m_axi_buser_lsu    )
  ,.m_axi_arready_lsu  ( m_axi_arready_lsu  )
  ,.m_axi_arvalid_lsu  ( m_axi_arvalid_lsu  )
  ,.m_axi_araddr_lsu   ( m_axi_araddr_lsu   )
  ,.m_axi_arprot_lsu   ( m_axi_arprot_lsu   )
  ,.m_axi_arid_lsu     ( m_axi_arid_lsu     )
  ,.m_axi_arlen_lsu    ( m_axi_arlen_lsu    )
  ,.m_axi_arsize_lsu   ( m_axi_arsize_lsu   )
  ,.m_axi_arburst_lsu  ( m_axi_arburst_lsu  )
  ,.m_axi_arlock_lsu   ( m_axi_arlock_lsu   )
  ,.m_axi_arcache_lsu  ( m_axi_arcache_lsu  )
  ,.m_axi_arqos_lsu    ( m_axi_arqos_lsu    )
  ,.m_axi_arregion_lsu ( m_axi_arregion_lsu )
  ,.m_axi_aruser_lsu   ( m_axi_aruser_lsu   )
  ,.m_axi_rready_lsu   ( m_axi_rready_lsu   )
  ,.m_axi_rvalid_lsu   ( m_axi_rvalid_lsu   )
  ,.m_axi_rdata_lsu    ( m_axi_rdata_lsu    )
  ,.m_axi_rresp_lsu    ( m_axi_rresp_lsu    )
  ,.m_axi_rid_lsu      ( m_axi_rid_lsu      )
  ,.m_axi_rlast_lsu    ( m_axi_rlast_lsu    )
  ,.m_axi_ruser_lsu    ( m_axi_ruser_lsu    )
  ,.clk_ex             ( clk                )
  ,.aclk_ex            ( aclk               )
  ,.rstn_ex            ( rstn               )
  ,.arstn_ex           ( arstn              )
);

RegisterFile #(
   .DATA_WIDTH    ( DATA_WIDTH    )
  ,.RF_ADDR_WIDTH ( RF_ADDR_WIDTH )
) u_rf (
   .id2rf_rs1_addr ( id2rf_rs1_addr )
  ,.id2rf_rs2_addr ( id2rf_rs2_addr )
  ,.id2rf_rs1_data ( id2rf_rs1_data )
  ,.id2rf_rs2_data ( id2rf_rs2_data )
  ,.ex2rf_valid    ( ex2rf_valid    )
  ,.ex2rf_ready    ( ex2rf_ready    )
  ,.ex2rf_rd_we    ( ex2rf_rd_we    )
  ,.ex2rf_rd_addr  ( ex2rf_rd_addr  )
  ,.ex2rf_rd_data  ( ex2rf_rd_data  )
  ,.clk_rf         ( clk            )
  ,.rstn_rf        ( rstn           )
);

TrapUnit #(
   .ADDR_WIDTH  ( ADDR_WIDTH  )
  ,.DATA_WIDTH  ( DATA_WIDTH  )
  ,.FAULT_WIDTH ( FAULT_WIDTH )
  ,.CAUSE_WIDTH ( CAUSE_WIDTH )
) u_trap (
   .ex2tr_valid    ( ex2tr_valid    )
  ,.ex2tr_ready    ( ex2tr_ready    )
  ,.ex2tr_pc       ( ex2tr_pc       )
  ,.ex2tr_npc      ( ex2tr_npc      )
  ,.ex2tr_faults   ( ex2tr_faults   )
  ,.tr2if_valid    ( tr2if_valid    )
  ,.tr2if_ready    ( tr2if_ready    )
  ,.tr2if_flush    ( tr2if_flush    )
  ,.tr2if_pc       ( tr2if_pc       )
  ,.tr2if_cause    ( tr2if_cause    )
  ,.tr2csr_valid   ( tr2csr_valid   )
  ,.tr2csr_ready   ( tr2csr_ready   )
  ,.tr2csr_we      ( tr2csr_we      )
  ,.tr2csr_mepc    ( tr2csr_mepc    )
  ,.tr2csr_mtval   ( tr2csr_mtval   )
  ,.tr2csr_mcause  ( tr2csr_mcause  )
  ,.tr2csr_mstatus ( tr2csr_mstatus )
  ,.csr2tr_MIE     ( csr2tr_MIE     )
  ,.csr2tr_mie     ( csr2tr_mie     )
  ,.csr2tr_mip     ( csr2tr_mip     )
  ,.csr2tr_mepc    ( csr2tr_mepc    )
  ,.csr2tr_mtvec   ( csr2tr_mtvec   )
  ,.clk_tr         ( clk            )
  ,.rstn_tr        ( rstn           )
);

endmodule
