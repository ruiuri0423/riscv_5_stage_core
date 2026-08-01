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

// Bootstrap FSM encoding
localparam SLEEP      = 1'b0;
localparam POWER_ON   = 1'b1;

// Queue payload geometry
localparam  CMD_Q_WIDTH = ADDR_WIDTH   // PC
                        + ADDR_WIDTH   // NPC
                        + 1            // Taken
                        + 1;           // Hit
localparam DATA_Q_WIDTH = DATA_WIDTH   // Instruction
                        + 1;           // Fault

reg                     state;

// AXI handshakes
wire                    m_axi_arhsk_if;
wire                    m_axi_rhsk_if;

// Command queue (AR-time payload: PC / NPC / Taken / Hit)
wire                    cmd_q_rok;
wire                    cmd_q_wok;
wire [             1:0] cmd_q_cnt;
wire [ CMD_Q_WIDTH-1:0] cmd_q_rdata;
wire                    cmd_q_ren;
wire                    cmd_q_wen;
wire [ CMD_Q_WIDTH-1:0] cmd_q_wdata;
wire                    cmd_q_flush;

// Data queue (R-time payload: Instruction / Fault)
wire                    data_q_rok;
wire                    data_q_wok;
wire [             1:0] data_q_cnt;
wire [DATA_Q_WIDTH-1:0] data_q_rdata;
wire                    data_q_ren;
wire                    data_q_wen;
wire [DATA_Q_WIDTH-1:0] data_q_wdata;
wire                    data_q_flush;

wire                    ongoing_cmd;

wire                    ex2if_flush_valid;
wire                    tr2if_flush_valid;
wire                    if2bp_taken_valid;
wire [  ADDR_WIDTH-1:0] pc_p;
reg  [  ADDR_WIDTH-1:0] pc;

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
assign m_axi_arvalid_if = (state == POWER_ON) & cmd_q_wok & ~tr2if_flush_valid & ~ex2if_flush_valid;
assign m_axi_araddr_if  = pc;
assign m_axi_arprot_if  = 3'b101;
assign m_axi_rready_if  = data_q_wok;

assign m_axi_arhsk_if = m_axi_arvalid_if & m_axi_arready_if;
assign m_axi_rhsk_if  = m_axi_rvalid_if & m_axi_rready_if;

//-----------------------------------------------------------------------------
// IFU to IDU
//-----------------------------------------------------------------------------
assign if2id_valid = cmd_q_rok & data_q_rok;
assign if2id_pc    =  cmd_q_rdata[(2+ADDR_WIDTH)+:ADDR_WIDTH];
assign if2id_inst  = data_q_rdata[(1           )+:DATA_WIDTH];
assign if2id_taken =  cmd_q_rdata[ 1                        ];
assign if2id_npc   =  cmd_q_rdata[(2           )+:ADDR_WIDTH];
assign if2id_hit   =  cmd_q_rdata[ 0                        ];
assign if2id_fault = data_q_rdata[ 0                        ];

assign if2id_hsk   = if2id_valid & if2id_ready;

//-----------------------------------------------------------------------------
// 1. Command Queue
// 2.    Data Queue
//-----------------------------------------------------------------------------
assign ongoing_cmd = cmd_q_cnt > data_q_cnt;

assign cmd_q_ren   = if2id_hsk;
assign cmd_q_wen   = m_axi_arhsk_if;
assign cmd_q_wdata = {m_axi_araddr_if, if2bp_npc, if2bp_taken, if2bp_hit};
assign cmd_q_flush = tr2if_flush_valid | ex2if_flush_valid;

SyncQueue #(
  .WIDTH        ( CMD_Q_WIDTH  ),
  .DEPTH        ( 2            )
) u_cmd_q (
  // output
  .sync_q_rok   ( cmd_q_rok    ),
  .sync_q_wok   ( cmd_q_wok    ),
  .sync_q_cnt   ( cmd_q_cnt    ),
  .sync_q_rdata ( cmd_q_rdata  ),
  // input       
  .sync_q_ren   ( cmd_q_ren    ),
  .sync_q_wen   ( cmd_q_wen    ),
  .sync_q_wdata ( cmd_q_wdata  ),
  .sync_q_flush ( cmd_q_flush  ),
  //             
  .CLK          ( clk_if       ),
  .RSTN         ( rstn_if      )
);

assign data_q_ren   = if2id_hsk;
assign data_q_wen   = m_axi_rhsk_if;
assign data_q_wdata = {m_axi_rdata_if, (m_axi_rresp_if != 2'b00)};
assign data_q_flush = tr2if_flush_valid | ex2if_flush_valid;

SyncQueue #(
  .WIDTH        ( DATA_Q_WIDTH ),
  .DEPTH        ( 2            )
) u_data_q (
  // output
  .sync_q_rok   ( data_q_rok   ),
  .sync_q_wok   ( data_q_wok   ),
  .sync_q_cnt   ( data_q_cnt   ),
  .sync_q_rdata ( data_q_rdata ),
  // input
  .sync_q_ren   ( data_q_ren   ),
  .sync_q_wen   ( data_q_wen   ),
  .sync_q_wdata ( data_q_wdata ),
  .sync_q_flush ( data_q_flush ),
  //
  .CLK          ( clk_if       ),
  .RSTN         ( rstn_if      ) 
);

//-----------------------------------------------------------------------------
// PC generate.
//-----------------------------------------------------------------------------
assign ex2if_ready       = !ongoing_cmd;
assign ex2if_flush_valid = ex2if_valid & ex2if_ready & ex2if_flush;
assign tr2if_ready       = !ongoing_cmd;
assign tr2if_flush_valid = tr2if_valid & tr2if_ready & tr2if_flush;
assign if2bp_query       = m_axi_arhsk_if;
assign if2bp_pc          = m_axi_araddr_if;
assign if2bp_taken_valid = if2bp_hit & if2bp_taken;

assign pc_p = tr2if_flush_valid ? tr2if_pc  :
              ex2if_flush_valid ? ex2if_pc  : 
              if2bp_taken_valid ? if2bp_npc : m_axi_araddr_if + 'd4;

always @(posedge clk_if)
  begin
    if (state == SLEEP)
      pc <= r_BOOT_ADDR;
    else if (m_axi_arhsk_if | tr2if_flush_valid | ex2if_flush_valid)
      pc <= pc_p;
  end

endmodule
