module CoreBus #(
   parameter INST_BASE_ADDR = 32'hFFFF_0000
  ,parameter INST_ADDR_LEN  = 32'h0000_1000
  ,parameter DATA_BASE_ADDR = 32'hFFFF_1000
  ,parameter DATA_ADDR_LEN  = 32'h0000_1000
  ,parameter BYTE_WIDTH = 8
  ,parameter DATA_WIDTH = 32
  ,parameter ADDR_WIDTH = 32
  ,parameter STRB_WIDTH = DATA_WIDTH / BYTE_WIDTH
)(
  // Instr. Memory
  // From InstFetch
   output reg  [DATA_WIDTH-1:0] inst_mem_rdata          
  ,output reg                   inst_mem_rvld
  , input wire                  inst_mem_en
  , input wire [ADDR_WIDTH-1:0] inst_mem_addr
  , input wire [DATA_WIDTH-1:0] inst_mem_wdata
  , input wire [STRB_WIDTH-1:0] inst_mem_wen
  // To Inst. Memory
  , input wire [DATA_WIDTH-1:0] core_bus_inst_mem_rdata
  , input wire                  core_bus_inst_mem_rvld
  ,output reg                   core_bus_inst_mem_en
  ,output reg  [ADDR_WIDTH-1:0] core_bus_inst_mem_addr
  ,output reg  [DATA_WIDTH-1:0] core_bus_inst_mem_wdata
  ,output reg  [STRB_WIDTH-1:0] core_bus_inst_mem_wen
  // Data Memory
  // From LSU
  ,output reg  [DATA_WIDTH-1:0] lsu_mem_rdata
  ,output reg                   lsu_mem_rvld
  , input wire                  lsu_mem_en
  , input wire [ADDR_WIDTH-1:0] lsu_mem_addr
  , input wire [DATA_WIDTH-1:0] lsu_mem_wdata
  , input wire [STRB_WIDTH-1:0] lsu_mem_wen
  // To Data Memory
  , input wire [DATA_WIDTH-1:0] core_bus_lsu_mem_rdata
  , input wire                  core_bus_lsu_mem_rvld
  ,output reg                   core_bus_lsu_mem_en
  ,output reg  [ADDR_WIDTH-1:0] core_bus_lsu_mem_addr
  ,output reg  [DATA_WIDTH-1:0] core_bus_lsu_mem_wdata
  ,output reg  [STRB_WIDTH-1:0] core_bus_lsu_mem_wen
  //
  , input                       CLK
  , input                       RSTN
);

  parameter INST_END_ADDR = INST_BASE_ADDR + INST_ADDR_LEN - 1;
  parameter DATA_END_ADDR = DATA_BASE_ADDR + DATA_ADDR_LEN - 1;

  // Instruction address decoder
  always @(*)
    begin : CoreBus_INST

      core_bus_inst_mem_en    = 'd0;
      core_bus_inst_mem_addr  = 'd0;
      core_bus_inst_mem_wdata = 'd0;
      core_bus_inst_mem_wen   = 'd0;
      inst_mem_rdata = 'd0;
      inst_mem_rvld  = 'd0;

      if (inst_mem_addr >= INST_BASE_ADDR
            && inst_mem_addr <= INST_END_ADDR)
      begin
        core_bus_inst_mem_en    = inst_mem_en    ;
        core_bus_inst_mem_addr  = inst_mem_addr  ;
        core_bus_inst_mem_wdata = inst_mem_wdata ;
        core_bus_inst_mem_wen   = inst_mem_wen   ;
      end
    
      inst_mem_rdata = core_bus_inst_mem_rdata;
      inst_mem_rvld  = core_bus_inst_mem_rvld;
    end
  
//always @(posedge CLK or negedge RSTN)
//  begin
//    if (~RSTN)
//      inst_mem_rdata <= 'd0;
//    else if (core_bus_inst_mem_rvld)
//      inst_mem_rdata <= core_bus_inst_mem_rdata;
//  end
// 
//always @(posedge CLK or negedge RSTN)
//  begin
//    if (~RSTN)
//      inst_mem_rvld <= 'd0;
//    else
//      inst_mem_rvld <= core_bus_inst_mem_rvld;
//  end 

  // Instruction address decoder
  always @(*)
    begin : CoreBus_LSU

      core_bus_lsu_mem_en    = 'd0;
      core_bus_lsu_mem_addr  = 'd0;
      core_bus_lsu_mem_wdata = 'd0;
      core_bus_lsu_mem_wen   = 'd0;
//    lsu_mem_rdata = 'd0;
//    lsu_mem_rvld  = 'd0;

      if (lsu_mem_addr >= DATA_BASE_ADDR
            && lsu_mem_addr <= DATA_END_ADDR)
      begin
        core_bus_lsu_mem_en    = lsu_mem_en    ;
        core_bus_lsu_mem_addr  = lsu_mem_addr  ;
        core_bus_lsu_mem_wdata = lsu_mem_wdata ;
        core_bus_lsu_mem_wen   = lsu_mem_wen   ;
      end

      else if(lsu_mem_addr == 32'hFFFF2000)
      begin
        $write("%c", lsu_mem_wdata[7:0]);
      end
    
//    lsu_mem_rdata = core_bus_lsu_mem_rdata;
//    lsu_mem_rvld  = core_bus_lsu_mem_rvld;
    end

  always @(posedge CLK or negedge RSTN)
    begin
      if (~RSTN)
        lsu_mem_rdata <= 'd0;
      else if (core_bus_lsu_mem_rvld)
        lsu_mem_rdata <= core_bus_lsu_mem_rdata;
    end
   
  always @(posedge CLK or negedge RSTN)
    begin
      if (~RSTN)
        lsu_mem_rvld <= 'd0;
      else
        lsu_mem_rvld <= core_bus_lsu_mem_rvld;
    end 

endmodule
