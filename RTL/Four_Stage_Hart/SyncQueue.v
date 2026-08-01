module SyncQueue #(
   parameter WIDTH   = 31
  ,parameter DEPTH   = 4
  ,parameter OUT_REG = 0
  //-----------------------
  ,parameter DEPTH_LOG2 = $clog2(DEPTH)
)(
  // output
   output             sync_q_rok
  ,output             sync_q_wok
  ,output [WIDTH-1:0] sync_q_rdata
  // input
  , input             sync_q_ren
  , input             sync_q_wen
  , input [WIDTH-1:0] sync_q_wdata
  , input             sync_q_flush
  //
  , input             CLK
  , input             RSTN
);

// Queue Pointer
wire                  sync_q_inc;
wire                  sync_q_dec;
wire [DEPTH_LOG2  :0] sync_q_cnt_n;
reg  [DEPTH_LOG2  :0] sync_q_cnt;

wire                  sync_q_rmax;
wire                  sync_q_rinc;
wire [DEPTH_LOG2-1:0] sync_q_rptr_n;
reg  [DEPTH_LOG2-1:0] sync_q_rptr; 

wire                  sync_q_wmax;
wire                  sync_q_winc;
wire [DEPTH_LOG2-1:0] sync_q_wptr_n;
reg  [DEPTH_LOG2-1:0] sync_q_wptr;

assign sync_q_inc    = sync_q_winc;
assign sync_q_dec    = sync_q_rinc;
assign sync_q_cnt_n  = sync_q_cnt + sync_q_inc - sync_q_dec;

assign sync_q_rinc   = sync_q_rok & sync_q_ren;
assign sync_q_rmax   = sync_q_rptr == (DEPTH - 1);
assign sync_q_rptr_n = sync_q_rmax ? 'd0 : (sync_q_rptr + 1'd1);

assign sync_q_winc   = sync_q_wok & sync_q_wen;
assign sync_q_wmax   = sync_q_wptr == (DEPTH - 1);
assign sync_q_wptr_n = sync_q_wmax ? 'd0 : (sync_q_wptr + 1'd1);

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      sync_q_cnt <= 'd0;
    else if (sync_q_flush)
      sync_q_cnt <= 'd0;
    else
      sync_q_cnt <= sync_q_cnt_n;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      sync_q_rptr <= 'd0;
    else if (sync_q_flush)
      sync_q_rptr <= 'd0;
    else if (sync_q_rinc)
      sync_q_rptr <= sync_q_rptr_n;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      sync_q_wptr <= 'd0;
    else if (sync_q_flush)
      sync_q_wptr <= 'd0;
    else if (sync_q_winc)
      sync_q_wptr <= sync_q_wptr_n;
  end

// Queue Memory
reg [WIDTH-1:0] sync_q_mem [DEPTH-1:0];

always @(posedge CLK)
  begin
    if (sync_q_winc)
      sync_q_mem[sync_q_wptr] <= sync_q_wdata;
  end

// Queue Output
assign sync_q_rok   = sync_q_cnt > 0;
assign sync_q_wok   = sync_q_cnt < DEPTH;

generate
  begin : GEN_OUT_REG
    if (OUT_REG == 1)
      begin
        reg [WIDTH-1:0] sync_q_rdata_reg;

        assign sync_q_rdata = sync_q_rdata_reg;
        
        always @(posedge CLK or negedge RSTN)
          begin
            if (~RSTN)
              sync_q_rdata_reg <= 'd0;
            else if (sync_q_rinc)
              sync_q_rdata_reg <= sync_q_mem[sync_q_rptr];
          end
      end
    else
      assign sync_q_rdata = sync_q_mem[sync_q_rptr];
  end
endgenerate

endmodule