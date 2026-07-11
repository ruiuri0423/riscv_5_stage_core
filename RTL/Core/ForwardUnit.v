module ForwardUnit (
      input [ 4:0] dec_rs1_p
    , input [ 4:0] dec_rs2_p
    , input        dec_rd_wen
    , input [ 4:0] dec_rd
    , input [ 4:0] dec_rs2
    , input [ 4:0] dec_rs1
    , input [ 3:0] dec_LS

    , input        lsu_mem_rvld
    , input        alu_flush
    , input [ 3:0] alu_LS
    , input [ 4:0] alu_rd
    , input        alu_rd_wen
    , input [31:0] alu_out
    , input        alu_csr_vld // CSR
    , input [31:0] alu_csr_out // CSR
    , input [ 4:0] wb_rd       // lsu -> wb is combo.
    , input        wb_rd_wen   // lsu -> wb is combo.
    , input [31:0] wb_rd_data  // lsu -> wb is combo.
    
    ,output        nop_insert
    ,output [ 0:0] rs1_forward
    ,output [31:0] rs1_forward_data
    ,output [ 0:0] rs2_forward
    ,output [31:0] rs2_forward_data

    , input        CLK
    , input        RSTN
);

reg nop_insert_hold;

assign rs1_alu_forward_valid   = (alu_rd == dec_rs1_p && alu_rd_wen) & (~alu_LS[3] |  alu_LS[2]); // The data need to be wait from LSU.
assign rs2_alu_forward_valid   = (alu_rd == dec_rs2_p && alu_rd_wen) & (~alu_LS[3] |  alu_LS[2]); // The data need to be wait from LSU.
assign rs1_alu_forward_invalid = (alu_rd == dec_rs1_p && alu_rd_wen) & ( alu_LS[3] & ~alu_LS[2]); // The data need to be wait from LSU.
assign rs2_alu_forward_invalid = (alu_rd == dec_rs2_p && alu_rd_wen) & ( alu_LS[3] & ~alu_LS[2]); // The data need to be wait from LSU.

assign rs1_forward = (alu_rd == dec_rs1_p && alu_rd_wen) | ( wb_rd == dec_rs1_p &&  wb_rd_wen);
assign rs2_forward = (alu_rd == dec_rs2_p && alu_rd_wen) | ( wb_rd == dec_rs2_p &&  wb_rd_wen);

assign rs1_forward_data = rs1_alu_forward_valid ? alu_csr_vld ? alu_csr_out : alu_out :
                          ( wb_rd == dec_rs1_p &&  wb_rd_wen) ?  wb_rd_data : 'd0;

assign rs2_forward_data = rs2_alu_forward_valid ? alu_csr_vld ? alu_csr_out : alu_out :
                          ( wb_rd == dec_rs2_p &&  wb_rd_wen) ?  wb_rd_data : 'd0; 

// Hazard if rd is read from memory
assign dec_rs_collide = (dec_rs1_p == dec_rd && dec_rd_wen) | 
                        (dec_rs2_p == dec_rd && dec_rd_wen);

assign dec_mem_read   = dec_rs_collide & (dec_LS[3] & (~dec_LS[2]));

assign alu_mem_read   =  rs1_alu_forward_invalid | 
                         rs2_alu_forward_invalid;

assign nop_insert = ~alu_flush & ((nop_insert_hold & ~lsu_mem_rvld) | dec_rs_collide | dec_mem_read | alu_mem_read);

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      nop_insert_hold <= 'd0;
    else if (lsu_mem_rvld | alu_flush)
      nop_insert_hold <= 'd0;
    else if (nop_insert & (dec_mem_read | alu_mem_read))
      nop_insert_hold <= 'd1;
  end

endmodule