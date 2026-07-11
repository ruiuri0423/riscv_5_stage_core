module LSU(
      input     [31:0] alu_rs2_data
    , input     [31:0] alu_out
    , input            alu_out_vld
    , input     [ 4:0] alu_rd
    , input            alu_rd_wen
    , input     [ 3:0] alu_LS      // bit 3: enable, bit 2: is store, bit 1~0: word/half/byte 
    , input            alu_lsign
    , input            alu_csr_vld // CSR
    , input     [31:0] alu_csr_out // CSR
    ,output reg [31:0] lsu_out
    ,output reg        lsu_out_vld
    ,output reg [ 4:0] lsu_rd
    ,output reg        lsu_rd_wen
    ,output reg [ 3:0] lsu_rstrb
    ,output reg        lsu_lsign
    ,output            lsu_ready
// memory interface
    // response
    , input     [31:0] mem_rdata
    , input            mem_rvld
    // request
    ,output reg        mem_en
    ,output reg [ 3:0] mem_wen
    ,output reg [31:0] mem_addr
    ,output reg [31:0] mem_wdata
//
    , input            CLK
    , input            RSTN
);

localparam WORD_MODE = 2'b11;
localparam HALF_MODE = 2'b10;
localparam BYTE_MODE = 2'b01;

wire load  = lsu_ready & alu_LS[3] & ~alu_LS[2];
wire store = lsu_ready & alu_LS[3] &  alu_LS[2];

reg [3:0] mem_rstrb;
reg       lsu_ready_hold;

assign lsu_ready = mem_rvld | lsu_ready_hold;

always @(posedge CLK or negedge RSTN)
    begin
        if (~RSTN)
            lsu_ready_hold <= 'd1;
        else if (load)
            lsu_ready_hold <= 'd0;
        else if (mem_rvld)
            lsu_ready_hold <= 'd1;
    end

always @(posedge CLK)
    if (lsu_ready)
        begin
            lsu_out     <=  alu_csr_vld ? alu_csr_out : alu_out;
            lsu_out_vld <= (alu_csr_vld | alu_out_vld) & ~load;
            lsu_rd_wen  <= alu_rd_wen;
            lsu_rd      <= alu_rd;
            lsu_rstrb   <= mem_rstrb;
            lsu_lsign   <= alu_lsign;
        end

always @(*)
    begin
        mem_en    = 'd0;
        mem_wen   = 'd0;
        mem_addr  = 'd0;
        mem_wdata = 'd0;
        mem_rstrb = 'd0;
        case (1'b1)
            load : 
                begin
                    mem_en   = 'd1;
                    case (alu_LS[1:0])
                    WORD_MODE : 
                        begin
                            mem_addr = {alu_out[31:2], 2'b00};
                            mem_rstrb = 4'b1111;
                        end
                    HALF_MODE : 
                        begin  
                            mem_addr = {alu_out[31:1], 1'b0};
                            case (alu_out[1])
                                1'b0 : mem_rstrb = 4'b0011;
                                1'b1 : mem_rstrb = 4'b1100;
                            endcase
                        end
                    BYTE_MODE : 
                        begin  
                            mem_addr = alu_out[31:0];
                            case (alu_out[1:0])
                                2'b00 : mem_rstrb = 4'b0001;
                                2'b01 : mem_rstrb = 4'b0010;
                                2'b10 : mem_rstrb = 4'b0100;
                                2'b11 : mem_rstrb = 4'b1000;
                            endcase
                        end
                    endcase
                end
            store : 
                begin
                    mem_en    = 'd1;
                    case (alu_LS[1:0])
                    WORD_MODE : 
                        begin
                            mem_addr  = {alu_out[31:2], 2'b00};
                            mem_wen   = 4'b1111;
                            mem_wdata = alu_rs2_data;
                        end
                    HALF_MODE : 
                        begin  
                            mem_addr = {alu_out[31:1], 1'b0};
                            case (alu_out[1])
                                1'b0 : begin
                                    mem_wen   = 4'b0011;
                                    mem_wdata = {16'b0, alu_rs2_data[15:00]};
                                end
                                1'b1 : begin
                                    mem_wen   = 4'b1100;
                                    mem_wdata = {alu_rs2_data[15:00], 16'b0};
                                end
                            endcase
                        end
                    BYTE_MODE : 
                        begin  
                            mem_addr = alu_out[31:0];
                            case (alu_out[1:0])
                                2'b00 : begin
                                    mem_wen   = 4'b0001;
                                    mem_wdata = {24'b0, alu_rs2_data[07:00]};
                                end
                                2'b01 : begin
                                    mem_wen   = 4'b0010;
                                    mem_wdata = {16'b0, alu_rs2_data[07:00], 8'b0};
                                end
                                2'b10 : begin
                                    mem_wen   = 4'b0100;
                                    mem_wdata = {8'b0, alu_rs2_data[07:00], 16'b0};
                                end
                                2'b11 : begin
                                    mem_wen   = 4'b1000;
                                    mem_wdata = {alu_rs2_data[07:00], 24'b0};
                                end
                            endcase
                        end
                    endcase
                end
        endcase
    end

endmodule