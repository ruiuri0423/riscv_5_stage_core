module FunctionDecoeder (
   output reg        dec_funct_vld
  ,output reg [31:0] dec_pc
  ,output reg        dec_auipc     
  ,output reg        dec_jal       
  ,output reg        dec_jalr      
  ,output reg        dec_branch    
  ,output reg        dec_taken
  ,output reg        dec_lsign
  ,output reg        dec_csr_ren  // CSR
  ,output reg        dec_csr_wen  // CSR
// ALU enable
  ,output reg        is_ADD
  ,output reg        is_SUB
  ,output reg        is_AND
  ,output reg        is_OR 
  ,output reg        is_XOR
  ,output reg        is_SLL
  ,output reg        is_SRL
  ,output reg        is_SRA
  ,output reg        is_ASG
  ,output reg        is_EQ 
  ,output reg        is_NE 
  ,output reg        is_LT 
  ,output reg        is_LTU
  ,output reg        is_GT 
  ,output reg        is_GTU
  ,output reg        is_CSR       // CSR
  ,output reg        is_CSRI      // CSR
  ,output reg        is_CSR_ADD   // CSR
  ,output reg        is_CSR_SET   // CSR
  ,output reg        is_CSR_CLR   // CSR
  ,output reg        rs2_sel
// LSU enable
  ,output reg [ 3:0] is_LS // bit 3: enable, bit 2: is store, bit 1~0: word/half/byte 
// CSR Hazard (Atomic)
  ,output            csr_hazard
// from TYPE_DECODER
  , input     [ 4:0] rd_p
  , input     [ 4:0] rs1_p
  , input     [ 2:0] funct3_p
  , input     [ 6:0] funct7_p
  , input            is_OP    
  , input            is_OP_IMM
  , input            is_LUI
  , input            is_AUIPC
  , input            is_JAL
  , input            is_JALR
  , input            is_BRANCH
  , input            is_LOAD
  , input            is_STORE
  , input            is_MISC_MEM
  , input            is_SYSTEM
  , input            dec_freeze
  , input            alu_flush
  , input            nop_insert
  , input     [31:0] inst_pc
  , input            inst_taken
  , input            inst_vld
  , input            CLK
  , input            RSTN
);

//=============== R_TYPE ===============//
wire add_en;
wire slt_en;
wire sltu_en;
wire and_en;
wire or_en;
wire xor_en;
wire sll_en;
wire srl_en;
wire sub_en;
wire sra_en;

assign add_en  = inst_vld & is_OP & (funct3_p == `FUNCT_ADD ) & ~funct7_p[5];
assign sub_en  = inst_vld & is_OP & (funct3_p == `FUNCT_SUB ) &  funct7_p[5];
assign slt_en  = inst_vld & is_OP & (funct3_p == `FUNCT_SLT );
assign sltu_en = inst_vld & is_OP & (funct3_p == `FUNCT_SLTU);
assign and_en  = inst_vld & is_OP & (funct3_p == `FUNCT_AND );
assign or_en   = inst_vld & is_OP & (funct3_p == `FUNCT_OR  );
assign xor_en  = inst_vld & is_OP & (funct3_p == `FUNCT_XOR );
assign sll_en  = inst_vld & is_OP & (funct3_p == `FUNCT_SLL );
assign srl_en  = inst_vld & is_OP & (funct3_p == `FUNCT_SRL ) & ~funct7_p[5];
assign sra_en  = inst_vld & is_OP & (funct3_p == `FUNCT_SRA ) &  funct7_p[5];

//=============== I_TYPE ===============//
wire addi_en;
wire slti_en;
wire sltiu_en;
wire andi_en;
wire ori_en;
wire xori_en;
wire slli_en;
wire srli_en;
wire srai_en;
wire jalr_en;
wire lb_en;
wire lh_en;
wire lw_en;
wire lbu_en;
wire lhu_en;
wire nop_en;

assign addi_en  = inst_vld & is_OP_IMM & (funct3_p == `FUNCT_ADDI );
assign slti_en  = inst_vld & is_OP_IMM & (funct3_p == `FUNCT_SLTI );
assign sltiu_en = inst_vld & is_OP_IMM & (funct3_p == `FUNCT_SLTIU);
assign andi_en  = inst_vld & is_OP_IMM & (funct3_p == `FUNCT_ANDI );
assign ori_en   = inst_vld & is_OP_IMM & (funct3_p == `FUNCT_ORI  );
assign xori_en  = inst_vld & is_OP_IMM & (funct3_p == `FUNCT_XORI );
assign slli_en  = inst_vld & is_OP_IMM & (funct3_p == `FUNCT_SLLI );
assign srli_en  = inst_vld & is_OP_IMM & (funct3_p == `FUNCT_SRLI ) & ~funct7_p[5];
assign srai_en  = inst_vld & is_OP_IMM & (funct3_p == `FUNCT_SRAI ) &  funct7_p[5];
assign jalr_en  = inst_vld & is_JALR   & (funct3_p == `FUNCT_JALR );
assign lb_en    = inst_vld & is_LOAD   & (funct3_p == `FUNCT_LB   );
assign lh_en    = inst_vld & is_LOAD   & (funct3_p == `FUNCT_LH   );
assign lw_en    = inst_vld & is_LOAD   & (funct3_p == `FUNCT_LW   );
assign lbu_en   = inst_vld & is_LOAD   & (funct3_p == `FUNCT_LBU  );
assign lhu_en   = inst_vld & is_LOAD   & (funct3_p == `FUNCT_LHU  );

//=============== S_TYPE ===============//
wire sb_en;
wire sh_en;
wire sw_en;

assign sb_en = inst_vld & is_STORE & (funct3_p == `FUNCT_SB);
assign sh_en = inst_vld & is_STORE & (funct3_p == `FUNCT_SH);
assign sw_en = inst_vld & is_STORE & (funct3_p == `FUNCT_SW);

