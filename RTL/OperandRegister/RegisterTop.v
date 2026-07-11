module RegisterTop (
   output reg [31:0] rs1_data 
  ,output reg [31:0] rs2_data
  , input     [31:0] rd_data
  , input     [ 4:0] rd
  , input            rd_wen     
  , input     [ 4:0] rs1
  , input     [ 4:0] rs2
  , input            rs1_ren
  , input            rs2_ren
  , input     [ 0:0] rs1_forward
  , input     [31:0] rs1_forward_data
  , input     [ 0:0] rs2_forward
  , input     [31:0] rs2_forward_data
  , input            CLK
  , input            RSTN
);

wire [31:0] x31;
wire [31:0] x30;
wire [31:0] x29;
wire [31:0] x28;
wire [31:0] x27;
wire [31:0] x26;
wire [31:0] x25;
wire [31:0] x24;
wire [31:0] x23;
wire [31:0] x22;
wire [31:0] x21;
wire [31:0] x20;
wire [31:0] x19;
wire [31:0] x18;
wire [31:0] x17;
wire [31:0] x16;
wire [31:0] x15;
wire [31:0] x14;
wire [31:0] x13;
wire [31:0] x12;
wire [31:0] x11;
wire [31:0] x10;
wire [31:0] x09;
wire [31:0] x08;
wire [31:0] x07;
wire [31:0] x06;
wire [31:0] x05;
wire [31:0] x04;
wire [31:0] x03;
wire [31:0] x02;
wire [31:0] x01;
wire [31:0] x00;

