module Register32(
   output reg [31:0] x31
  ,output reg [31:0] x30
  ,output reg [31:0] x29
  ,output reg [31:0] x28
  ,output reg [31:0] x27
  ,output reg [31:0] x26
  ,output reg [31:0] x25
  ,output reg [31:0] x24
  ,output reg [31:0] x23
  ,output reg [31:0] x22
  ,output reg [31:0] x21
  ,output reg [31:0] x20
  ,output reg [31:0] x19
  ,output reg [31:0] x18
  ,output reg [31:0] x17
  ,output reg [31:0] x16
  ,output reg [31:0] x15
  ,output reg [31:0] x14
  ,output reg [31:0] x13
  ,output reg [31:0] x12
  ,output reg [31:0] x11
  ,output reg [31:0] x10
  ,output reg [31:0] x09
  ,output reg [31:0] x08
  ,output reg [31:0] x07
  ,output reg [31:0] x06
  ,output reg [31:0] x05
  ,output reg [31:0] x04
  ,output reg [31:0] x03
  ,output reg [31:0] x02
  ,output reg [31:0] x01
  ,output reg [31:0] x00
  , input            x31_wen
  , input            x30_wen
  , input            x29_wen
  , input            x28_wen
  , input            x27_wen
  , input            x26_wen
  , input            x25_wen
  , input            x24_wen
  , input            x23_wen
  , input            x22_wen
  , input            x21_wen
  , input            x20_wen
  , input            x19_wen
  , input            x18_wen
  , input            x17_wen
  , input            x16_wen
  , input            x15_wen
  , input            x14_wen
  , input            x13_wen
  , input            x12_wen
  , input            x11_wen
  , input            x10_wen
  , input            x09_wen
  , input            x08_wen
  , input            x07_wen
  , input            x06_wen
  , input            x05_wen
  , input            x04_wen
  , input            x03_wen
  , input            x02_wen
  , input            x01_wen
  , input     [31:0] x_wdata
  , input            CLK
  , input            RSTN
);

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x00 <= 'd0;
    else
      x00 <= 'd0;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x01 <= 'd0;
    else if (x01_wen)
      x01 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x02 <= 'd0;
    else if (x02_wen)
      x02 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x03 <= 'd0;
    else if (x03_wen)
      x03 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x04 <= 'd0;
    else if (x04_wen)
      x04 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x05 <= 'd0;
    else if (x05_wen)
      x05 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x06 <= 'd0;
    else if (x06_wen)
      x06 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x07 <= 'd0;
    else if (x07_wen)
      x07 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x08 <= 'd0;
    else if (x08_wen)
      x08 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x09 <= 'd0;
    else if (x09_wen)
      x09 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x10 <= 'd0;
    else if (x10_wen)
      x10 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x11 <= 'd0;
    else if (x11_wen)
      x11 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x12 <= 'd0;
    else if (x12_wen)
      x12 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x13 <= 'd0;
    else if (x13_wen)
      x13 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x14 <= 'd0;
    else if (x14_wen)
      x14 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x15 <= 'd0;
    else if (x15_wen)
      x15 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x16 <= 'd0;
    else if (x16_wen)
      x16 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x17 <= 'd0;
    else if (x17_wen)
      x17 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x18 <= 'd0;
    else if (x18_wen)
      x18 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x19 <= 'd0;
    else if (x19_wen)
      x19 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x20 <= 'd0;
    else if (x20_wen)
      x20 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x21 <= 'd0;
    else if (x21_wen)
      x21 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x22 <= 'd0;
    else if (x22_wen)
      x22 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x23 <= 'd0;
    else if (x23_wen)
      x23 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x24 <= 'd0;
    else if (x24_wen)
      x24 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x25 <= 'd0;
    else if (x25_wen)
      x25 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x26 <= 'd0;
    else if (x26_wen)
      x26 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x27 <= 'd0;
    else if (x27_wen)
      x27 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x28 <= 'd0;
    else if (x28_wen)
      x28 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x29 <= 'd0;
    else if (x29_wen)
      x29 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x30 <= 'd0;
    else if (x30_wen)
      x30 <= x_wdata;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      x31 <= 'd0;
    else if (x31_wen)
      x31 <= x_wdata;
  end

endmodule