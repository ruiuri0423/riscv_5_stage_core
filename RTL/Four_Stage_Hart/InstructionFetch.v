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
  ,output reg  [ ADDR_WIDTH-1:0] if2id_pc
  ,output wire [ INST_WIDTH-1:0] if2id_inst
  ,output reg                    if2id_taken
  ,output reg  [ ADDR_WIDTH-1:0] if2id_npc
  ,output reg                    if2id_hit
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

// Bootstrap FSM encoding
localparam SLEEP      = 1'b0;
localparam POWER_ON   = 1'b1;

reg                   state;

wire                  m_axi_arhsk_if;
wire                  m_axi_rhsk_if;
reg                   m_axi_arvalid_ostd;  // AR outstanding credit (outstanding = 1)

wire                  if2id_hsk;
reg                   if2id_stall;         // IF2ID payload held, RDATA back-pressured

wire                  ex2if_flush_valid;
wire                  tr2if_flush_valid;
wire [ADDR_WIDTH-1:0] pc_p;
reg  [ADDR_WIDTH-1:0] pc;

//-----------------------------------------------------------------------------
// Boostrap
//-----------------------------------------------------------------------------
always @(posedge clk_if or negedge rstn_if)
  begin
    if (!rstn_if) 
      state <= SLEEP;
    else
      state <= POWER_ON;
  end

//-----------------------------------------------------------------------------
// IFU AXI
//-----------------------------------------------------------------------------
assign m_axi_arvalid_if = ( m_axi_arvalid_ostd && state == POWER_ON) | 
                          (~m_axi_arvalid_ostd && m_axi_rhsk_if    );
assign m_axi_araddr_if  = tr2if_flush_valid ? tr2if_pc : 
                          ex2if_flush_valid ? ex2if_pc : pc;
assign m_axi_arprot_if  = 3'b101;
assign m_axi_rready_if  = ~if2id_stall | if2id_hsk;

assign m_axi_arhsk_if   = m_axi_arvalid_if & m_axi_arready_if;
assign m_axi_rhsk_if    = m_axi_rvalid_if & m_axi_rready_if;

always @(posedge clk_if or negedge rstn_if)
  begin
    if (!rstn_if) 
      m_axi_arvalid_ostd <= 'd1;
    else if (~m_axi_arhsk_if &  m_axi_rhsk_if)
      m_axi_arvalid_ostd <= 'd1;
    else if ( m_axi_arhsk_if & ~m_axi_rhsk_if)
      m_axi_arvalid_ostd <= 'd0;
  end

//-----------------------------------------------------------------------------
// IFU to IDU
//-----------------------------------------------------------------------------
assign if2id_valid = if2id_stall | m_axi_rhsk_if;
assign if2id_inst  <= m_axi_rdata_if;
assign if2id_fault <= m_axi_rresp_if != 2'b00;
assign if2id_hsk   = if2id_valid & if2id_ready;

always @(posedge clk_if or negedge rstn_if)
  begin
    if (!rstn_if) 
      if2id_stall <= 'd0;
    else if (~m_axi_rhsk_if &  if2id_hsk)
      if2id_stall <= 'd0;
    else if ( m_axi_rhsk_if & ~if2id_hsk)
      if2id_stall <= 'd1;
  end

always @(posedge clk_if or negedge rstn_if)
  begin
    if (!rstn_if) 
      begin
        if2id_pc    <= 'd0;
        if2id_taken <= 'd0;
        if2id_npc   <= 'd0;
        if2id_hit   <= 'd0;
      end
    else if (m_axi_arhsk_if)
      begin
        if2id_pc    <= m_axi_araddr_if;
        if2id_taken <= if2bp_taken;
        if2id_npc   <= if2bp_npc;
        if2id_hit   <= if2bp_hit;
      end
  end

//-----------------------------------------------------------------------------
// PC generate.
//-----------------------------------------------------------------------------
assign ex2if_flush_valid = ex2if_valid & ex2if_ready & ex2if_flush;
assign tr2if_flush_valid = tr2if_valid & tr2if_ready & tr2if_flush;

assign pc_p = (if2bp_hit & if2bp_taken) ? if2bp_npc : m_axi_araddr_if + 'd4;

always @(posedge clk_if or negedge rstn_if)
  begin
    if (!rstn_if) 
      pc <= 'd0;
    else if (m_axi_arhsk_if)
      pc <= pc_p;
  end

endmodule
