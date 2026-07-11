module CSRTop (
   output reg         alu_csr_vld
  ,output reg  [31:0] alu_csr_out
  , input      [31:0] dec_rs1_data
  , input      [31:0] dec_csr_imm
  , input      [11:0] dec_csr_addr
  , input             dec_csr_ren
  , input             dec_csr_wen
  , input             lsu_ready // Exception
  , input             alu_flush // Exception
  , input             is_CSR
  , input             is_CSRI
  , input             is_CSR_ADD
  , input             is_CSR_SET
  , input             is_CSR_CLR
  , input             CLK
  , input             RSTN
);

reg  [11:0] alu_csr_addr;
reg         alu_csr_wen;
reg  [31:0] alu_csr_wb;
wire [31:0] dec_csr_out;

wire [31:0] rs1_data;
wire [31:0] imm_data;

wire        csr_freeze;

assign rs1_data   = dec_rs1_data;
assign imm_data   = dec_csr_imm;
assign csr_freeze = ~lsu_ready;

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      begin
        alu_csr_vld  <= 'd0;
        alu_csr_out  <= 'd0;
      end
    else if (alu_flush)
      begin
        alu_csr_vld  <= 'd0;
        alu_csr_out  <= 'd0;
      end
    else if (~csr_freeze)
      begin
        alu_csr_vld  <=  is_CSR | is_CSRI;
        alu_csr_out  <= (is_CSR & is_CSRI) ? dec_csr_out : alu_csr_out;
      end
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      begin
        alu_csr_wen  <= 'd0;
        alu_csr_addr <= 'd0;
        alu_csr_wb   <= 'd0;
      end
    else if (alu_flush)
      begin
        alu_csr_wen  <= 'd0;
        alu_csr_addr <= 'd0;
        alu_csr_wb   <= 'd0;
      end
    else
      begin
        alu_csr_wen  <= alu_csr_wen ? 1'b0 : (~csr_freeze & dec_csr_wen) ? 1'b1 : 1'b0;
        alu_csr_addr <= dec_csr_addr;
        alu_csr_wb   <= (is_CSR  & is_CSR_ADD) ? dec_csr_out + rs1_data :
                        (is_CSR  & is_CSR_SET) ? dec_csr_out | rs1_data :
                        (is_CSR  & is_CSR_CLR) ? dec_csr_out & rs1_data :
                        (is_CSRI & is_CSR_ADD) ? dec_csr_out + imm_data :
                        (is_CSRI & is_CSR_SET) ? dec_csr_out | imm_data :
                        (is_CSRI & is_CSR_CLR) ? dec_csr_out & imm_data : 'd0;
      end
  end

wire [11:0] csr_addr = dec_csr_ren ? dec_csr_addr :
                       alu_csr_wen ? alu_csr_addr : 'd0;

CSR i0_CSR (
  .csr_rdata ( dec_csr_out ),
  .csr_wdata ( alu_csr_wb  ),
  .csr_ren   ( dec_csr_ren ), // read
  .csr_wen   ( alu_csr_wen ), // write
  .csr_addr  ( csr_addr    ), // address
  .CLK       ( CLK         ),
  .RSTN      ( RSTN        )
);

endmodule