module WriteBack(
    // From LSU
      input [31:0] lsu_out
    , input        lsu_out_vld
    , input [31:0] lsu_mem_rdata
    , input        lsu_mem_rvld
    , input [ 3:0] lsu_rstrb
    , input [ 4:0] lsu_rd
    , input        lsu_rd_wen
    , input        lsu_lsign
    // 
    ,output [ 4:0] wb_rd
    ,output [31:0] wb_rd_data
    ,output        wb_rd_wen
    //
    , input        CLK
    , input        RSTN
);

// Read from memory with lw/lh/lb align.
wire [31:0] mem_rdata = lsu_rstrb == 4'b0000 ?                                         lsu_mem_rdata         :
                        lsu_rstrb == 4'b0011 ? {{16{(lsu_lsign & lsu_mem_rdata[15])}}, lsu_mem_rdata[15: 0]} :
                        lsu_rstrb == 4'b1100 ? {{16{(lsu_lsign & lsu_mem_rdata[31])}}, lsu_mem_rdata[31:16]} :
                        lsu_rstrb == 4'b0001 ? {{24{(lsu_lsign & lsu_mem_rdata[07])}}, lsu_mem_rdata[ 7: 0]} :
                        lsu_rstrb == 4'b0010 ? {{24{(lsu_lsign & lsu_mem_rdata[15])}}, lsu_mem_rdata[15: 8]} :
                        lsu_rstrb == 4'b0100 ? {{24{(lsu_lsign & lsu_mem_rdata[23])}}, lsu_mem_rdata[23:16]} :
                        lsu_rstrb == 4'b1000 ? {{24{(lsu_lsign & lsu_mem_rdata[31])}}, lsu_mem_rdata[31:24]} : 
                                                                                       lsu_mem_rdata         ;

assign wb_rd      = lsu_rd;
assign wb_rd_wen  = (lsu_out_vld | lsu_mem_rvld) & lsu_rd_wen;
assign wb_rd_data = lsu_out_vld ? lsu_out : lsu_mem_rvld ? mem_rdata : 1'd0;

endmodule