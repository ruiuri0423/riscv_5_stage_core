module TypeDecoder (
   output reg         dec_type_vld
  ,output reg  [11:0] dec_csr_addr // CSR
  ,output reg  [31:0] dec_csr_imm  // CSR
  ,output wire        rs1_ren
  ,output wire        rs2_ren
  ,output reg         rd_wen
//,output reg  [ 5:0] inst_type
  ,output reg  [31:0] imm
  ,output reg  [ 6:0] funct7
  ,output reg  [ 6:0] funct7_p
  ,output reg  [ 4:0] rs2   
  ,output reg  [ 4:0] rs1   
  ,output reg  [ 4:0] rs2_p
  ,output reg  [ 4:0] rs1_p
  ,output reg  [ 4:0] rd_p
  ,output reg  [ 2:0] funct3
  ,output reg  [ 2:0] funct3_p
  ,output reg  [ 4:0] rd    
  ,output reg  [ 6:0] opcode
  ,output wire        is_OP    
  ,output wire        is_OP_IMM
  ,output wire        is_LUI
  ,output wire        is_AUIPC
  ,output wire        is_JAL
  ,output wire        is_JALR
  ,output wire        is_BRANCH
  ,output wire        is_LOAD
  ,output wire        is_STORE
  ,output wire        is_MISC_MEM
  ,output wire        is_SYSTEM
  , input             dec_freeze
  , input             alu_flush
  , input             nop_insert
// CSR Hazard (Atomic)
  , input             csr_hazard
  , input      [31:0] inst
  , input             inst_vld
  , input             CLK
  , input             RSTN 
);

assign  is_OP       = inst_vld & (inst[6:0] == `INST_OP      );    
assign  is_OP_IMM   = inst_vld & (inst[6:0] == `INST_OP_IMM  );
assign  is_LUI      = inst_vld & (inst[6:0] == `INST_LUI     );
assign  is_AUIPC    = inst_vld & (inst[6:0] == `INST_AUIPC   );
assign  is_JAL      = inst_vld & (inst[6:0] == `INST_JAL     );
assign  is_JALR     = inst_vld & (inst[6:0] == `INST_JALR    );
assign  is_BRANCH   = inst_vld & (inst[6:0] == `INST_BRANCH  );
assign  is_LOAD     = inst_vld & (inst[6:0] == `INST_LOAD    );
assign  is_STORE    = inst_vld & (inst[6:0] == `INST_STORE   );
assign  is_MISC_MEM = inst_vld & (inst[6:0] == `INST_MISC_MEM);
assign  is_SYSTEM   = inst_vld & (inst[6:0] == `INST_SYSTEM  );

wire r_type_inst = ~nop_insert & ~alu_flush & ~csr_hazard & ~dec_freeze & (is_OP                        );
wire i_type_inst = ~nop_insert & ~alu_flush & ~csr_hazard & ~dec_freeze & (is_OP_IMM | is_JALR | is_LOAD 
                                                                           | is_SYSTEM                  );
wire s_type_inst = ~nop_insert & ~alu_flush & ~csr_hazard & ~dec_freeze & (is_STORE                     );
wire b_type_inst = ~nop_insert & ~alu_flush & ~csr_hazard & ~dec_freeze & (is_BRANCH                    );
wire u_type_inst = ~nop_insert & ~alu_flush & ~csr_hazard & ~dec_freeze & (is_LUI | is_AUIPC            );
wire j_type_inst = ~nop_insert & ~alu_flush & ~csr_hazard & ~dec_freeze & (is_JAL                       );

reg [31:0] imm_p;
reg [ 6:0] opcode_p;

always @(*)
  begin
    if (inst_vld)
      begin
        imm_p    = imm;
        funct7_p = inst[31:25];
        rs2_p    = inst[24:20];
        rs1_p    = inst[19:15];
        funct3_p = inst[14:12];
        rd_p     = inst[11: 7];
        opcode_p = inst[ 6: 0];

        case(1'b1)
          i_type_inst: begin `I_TYPE_IMM end
          s_type_inst: begin `S_TYPE_IMM end
          b_type_inst: begin `B_TYPE_IMM end
          u_type_inst: begin `U_TYPE_IMM end
          j_type_inst: begin `J_TYPE_IMM end
        endcase
      end
    else
      begin
        imm_p    = 'd0;
        funct7_p = 'd0;
        rs2_p    = 'd0;
        rs1_p    = 'd0;
        funct3_p = 'd0;
        rd_p     = 'd0;
        opcode_p = 'd0;
      end
  end

always @(posedge CLK or negedge RSTN) 
  begin
    if (~RSTN)
      begin
        imm    <= 'd0;
        funct7 <= 'd0;
        rs2    <= 'd0;
        rs1    <= 'd0;
        funct3 <= 'd0;
        rd     <= 'd0;
        opcode <= 'd0;
      end  
    else if (alu_flush | csr_hazard | nop_insert)
      begin
        imm    <= 'd0;
        funct7 <= 'd0;
        rs2    <= 'd0;
        rs1    <= 'd0;
        funct3 <= 'd0;
        rd     <= 'd0;
        opcode <= 'd0;
      end  
    else if (~dec_freeze)
      begin
        imm    <= imm_p   ;
        funct7 <= funct7_p;
        rs2    <= rs2_p   ;
        rs1    <= rs1_p   ;
        funct3 <= funct3_p;
        rd     <= rd_p    ;
        opcode <= opcode_p;
      end
  end

//always @(posedge CLK or negedge RSTN) 
//  begin
//    if (~RSTN)
//      inst_type <= 'd0;
//    else if (inst_vld)
//      inst_type <= {
//        r_type_inst,
//        i_type_inst,
//        s_type_inst,
//        b_type_inst,
//        u_type_inst,
//        j_type_inst
//      };
//  end

always @(posedge CLK or negedge RSTN) 
  begin
    if (~RSTN)
      begin
        dec_type_vld <= 'd0;
//      rs1_ren      <= 'd0;
//      rs2_ren      <= 'd0;
        rd_wen       <= 'd0;
        dec_csr_addr <= 'd0;
        dec_csr_imm  <= 'd0;
      end
    else if (alu_flush | csr_hazard | nop_insert)
      begin
        dec_type_vld <= 'd0;
//      rs1_ren      <= 'd0;
//      rs2_ren      <= 'd0;
        rd_wen       <= 'd0;
        dec_csr_addr <= 'd0;
        dec_csr_imm  <= 'd0;
      end
    else if (~dec_freeze)
      begin
        dec_type_vld <= inst_vld;
//      rs1_ren      <=  r_type_inst | i_type_inst | s_type_inst | b_type_inst;
//      rs2_ren      <=  r_type_inst | s_type_inst | b_type_inst;
        rd_wen       <= (rd_p != 4'd0) & 
                        (r_type_inst | i_type_inst | u_type_inst | j_type_inst);
        dec_csr_addr <=  imm_p[11:0];
        dec_csr_imm  <=  rs1_p[ 4:0];
      end
  end

assign rs1_ren      = r_type_inst | i_type_inst | s_type_inst | b_type_inst;
assign rs2_ren      = r_type_inst | s_type_inst | b_type_inst;

endmodule