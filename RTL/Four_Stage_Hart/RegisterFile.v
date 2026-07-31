/* Register File (RF) - port shell only.
   Generated from RISCV_design.xlsx, sheet "Register File".
   Read ports are combinational mux outputs; latch point is inside IDU. */

module RegisterFile #(
   parameter    DATA_WIDTH = 32
  ,parameter RF_ADDR_WIDTH = 5
)(
  // IDU to RF (combinational read)
    input wire [RF_ADDR_WIDTH-1:0] id2rf_rs1_addr
  , input wire [RF_ADDR_WIDTH-1:0] id2rf_rs2_addr
  ,output wire [   DATA_WIDTH-1:0] id2rf_rs1_data  // mux out
  ,output wire [   DATA_WIDTH-1:0] id2rf_rs2_data  // mux out
  // EXUs to RF (writeback)
  , input wire                     ex2rf_valid
  ,output wire                     ex2rf_ready
  , input wire                     ex2rf_rd_we
  , input wire [RF_ADDR_WIDTH-1:0] ex2rf_rd_addr
  , input wire [   DATA_WIDTH-1:0] ex2rf_rd_data
  // clock & reset
  , input wire                     clk_rf
  , input wire                     rstn_rf
);

endmodule