//=============== B_TYPE ===============//
wire beq_en;
wire bne_en;
wire blt_en;
wire bltu_en;
wire bge_en;
wire bgeu_en;
//=============== U_TYPE ===============//
wire lui_en;
wire auipc_en;
//=============== J_TYPE ===============//
wire jal_en;

assign beq_en   = inst_vld & is_BRANCH & (funct3_p == `FUNCT_BEQ );
assign bne_en   = inst_vld & is_BRANCH & (funct3_p == `FUNCT_BNE );
assign blt_en   = inst_vld & is_BRANCH & (funct3_p == `FUNCT_BLT );
assign bltu_en  = inst_vld & is_BRANCH & (funct3_p == `FUNCT_BLTU);
assign bge_en   = inst_vld & is_BRANCH & (funct3_p == `FUNCT_BGE );
assign bgeu_en  = inst_vld & is_BRANCH & (funct3_p == `FUNCT_BGEU);
assign lui_en   = inst_vld & is_LUI;
assign auipc_en = inst_vld & is_AUIPC;
assign jal_en   = inst_vld & is_JAL;

//=============== CSR Atomic ===============//
assign csrrw_en  = inst_vld & is_SYSTEM & (funct3_p == `FUNCT_CSRRW );
assign csrrs_en  = inst_vld & is_SYSTEM & (funct3_p == `FUNCT_CSRRS );
assign csrrc_en  = inst_vld & is_SYSTEM & (funct3_p == `FUNCT_CSRRC );
assign csrrwi_en = inst_vld & is_SYSTEM & (funct3_p == `FUNCT_CSRRWI);
assign csrrsi_en = inst_vld & is_SYSTEM & (funct3_p == `FUNCT_CSRRSI);
assign csrrci_en = inst_vld & is_SYSTEM & (funct3_p == `FUNCT_CSRRCI);

assign is_CSR_p     =  csrrw_en |  csrrs_en |  csrrc_en;// CSR
assign is_CSRI_p    = csrrwi_en | csrrsi_en | csrrci_en;// CSR
assign is_CSR_ADD_p =  csrrw_en | csrrwi_en;            // CSR
assign is_CSR_SET_p =  csrrs_en | csrrsi_en;            // CSR
assign is_CSR_CLR_p =  csrrc_en | csrrci_en;            // CSR

assign csr_hazard = (is_CSR   | is_CSRI  ) & 
                    (is_CSR_p | is_CSRI_p);

