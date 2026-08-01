`ifndef DEF_DEC_VH
`define DEF_DEC_VH
`define INST_OP       7'b0110011 
`define INST_OP_IMM   7'b0010011 
`define INST_LUI      7'b0110111
`define INST_AUIPC    7'b0010111 
`define INST_JAL      7'b1101111 
`define INST_JALR     7'b1100111 
`define INST_BRANCH   7'b1100011 
`define INST_LOAD     7'b0000011 
`define INST_STORE    7'b0100011 
`define INST_MISC_MEM 7'b0001111
`define INST_SYSTEM   7'b1110011 

`define FUNCT_ADD    3'b000
`define FUNCT_SUB    3'b000
`define FUNCT_SLL    3'b001
`define FUNCT_SLT    3'b010
`define FUNCT_SLTU   3'b011
`define FUNCT_XOR    3'b100
`define FUNCT_SRL    3'b101
`define FUNCT_SRA    3'b101
`define FUNCT_OR     3'b110
`define FUNCT_AND    3'b111
`define FUNCT_ADDI   3'b000
`define FUNCT_SLTI   3'b010 
`define FUNCT_SLTIU  3'b011
`define FUNCT_XORI   3'b100
`define FUNCT_ORI    3'b110
`define FUNCT_ANDI   3'b111
`define FUNCT_SLLI   3'b001
`define FUNCT_SRLI   3'b101
`define FUNCT_SRAI   3'b101
`define FUNCT_JALR   3'b000
//`define FUNCT_LOAD  
`define FUNCT_LB     3'b000
`define FUNCT_LH     3'b001
`define FUNCT_LW     3'b010
`define FUNCT_LBU    3'b100
`define FUNCT_LHU    3'b101
`define FUNCT_NOP    3'b000
//`define FUNCT_STORE
`define FUNCT_SB     3'b000
`define FUNCT_SH     3'b001
`define FUNCT_SW     3'b010
`define FUNCT_BEQ    3'b000
`define FUNCT_BNE    3'b001
`define FUNCT_BLT    3'b100
`define FUNCT_BGE    3'b101
`define FUNCT_BLTU   3'b110
`define FUNCT_BGEU   3'b111
//`define CSR Atomic
`define FUNCT_CSRRW  3'b001
`define FUNCT_CSRRS  3'b010
`define FUNCT_CSRRC  3'b011
`define FUNCT_CSRRWI 3'b101
`define FUNCT_CSRRSI 3'b110
`define FUNCT_CSRRCI 3'b111
//`define EEI
`define FUNCT_ECALL  12'b000000000000
`define FUNCT_EBREAK 12'b000000000001

`define I_TYPE_IMM   {{21{if2id_inst[31]}}, if2id_inst[30:20]} 
`define S_TYPE_IMM   {{21{if2id_inst[31]}}, if2id_inst[30:25], if2id_inst[11:8], if2id_inst[7]}
`define B_TYPE_IMM   {{20{if2id_inst[31]}}, if2id_inst[7], if2id_inst[30:25], if2id_inst[11:8], 1'b0}
`define U_TYPE_IMM   {if2id_inst[31], if2id_inst[30:20], if2id_inst[19:12], 12'd0}
`define J_TYPE_IMM   {{12{if2id_inst[31]}}, if2id_inst[19:12], if2id_inst[20], if2id_inst[30:21], 1'b0}
`endif