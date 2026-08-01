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
   output reg                    m_axi_arvalid_if
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
  ,output reg  [ INST_WIDTH-1:0] if2id_inst
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

wire                  m_axi_arvalid_cl;
wire                  m_axi_arvalid_we;
wire                  m_axi_rhsk_if;

wire [ADDR_WIDTH-1:0] pc_p;
reg  [ADDR_WIDTH-1:0] pc;

wire                  inst_buf_cl;
wire                  inst_buf_we;
reg                   inst_buf_full;
reg  [INST_WIDTH-1:0] inst_buf;

wire                  if2id_hsk;
wire [INST_WIDTH-1:0] if2id_inst_p;

//-----------------------------------------------------------------------------
// IFU AXI
//-----------------------------------------------------------------------------
//assign m_axi_arvalid_if = ~inst_buf_full | if2id_ready;
assign m_axi_arvalid_cl = m_axi_rhsk_if;
assign m_axi_arvalid_we = m_axi_arvalid_if & m_axi_arready_if;
assign m_axi_araddr_if  = (tr2if_valid & tr2if_ready & tr2if_flush) ? tr2if_pc :
                          (ex2if_valid & ex2if_ready & ex2if_flush) ? ex2if_pc : pc;
assign m_axi_arprot_if  = 3'b101;

assign m_axi_rhsk_if    = m_axi_rvalid_if & m_axi_rready_if;
assign m_axi_rready_if  = ~inst_buf_full | if2id_ready;

always @(posedge clk_if or negedge rstn_if) 
  begin
    if (!rstn_if)
      m_axi_arvalid_if <= 'd1;
    else if (m_axi_arvalid_cl)
      m_axi_arvalid_if <= 'd1;
    else if (m_axi_arvalid_we)
      m_axi_arvalid_if <= 'd0;
  end

//-----------------------------------------------------------------------------
// IFU to IDU
//-----------------------------------------------------------------------------
assign if2id_hsk        = if2id_valid & if2id_ready;
assign if2id_valid      = m_axi_rhsk_if | inst_buf_full; 
assign if2id_inst_p     = inst_buf_full ? inst_buf : m_axi_rdata_if;

always @(posedge clk_if or negedge rstn_if) 
  begin
    if (!rstn_if)
      if2id_inst <= 'd0;
    else if (if2id_hsk)
      if2id_inst <= if2id_inst_p;
  end

//-----------------------------------------------------------------------------
// Instruction buffer.
//-----------------------------------------------------------------------------
assign inst_buf_we      =  m_axi_rhsk_if & (inst_buf_full ? if2id_hsk : ~if2id_hsk);
assign inst_buf_cl      = ~m_axi_rhsk_if &  inst_buf_full & if2id_hsk;

always @(posedge clk_if or negedge rstn_if) 
  begin
    if (!rstn_if)
      inst_buf_full <= 'd0;
    else if (inst_buf_cl)
      inst_buf_full <= 'd0;
    else if (inst_buf_we)
      inst_buf_full <= 'd1;
  end

always @(posedge clk_if or negedge rstn_if) 
  begin
    if (!rstn_if)
      inst_buf <= 'd0;
    else if (inst_buf_we)
      inst_buf <= m_axi_rdata_if;
  end

//-----------------------------------------------------------------------------
// PC generate.
//-----------------------------------------------------------------------------
assign pc_p = pc + 'd4;

always @(posedge clk_if or negedge rstn_if)
  begin
    if (!rstn_if) 
      pc <= 'd0;
    else
      pc <= pc_p;
  end

endmodule
