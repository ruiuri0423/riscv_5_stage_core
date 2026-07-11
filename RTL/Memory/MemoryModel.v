module MemoryModel #(
     parameter BYTE_WIDTH = 8
    ,parameter DATA_WIDTH = 32
    ,parameter DATA_DEPTH = 1024
    ,parameter ADDR_WIDTH = 10
    ,parameter STRB_WIDTH = DATA_WIDTH / BYTE_WIDTH
)(
     output reg  [DATA_WIDTH-1:0] mem_rdata
    ,output reg                   mem_rvld
    , input wire                  mem_en
    , input wire [ADDR_WIDTH-1:0] mem_addr
    , input wire [DATA_WIDTH-1:0] mem_wdata
    , input wire [STRB_WIDTH-1:0] mem_wen
    , input wire                  CLK
    , input wire                  RSTN
);

reg [31:0] mem [0:1023]; // 4KB memory

always @(posedge CLK)
    begin
        if (mem_en)
            begin
                mem[mem_addr[9:0]][ 7: 0] <= mem_wen[0] ? mem_wdata[ 7: 0] : mem[mem_addr[9:0]][ 7: 0];
                mem[mem_addr[9:0]][15: 8] <= mem_wen[1] ? mem_wdata[15: 8] : mem[mem_addr[9:0]][15: 8];
                mem[mem_addr[9:0]][23:16] <= mem_wen[2] ? mem_wdata[23:16] : mem[mem_addr[9:0]][23:16];
                mem[mem_addr[9:0]][31:24] <= mem_wen[3] ? mem_wdata[31:24] : mem[mem_addr[9:0]][31:24];
            end
    end

always @(posedge CLK or negedge RSTN)
    begin
        if (~RSTN)
            mem_rdata <= 'd0;
        else if (mem_en & (~|mem_wen))
            mem_rdata <= mem[mem_addr[9:0]];
    end

always @(posedge CLK or negedge RSTN)
    begin
        if (~RSTN)
            mem_rvld <= 'd0;
        else
            mem_rvld <= mem_en & (~|mem_wen);
    end


endmodule