//=============== ALU Function enable ===============//
always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      begin
        is_ADD     <= 1'b0;
        is_SUB     <= 1'b0;
        is_AND     <= 1'b0;
        is_OR      <= 1'b0;
        is_XOR     <= 1'b0;
        is_SLL     <= 1'b0;
        is_SRL     <= 1'b0;
        is_SRA     <= 1'b0;
        is_ASG     <= 1'b0;
        is_EQ      <= 1'b0;
        is_NE      <= 1'b0;
        is_LT      <= 1'b0;
        is_LTU     <= 1'b0;
        is_GT      <= 1'b0;
        is_GTU     <= 1'b0;
        is_CSR     <= 1'b0;// CSR
        is_CSRI    <= 1'b0;// CSR
        is_CSR_ADD <= 1'b0;// CSR
        is_CSR_SET <= 1'b0;// CSR
        is_CSR_CLR <= 1'b0;// CSR
      end
    else if (alu_flush | csr_hazard | nop_insert)
      begin
        is_ADD     <= 1'b0;
        is_SUB     <= 1'b0;
        is_AND     <= 1'b0;
        is_OR      <= 1'b0;
        is_XOR     <= 1'b0;
        is_SLL     <= 1'b0;
        is_SRL     <= 1'b0;
        is_SRA     <= 1'b0;
        is_ASG     <= 1'b0;
        is_EQ      <= 1'b0;
        is_NE      <= 1'b0;
        is_LT      <= 1'b0;
        is_LTU     <= 1'b0;
        is_GT      <= 1'b0;
        is_GTU     <= 1'b0;
        is_CSR     <= 1'b0;// CSR
        is_CSRI    <= 1'b0;// CSR
        is_CSR_ADD <= 1'b0;// CSR
        is_CSR_SET <= 1'b0;// CSR
        is_CSR_CLR <= 1'b0;// CSR
      end
    else if (~dec_freeze)
      begin
        is_ADD     <= addi_en |  add_en |
                      jalr_en |  jal_en |
                        sb_en |   sh_en |    sw_en |
                        lb_en |   lh_en |    lw_en | 
                       lbu_en |  lhu_en | auipc_en ;
        is_SUB     <=   sub_en;    
        is_AND     <=  andi_en |  and_en;
        is_OR      <=   ori_en |   or_en;
        is_XOR     <=  xori_en |  xor_en;
        is_SLL     <=  slli_en |  sll_en;
        is_SRL     <=  srli_en |  srl_en;
        is_SRA     <=  srai_en |  sra_en;
        is_ASG     <=   lui_en;     
        is_EQ      <=   beq_en;
        is_NE      <=   bne_en;
        is_LT      <=  slti_en |  slt_en |  blt_en;
        is_LTU     <= sltiu_en | sltu_en | bltu_en;
        is_GT      <=   bge_en;
        is_GTU     <=  bgeu_en;
        // CSR (begin)
        is_CSR     <= is_CSR_p;    
        is_CSRI    <= is_CSRI_p;   
        is_CSR_ADD <= is_CSR_ADD_p;
        is_CSR_SET <= is_CSR_SET_p;
        is_CSR_CLR <= is_CSR_CLR_p;
        // CSR (end)
      end
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      rs2_sel <= 1'b0;
    else if (alu_flush | csr_hazard | nop_insert)
      rs2_sel <= 1'b0;
    else if (~dec_freeze)
      begin
        if (is_OP | is_BRANCH)
          rs2_sel <= 1'b0;
        else
          rs2_sel <= 1'b1; // select imm.
      end
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      begin
        dec_auipc  <= 'd0;
        dec_jal    <= 'd0;
        dec_jalr   <= 'd0;
        dec_branch <= 'd0;
        dec_lsign  <= 'd0;
      end
    else if (alu_flush | csr_hazard | nop_insert)
      begin
        dec_auipc  <= 'd0;
        dec_jal    <= 'd0;
        dec_jalr   <= 'd0;
        dec_branch <= 'd0;
        dec_lsign  <= 'd0;
      end
    else if (~dec_freeze)
      begin
        dec_auipc  <= auipc_en;
        dec_jal    <= jal_en;
        dec_jalr   <= jalr_en;

        dec_branch <= beq_en  | bne_en | blt_en  |
                      bltu_en | bge_en | bgeu_en ;

        dec_lsign  <= lb_en | lh_en;
      end
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      begin
        dec_csr_ren  <= 'd0;// CSR
        dec_csr_wen  <= 'd0;// CSR
      end
    else if (alu_flush | csr_hazard | nop_insert)
      begin
        dec_csr_ren  <= 'd0;// CSR
        dec_csr_wen  <= 'd0;// CSR
      end
    else if (~dec_freeze)
      begin
        dec_csr_ren  <= (is_CSR_p | is_CSRI_p) & ~( is_CSR_ADD_p                 & ( rd_p == 4'd0));
        dec_csr_wen  <= (is_CSR_p | is_CSRI_p) & ~((is_CSR_SET_p | is_CSR_CLR_p) & (rs1_p == 4'd0));
      end
  end

always @(posedge CLK or negedge RSTN) 
  begin
    if (~RSTN)
      dec_funct_vld <= 'd0;
    else if (alu_flush | csr_hazard | nop_insert)
      dec_funct_vld <= 'd0;
    else if (~dec_freeze)
      dec_funct_vld <= inst_vld;
  end

always @(posedge CLK or negedge RSTN) 
  begin
    if (~RSTN)
      dec_pc <= 'd0;
    else if (alu_flush | csr_hazard | nop_insert)
      dec_pc <= 'd0;
    else if (~dec_freeze)
      dec_pc <= inst_pc;
  end

always @(posedge CLK or negedge RSTN) 
  begin
    if (~RSTN)
      dec_taken <= 'd0;
    else if (alu_flush | csr_hazard | nop_insert)
      dec_taken <= 'd0;
    else if (~dec_freeze)
      dec_taken <= inst_taken;
  end

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      is_LS <= 4'b0;
    else if (alu_flush | csr_hazard | nop_insert)
      is_LS <= 4'b0;
    else if (~dec_freeze)
      begin
        case(1'b1)
          is_LOAD  : 
            begin
              case(1'b1)
                (lw_en          ) : is_LS <= 4'b1011;
                (lh_en | lhu_en ) : is_LS <= 4'b1010;
                (lb_en | lbu_en ) : is_LS <= 4'b1001;
              endcase
            end
          is_STORE : 
            begin
              case(1'b1)
                sw_en : is_LS <= 4'b1111;
                sh_en : is_LS <= 4'b1110;
                sb_en : is_LS <= 4'b1101;
              endcase
            end
          default  : is_LS <= 4'b0;
        endcase
      end
  end

endmodule