wire        x31_wen = rd_wen & (rd == 'd31);
wire        x30_wen = rd_wen & (rd == 'd30);
wire        x29_wen = rd_wen & (rd == 'd29);
wire        x28_wen = rd_wen & (rd == 'd28);
wire        x27_wen = rd_wen & (rd == 'd27);
wire        x26_wen = rd_wen & (rd == 'd26);
wire        x25_wen = rd_wen & (rd == 'd25);
wire        x24_wen = rd_wen & (rd == 'd24);
wire        x23_wen = rd_wen & (rd == 'd23);
wire        x22_wen = rd_wen & (rd == 'd22);
wire        x21_wen = rd_wen & (rd == 'd21);
wire        x20_wen = rd_wen & (rd == 'd20);
wire        x19_wen = rd_wen & (rd == 'd19);
wire        x18_wen = rd_wen & (rd == 'd18);
wire        x17_wen = rd_wen & (rd == 'd17);
wire        x16_wen = rd_wen & (rd == 'd16);
wire        x15_wen = rd_wen & (rd == 'd15);
wire        x14_wen = rd_wen & (rd == 'd14);
wire        x13_wen = rd_wen & (rd == 'd13);
wire        x12_wen = rd_wen & (rd == 'd12);
wire        x11_wen = rd_wen & (rd == 'd11);
wire        x10_wen = rd_wen & (rd == 'd10);
wire        x09_wen = rd_wen & (rd == 'd09);
wire        x08_wen = rd_wen & (rd == 'd08);
wire        x07_wen = rd_wen & (rd == 'd07);
wire        x06_wen = rd_wen & (rd == 'd06);
wire        x05_wen = rd_wen & (rd == 'd05);
wire        x04_wen = rd_wen & (rd == 'd04);
wire        x03_wen = rd_wen & (rd == 'd03);
wire        x02_wen = rd_wen & (rd == 'd02);
wire        x01_wen = rd_wen & (rd == 'd01);
wire [31:0] x_wdata = rd_data;

wire [31:0] rs1_p = (rs1 == 'd31) ? x31 :
                    (rs1 == 'd30) ? x30 :
                    (rs1 == 'd29) ? x29 :
                    (rs1 == 'd28) ? x28 :
                    (rs1 == 'd27) ? x27 :
                    (rs1 == 'd26) ? x26 :
                    (rs1 == 'd25) ? x25 :
                    (rs1 == 'd24) ? x24 :
                    (rs1 == 'd23) ? x23 :
                    (rs1 == 'd22) ? x22 :
                    (rs1 == 'd21) ? x21 :
                    (rs1 == 'd20) ? x20 :
                    (rs1 == 'd19) ? x19 :
                    (rs1 == 'd18) ? x18 :
                    (rs1 == 'd17) ? x17 :
                    (rs1 == 'd16) ? x16 :
                    (rs1 == 'd15) ? x15 :
                    (rs1 == 'd14) ? x14 :
                    (rs1 == 'd13) ? x13 :
                    (rs1 == 'd12) ? x12 :
                    (rs1 == 'd11) ? x11 :
                    (rs1 == 'd10) ? x10 :
                    (rs1 == 'd09) ? x09 :
                    (rs1 == 'd08) ? x08 :
                    (rs1 == 'd07) ? x07 :
                    (rs1 == 'd06) ? x06 :
                    (rs1 == 'd05) ? x05 :
                    (rs1 == 'd04) ? x04 :
                    (rs1 == 'd03) ? x03 :
                    (rs1 == 'd02) ? x02 :
                    (rs1 == 'd01) ? x01 :
                                    x00 ;

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
        rs1_data <= 'd0;
    else if (rs1_ren)
        rs1_data <= rs1_forward ? rs1_forward_data : rs1_p;
  end

wire [31:0] rs2_p = (rs2 == 'd31) ? x31 :
                    (rs2 == 'd30) ? x30 :
                    (rs2 == 'd29) ? x29 :
                    (rs2 == 'd28) ? x28 :
                    (rs2 == 'd27) ? x27 :
                    (rs2 == 'd26) ? x26 :
                    (rs2 == 'd25) ? x25 :
                    (rs2 == 'd24) ? x24 :
                    (rs2 == 'd23) ? x23 :
                    (rs2 == 'd22) ? x22 :
                    (rs2 == 'd21) ? x21 :
                    (rs2 == 'd20) ? x20 :
                    (rs2 == 'd19) ? x19 :
                    (rs2 == 'd18) ? x18 :
                    (rs2 == 'd17) ? x17 :
                    (rs2 == 'd16) ? x16 :
                    (rs2 == 'd15) ? x15 :
                    (rs2 == 'd14) ? x14 :
                    (rs2 == 'd13) ? x13 :
                    (rs2 == 'd12) ? x12 :
                    (rs2 == 'd11) ? x11 :
                    (rs2 == 'd10) ? x10 :
                    (rs2 == 'd09) ? x09 :
                    (rs2 == 'd08) ? x08 :
                    (rs2 == 'd07) ? x07 :
                    (rs2 == 'd06) ? x06 :
                    (rs2 == 'd05) ? x05 :
                    (rs2 == 'd04) ? x04 :
                    (rs2 == 'd03) ? x03 :
                    (rs2 == 'd02) ? x02 :
                    (rs2 == 'd01) ? x01 :
                                    x00 ;

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
        rs2_data <= 'd0;
    else if (rs2_ren)
        rs2_data <= rs2_forward ? rs2_forward_data : rs2_p;
  end

Register32 i0_Register32(
  .x31     ( x31     ),
  .x30     ( x30     ),
  .x29     ( x29     ),
  .x28     ( x28     ),
  .x27     ( x27     ),
  .x26     ( x26     ),
  .x25     ( x25     ),
  .x24     ( x24     ),
  .x23     ( x23     ),
  .x22     ( x22     ),
  .x21     ( x21     ),
  .x20     ( x20     ),
  .x19     ( x19     ),
  .x18     ( x18     ),
  .x17     ( x17     ),
  .x16     ( x16     ),
  .x15     ( x15     ),
  .x14     ( x14     ),
  .x13     ( x13     ),
  .x12     ( x12     ),
  .x11     ( x11     ),
  .x10     ( x10     ),
  .x09     ( x09     ),
  .x08     ( x08     ),
  .x07     ( x07     ),
  .x06     ( x06     ),
  .x05     ( x05     ),
  .x04     ( x04     ),
  .x03     ( x03     ),
  .x02     ( x02     ),
  .x01     ( x01     ),
  .x00     ( x00     ),
  .x31_wen ( x31_wen ),
  .x30_wen ( x30_wen ),
  .x29_wen ( x29_wen ),
  .x28_wen ( x28_wen ),
  .x27_wen ( x27_wen ),
  .x26_wen ( x26_wen ),
  .x25_wen ( x25_wen ),
  .x24_wen ( x24_wen ),
  .x23_wen ( x23_wen ),
  .x22_wen ( x22_wen ),
  .x21_wen ( x21_wen ),
  .x20_wen ( x20_wen ),
  .x19_wen ( x19_wen ),
  .x18_wen ( x18_wen ),
  .x17_wen ( x17_wen ),
  .x16_wen ( x16_wen ),
  .x15_wen ( x15_wen ),
  .x14_wen ( x14_wen ),
  .x13_wen ( x13_wen ),
  .x12_wen ( x12_wen ),
  .x11_wen ( x11_wen ),
  .x10_wen ( x10_wen ),
  .x09_wen ( x09_wen ),
  .x08_wen ( x08_wen ),
  .x07_wen ( x07_wen ),
  .x06_wen ( x06_wen ),
  .x05_wen ( x05_wen ),
  .x04_wen ( x04_wen ),
  .x03_wen ( x03_wen ),
  .x02_wen ( x02_wen ),
  .x01_wen ( x01_wen ),
  .x_wdata ( x_wdata ),
  .CLK     ( CLK     ),
  .RSTN    ( RSTN    ) 
);

endmodule