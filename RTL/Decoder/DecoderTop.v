`include "DefineType.v"

module DecoderTop(
   output wire        dec_funct_vld
  ,output wire        dec_type_vld
  ,output wire        dec_auipc
  ,output wire        dec_jal
  ,output wire        dec_jalr
  ,output wire        dec_branch
  ,output wire        dec_taken
  ,output wire        dec_lsign
  ,output wire [31:0] dec_pc
  ,output wire [11:0] dec_csr_addr // CSR
  ,output wire [31:0] dec_csr_imm  // CSR
  ,output wire        dec_csr_ren  // CSR
  ,output wire        dec_csr_wen  // CSR
  ,output wire        rs1_ren
  ,output wire        rs2_ren
  ,output wire        rd_wen
//,output wire [ 5:0] inst_type
  ,output wire [31:0] imm
  ,output wire [ 6:0] funct7
  ,output wire [ 4:0] rs2
  ,output wire [ 4:0] rs1   
  ,output wire [ 4:0] rs2_p
  ,output wire [ 4:0] rs1_p 
  ,output wire [ 2:0] funct3
  ,output wire [ 4:0] rd    
  ,output wire [ 6:0] opcode
// ALU enable
  ,output wire        is_ADD
  ,output wire        is_SUB
  ,output wire        is_AND
  ,output wire        is_OR 
  ,output wire        is_XOR
  ,output wire        is_SLL
  ,output wire        is_SRL
  ,output wire        is_SRA
  ,output wire        is_ASG
  ,output wire        is_EQ 
  ,output wire        is_NE 
  ,output wire        is_LT 
  ,output wire        is_LTU
  ,output wire        is_GT 
  ,output wire        is_GTU
  ,output wire        is_CSR       // CSR
  ,output wire        is_CSRI      // CSR
  ,output wire        is_CSR_ADD   // CSR
  ,output wire        is_CSR_SET   // CSR
  ,output wire        is_CSR_CLR   // CSR
  ,output wire        rs2_sel
// LSU enable
  ,output wire [ 3:0] is_LS
  , input wire        lsu_ready
// CSR Hazard (Atomic)
  ,output wire        csr_hazard
// from alu
  , input             alu_flush // branch miss predict
// from forward unit
  , input             nop_insert
// from Instruction Fetch
  , input      [31:0] inst
  , input      [31:0] inst_pc
  , input             inst_taken
  , input             inst_vld
  , input             CLK
  , input             RSTN
);

wire        is_OP;
wire        is_OP_IMM;
wire        is_LUI;
wire        is_AUIPC;
wire        is_JAL;
wire        is_JALR;
wire        is_BRANCH;
wire        is_LOAD;
wire        is_STORE;
wire        is_MISC_MEM;
wire        is_SYSTEM;
wire [ 2:0] funct3_p;
wire [ 6:0] funct7_p;
wire [ 4:0] rd_p;
wire        dec_freeze = ~lsu_ready;

TypeDecoder i0_TypeDecoder(
  .dec_type_vld ( dec_type_vld ),
  .dec_csr_addr ( dec_csr_addr ),// CSR
  .dec_csr_imm  ( dec_csr_imm  ),// CSR
  .rs1_ren      ( rs1_ren      ),
  .rs2_ren      ( rs2_ren      ),
  .rd_wen       ( rd_wen       ),
//.inst_type    ( inst_type    ),
  .imm          ( imm          ),
  .funct7       ( funct7       ),
  .funct7_p     ( funct7_p     ),
  .rs2          ( rs2          ),
  .rs1          ( rs1          ),
  .rs2_p        ( rs2_p        ),
  .rs1_p        ( rs1_p        ),
  .rd_p         ( rd_p         ),
  .funct3       ( funct3       ),
  .funct3_p     ( funct3_p     ),
  .rd           ( rd           ),
  .opcode       ( opcode       ),
  .is_OP        ( is_OP        ),
  .is_OP_IMM    ( is_OP_IMM    ),
  .is_LUI       ( is_LUI       ),
  .is_AUIPC     ( is_AUIPC     ),
  .is_JAL       ( is_JAL       ),
  .is_JALR      ( is_JALR      ),
  .is_BRANCH    ( is_BRANCH    ),
  .is_LOAD      ( is_LOAD      ),
  .is_STORE     ( is_STORE     ),
  .is_MISC_MEM  ( is_MISC_MEM  ),
  .is_SYSTEM    ( is_SYSTEM    ),
  .dec_freeze   ( dec_freeze   ),
  .alu_flush    ( alu_flush    ),
  .nop_insert   ( nop_insert   ),
  .csr_hazard   ( csr_hazard   ),
  .inst         ( inst         ),
  .inst_vld     ( inst_vld     ),
  .CLK          ( CLK          ),
  .RSTN         ( RSTN         )
);

FunctionDecoeder i1_FunctionDecorder(
  .dec_funct_vld ( dec_funct_vld ),
  .dec_pc        ( dec_pc        ),
  .dec_auipc     ( dec_auipc     ),
  .dec_jal       ( dec_jal       ),
  .dec_jalr      ( dec_jalr      ),
  .dec_branch    ( dec_branch    ),
  .dec_taken     ( dec_taken     ),
  .dec_lsign     ( dec_lsign     ),
  .dec_csr_ren   ( dec_csr_ren   ),// CSR
  .dec_csr_wen   ( dec_csr_wen   ),// CSR
// ALU enable
  .is_ADD        ( is_ADD        ),
  .is_SUB        ( is_SUB        ),
  .is_AND        ( is_AND        ),
  .is_OR         ( is_OR         ),
  .is_XOR        ( is_XOR        ),
  .is_SLL        ( is_SLL        ),
  .is_SRL        ( is_SRL        ),
  .is_SRA        ( is_SRA        ),
  .is_ASG        ( is_ASG        ),
  .is_EQ         ( is_EQ         ),
  .is_NE         ( is_NE         ),
  .is_LT         ( is_LT         ),
  .is_LTU        ( is_LTU        ),
  .is_GT         ( is_GT         ),
  .is_GTU        ( is_GTU        ),
  .is_CSR        ( is_CSR        ),// CSR
  .is_CSRI       ( is_CSRI       ),// CSR
  .is_CSR_ADD    ( is_CSR_ADD    ),// CSR
  .is_CSR_SET    ( is_CSR_SET    ),// CSR
  .is_CSR_CLR    ( is_CSR_CLR    ),// CSR
  .rs2_sel       ( rs2_sel       ),
// LSU enable
  .is_LS         ( is_LS         ),
// CSR Hazard (Atomic)
  .csr_hazard    ( csr_hazard    ),
// from TYPE_DECODER
  .rd_p          ( rd_p          ),
  .rs1_p         ( rs1_p         ),  
  .funct3_p      ( funct3_p      ),
  .funct7_p      ( funct7_p      ),
  .is_OP         ( is_OP         ),
  .is_OP_IMM     ( is_OP_IMM     ),
  .is_LUI        ( is_LUI        ),
  .is_AUIPC      ( is_AUIPC      ),
  .is_JAL        ( is_JAL        ),
  .is_JALR       ( is_JALR       ),
  .is_BRANCH     ( is_BRANCH     ),
  .is_LOAD       ( is_LOAD       ),
  .is_STORE      ( is_STORE      ),
  .is_MISC_MEM   ( is_MISC_MEM   ),
  .is_SYSTEM     ( is_SYSTEM     ),
  .dec_freeze    ( dec_freeze    ),
  .alu_flush     ( alu_flush     ),
  .nop_insert    ( nop_insert    ),
  .inst_pc       ( inst_pc       ),
  .inst_taken    ( inst_taken    ),
  .inst_vld      ( inst_vld      ),
  .CLK           ( CLK           ),
  .RSTN          ( RSTN          )
);

endmodule