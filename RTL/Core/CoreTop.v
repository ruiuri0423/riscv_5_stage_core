module CoreTop (
     input wire [31:0] boot_addr
    ,input wire        CLK
    ,input wire        RSTN
);

// Stage : Instruction Fetch
wire        inst_mem_en;
wire [ 3:0] inst_mem_wen;
wire [31:0] inst_mem_addr;
wire [31:0] inst_mem_wdata;
wire [31:0] inst_mem_rdata;
wire        inst_mem_rvld;

wire [31:0] inst;
wire [31:0] inst_pc;
wire        inst_vld;

wire [31:0] pc;
wire [31:0] pc_nxt;
wire [31:0] pc_ret;
wire [31:0] pc_imm;

// Stage : Decoder  
wire        dec_vld;
wire [ 4:0] dec_rs1;
wire [ 4:0] dec_rs2;
wire [ 4:0] dec_rs1_p;
wire [ 4:0] dec_rs2_p;
wire        dec_rs1_ren;
wire        dec_rs2_ren;
wire [ 4:0] dec_rd;
wire        dec_rd_wen;
wire [31:0] dec_rs1_data;
wire [31:0] dec_rs2_data;
wire [31:0] dec_imm_data;
wire [ 3:0] dec_LS;
wire [31:0] dec_pc;
wire [11:0] dec_csr_addr; // CSR
wire [31:0] dec_csr_imm;  // CSR
wire        dec_csr_ren;  // CSR
wire        dec_csr_wen;  // CSR
wire        csr_hazard;   // CSR

// Stage : Execute
wire [31:0] alu_rs2_data;
wire [31:0] alu_out;
wire [ 0:0] alu_out_vld;
wire [ 4:0] alu_rd;
wire [ 0:0] alu_rd_wen;
wire [ 3:0] alu_LS;
wire        alu_branch;
wire        alu_taken;
wire        alu_flush;
wire [31:0] alu_target;
wire [31:0] alu_pc;
wire        alu_csr_vld;
wire [31:0] alu_csr_out;

// Stage : Memory Access
wire        lsu_ready;
wire [31:0] lsu_mem_rdata;
wire        lsu_mem_rvld;
wire        lsu_mem_en;
wire [ 3:0] lsu_mem_wen;
wire [31:0] lsu_mem_addr;
wire [31:0] lsu_mem_wdata;
wire [31:0] lsu_out;
wire        lsu_out_vld;
wire [ 4:0] lsu_rd;
wire [ 3:0] lsu_rstrb;
wire        lsu_rd_wen;

// Stage : Writeback
wire [31:0] wb_rd_data;
wire [ 4:0] wb_rd;
wire        wb_rd_wen; 

// Module : CoreBus
wire [31:0] core_bus_inst_mem_rdata;
wire        core_bus_inst_mem_rvld;
wire        core_bus_inst_mem_en;
wire [31:0] core_bus_inst_mem_addr;
wire [31:0] core_bus_inst_mem_wdata;
wire [ 3:0] core_bus_inst_mem_wen;
wire [31:0] core_bus_lsu_mem_rdata;
wire        core_bus_lsu_mem_rvld;
wire        core_bus_lsu_mem_en;
wire [31:0] core_bus_lsu_mem_addr;
wire [31:0] core_bus_lsu_mem_wdata;
wire [ 3:0] core_bus_lsu_mem_wen;

// Module : Forward Unit
wire [ 0:0] nop_insert;
wire [ 0:0] rs1_forward;
wire [31:0] rs1_forward_data;
wire [ 0:0] rs2_forward;
wire [31:0] rs2_forward_data;

InstFetch i0_InstFetch(
    .lsu_ready  ( lsu_ready      ),
    .inst       ( inst           ),
    .inst_pc    ( inst_pc        ),
    .inst_taken ( inst_taken     ),
    .inst_vld   ( inst_vld       ),
    .mem_en     ( inst_mem_en    ),
    .mem_addr   ( inst_mem_addr  ),
    .mem_wdata  ( inst_mem_wdata ),
    .mem_wen    ( inst_mem_wen   ),
    .mem_rdata  ( inst_mem_rdata ),
    .mem_rvld   ( inst_mem_rvld  ),
    .pc         ( pc             ),
    .pc_nxt     ( pc_nxt         ),
    .pc_ret     ( pc_ret         ),
    .pc_imm     ( pc_imm         ), 
    .alu_branch ( alu_branch     ),
    .alu_call   ( alu_call       ),
    .alu_return ( alu_return     ),
    .alu_taken  ( alu_taken      ),
    .alu_flush  ( alu_flush      ),
    .alu_target ( alu_target     ),
    .alu_pc     ( alu_pc         ),
    .csr_hazard ( csr_hazard     ),
    .nop_insert ( nop_insert     ),
    .boot_addr  ( boot_addr      ),
    .CLK        ( CLK            ),
    .RSTN       ( RSTN           )
);

MemoryModel i1_InstMemory(
    .mem_rdata  ( core_bus_inst_mem_rdata       ),
    .mem_rvld   ( core_bus_inst_mem_rvld        ),
    .mem_en     ( core_bus_inst_mem_en          ),
    .mem_addr   ( core_bus_inst_mem_addr[11:2]  ),
    .mem_wdata  ( core_bus_inst_mem_wdata       ),
    .mem_wen    ( core_bus_inst_mem_wen         ),
    .CLK        ( CLK                           ),
    .RSTN       ( RSTN                          ) 
);

DecoderTop i2_DecoderTop(
  .lsu_ready     ( lsu_ready    ),
  .dec_funct_vld ( dec_vld      ),
  .dec_type_vld  (              ),
  .dec_auipc     ( dec_auipc    ),
  .dec_jal       ( dec_jal      ),
  .dec_jalr      ( dec_jalr     ),
  .dec_branch    ( dec_branch   ),
  .dec_taken     ( dec_taken    ),
  .dec_lsign     ( dec_lsign    ),
  .dec_csr_addr  ( dec_csr_addr ),// CSR
  .dec_csr_imm   ( dec_csr_imm  ),// CSR
  .dec_csr_ren   ( dec_csr_ren  ),// CSR
  .dec_csr_wen   ( dec_csr_wen  ),// CSR
  .dec_pc        ( dec_pc       ),
  .rs1_ren       ( dec_rs1_ren  ),
  .rs2_ren       ( dec_rs2_ren  ),
  .rd_wen        ( dec_rd_wen   ),
  .imm           ( dec_imm_data ),
  .funct7        (              ),
  .rs2           ( dec_rs2      ),
  .rs1           ( dec_rs1      ),
  .rs2_p         ( dec_rs2_p    ),
  .rs1_p         ( dec_rs1_p    ),
  .funct3        (              ),           
  .rd            ( dec_rd       ),
  .opcode        (              ),           
  .is_ADD        ( is_ADD       ),
  .is_SUB        ( is_SUB       ),
  .is_AND        ( is_AND       ),
  .is_OR         ( is_OR        ),
  .is_XOR        ( is_XOR       ),
  .is_SLL        ( is_SLL       ),
  .is_SRL        ( is_SRL       ),
  .is_SRA        ( is_SRA       ),
  .is_ASG        ( is_ASG       ),
  .is_EQ         ( is_EQ        ),
  .is_NE         ( is_NE        ),
  .is_LT         ( is_LT        ),
  .is_LTU        ( is_LTU       ),
  .is_GT         ( is_GT        ),
  .is_GTU        ( is_GTU       ),
  .is_CSR        ( is_CSR       ),// CSR
  .is_CSRI       ( is_CSRI      ),// CSR
  .is_CSR_ADD    ( is_CSR_ADD   ),// CSR
  .is_CSR_SET    ( is_CSR_SET   ),// CSR
  .is_CSR_CLR    ( is_CSR_CLR   ),// CSR
  .rs2_sel       ( rs2_sel      ),
  .is_LS         ( dec_LS       ),
  .csr_hazard    ( csr_hazard   ),
  .nop_insert    ( nop_insert   ),
  .alu_flush     ( alu_flush    ),
  .inst          ( inst         ),
  .inst_pc       ( inst_pc      ),
  .inst_taken    ( inst_taken   ),
  .inst_vld      ( inst_vld     ),
  .CLK           ( CLK          ),
  .RSTN          ( RSTN         ) 
);

RegisterTop i3_RegisterTop(
  .rs1_data         ( dec_rs1_data     ),
  .rs2_data         ( dec_rs2_data     ),
  .rd_data          ( wb_rd_data       ),
  .rd               ( wb_rd            ),
  .rd_wen           ( wb_rd_wen        ), 
  .rs1              ( dec_rs1_p        ),
  .rs2              ( dec_rs2_p        ),
  .rs1_ren          ( dec_rs1_ren      ),
  .rs2_ren          ( dec_rs2_ren      ),
  .rs1_forward      ( rs1_forward      ),
  .rs1_forward_data ( rs1_forward_data ),
  .rs2_forward      ( rs2_forward      ),
  .rs2_forward_data ( rs2_forward_data ),
  .CLK              ( CLK              ),
  .RSTN             ( RSTN             )
);

ALUTop i4_ALUTop(
    .lsu_ready        ( lsu_ready        ),
    .alu_rs2_data     ( alu_rs2_data     ),
    .alu_out          ( alu_out          ),
    .alu_out_vld      ( alu_out_vld      ),
    .alu_rd_wen       ( alu_rd_wen       ),
    .alu_rd           ( alu_rd           ),
    .alu_LS           ( alu_LS           ),
    .alu_branch       ( alu_branch       ),// branch predict
    .alu_call         ( alu_call         ),// branch predict
    .alu_return       ( alu_return       ),// branch predict
    .alu_taken        ( alu_taken        ),// branch predict
    .alu_flush        ( alu_flush        ),// branch predict
    .alu_target       ( alu_target       ),// branch predict
    .alu_pc           ( alu_pc           ),// branch predict
    .alu_lsign        ( alu_lsign        ),
    .dec_vld          ( dec_vld          ),              
    .dec_rs1          ( dec_rs1          ),
    .dec_rs2          ( dec_rs2          ),
    .dec_rs1_data     ( dec_rs1_data     ),
    .dec_rs2_data     ( dec_rs2_data     ),
    .dec_imm          ( dec_imm_data     ),
    .dec_rd_wen       ( dec_rd_wen       ),
    .dec_rd           ( dec_rd           ),
    .dec_LS           ( dec_LS           ),
    .dec_pc           ( dec_pc           ),
    .dec_auipc        ( dec_auipc        ),
    .dec_jal          ( dec_jal          ),
    .dec_jalr         ( dec_jalr         ),
    .dec_branch       ( dec_branch       ),
    .dec_taken        ( dec_taken        ),
    .dec_lsign        ( dec_lsign        ),
    .inst_pc          ( inst_pc          ),
    .is_ADD           ( is_ADD           ),
    .is_SUB           ( is_SUB           ),
    .is_AND           ( is_AND           ),
    .is_OR            ( is_OR            ),
    .is_XOR           ( is_XOR           ),
    .is_SLL           ( is_SLL           ),
    .is_SRL           ( is_SRL           ),
    .is_SRA           ( is_SRA           ),
    .is_ASG           ( is_ASG           ),
    .is_EQ            ( is_EQ            ),
    .is_NE            ( is_NE            ),
    .is_LT            ( is_LT            ),
    .is_LTU           ( is_LTU           ),
    .is_GT            ( is_GT            ),
    .is_GTU           ( is_GTU           ),
    .rs2_sel          ( rs2_sel          ),
    .CLK              ( CLK              ),
    .RSTN             ( RSTN             ) 
);

LSU i5_LSU(
    .alu_rs2_data( alu_rs2_data  ),
    .alu_out     ( alu_out       ),
    .alu_out_vld ( alu_out_vld   ),
    .alu_rd      ( alu_rd        ),
    .alu_rd_wen  ( alu_rd_wen    ),
    .alu_LS      ( alu_LS        ),// bit 3: enable, bit 2: is store, bit 1~0: word/half/byte 
    .alu_lsign   ( alu_lsign     ),
    .alu_csr_vld ( alu_csr_vld   ),
    .alu_csr_out ( alu_csr_out   ),
    .lsu_out     ( lsu_out       ),
    .lsu_out_vld ( lsu_out_vld   ),
    .lsu_rd_wen  ( lsu_rd_wen    ),
    .lsu_rd      ( lsu_rd        ),
    .lsu_rstrb   ( lsu_rstrb     ),
    .lsu_lsign   ( lsu_lsign     ),
    .lsu_ready   ( lsu_ready     ),
// memory interface
    // response
    .mem_rdata   ( lsu_mem_rdata ),
    .mem_rvld    ( lsu_mem_rvld  ),
    // request   
    .mem_en      ( lsu_mem_en    ),
    .mem_wen     ( lsu_mem_wen   ),
    .mem_addr    ( lsu_mem_addr  ),
    .mem_wdata   ( lsu_mem_wdata ),
//               
    .CLK         ( CLK           ),
    .RSTN        ( RSTN          )
);

MemoryModel i6_DataMemory(
    .mem_rdata  ( core_bus_lsu_mem_rdata      ),
    .mem_rvld   ( core_bus_lsu_mem_rvld       ),
    .mem_en     ( core_bus_lsu_mem_en         ),
    .mem_addr   ( core_bus_lsu_mem_addr[11:2] ),
    .mem_wdata  ( core_bus_lsu_mem_wdata      ),
    .mem_wen    ( core_bus_lsu_mem_wen        ),
    .CLK        ( CLK                         ),
    .RSTN       ( RSTN                        ) 
);

WriteBack i7_WriteBack(
    .lsu_out       ( lsu_out       ),
    .lsu_out_vld   ( lsu_out_vld   ),
    .lsu_mem_rdata ( lsu_mem_rdata ),
    .lsu_mem_rvld  ( lsu_mem_rvld  ),
    .lsu_rstrb     ( lsu_rstrb     ),
    .lsu_rd        ( lsu_rd        ),
    .lsu_rd_wen    ( lsu_rd_wen    ),
    .lsu_lsign     ( lsu_lsign     ),
    .wb_rd         ( wb_rd         ),
    .wb_rd_data    ( wb_rd_data    ),
    .wb_rd_wen     ( wb_rd_wen     ),
    .CLK           ( CLK           ),
    .RSTN          ( RSTN          )
);


CoreBus#(
  .INST_BASE_ADDR ( 32'hFFFF_0000 ),
  .INST_ADDR_LEN  ( 32'h0000_1000 ),
  .DATA_BASE_ADDR ( 32'hFFFF_1000 ),
  .DATA_ADDR_LEN  ( 32'h0000_1000 ) 
) i8_CoreBus (
  .inst_mem_rdata          ( inst_mem_rdata           ),
  .inst_mem_rvld           ( inst_mem_rvld            ),
  .inst_mem_en             ( inst_mem_en              ),
  .inst_mem_addr           ( inst_mem_addr            ),
  .inst_mem_wdata          ( inst_mem_wdata           ),
  .inst_mem_wen            ( inst_mem_wen             ),
  .core_bus_inst_mem_rdata ( core_bus_inst_mem_rdata  ),
  .core_bus_inst_mem_rvld  ( core_bus_inst_mem_rvld   ),
  .core_bus_inst_mem_en    ( core_bus_inst_mem_en     ),
  .core_bus_inst_mem_addr  ( core_bus_inst_mem_addr   ),
  .core_bus_inst_mem_wdata ( core_bus_inst_mem_wdata  ),
  .core_bus_inst_mem_wen   ( core_bus_inst_mem_wen    ),
  .lsu_mem_rdata           ( lsu_mem_rdata            ),
  .lsu_mem_rvld            ( lsu_mem_rvld             ),
  .lsu_mem_en              ( lsu_mem_en               ),
  .lsu_mem_addr            ( lsu_mem_addr             ),
  .lsu_mem_wdata           ( lsu_mem_wdata            ),
  .lsu_mem_wen             ( lsu_mem_wen              ),
  .core_bus_lsu_mem_rdata  ( core_bus_lsu_mem_rdata   ),
  .core_bus_lsu_mem_rvld   ( core_bus_lsu_mem_rvld    ),
  .core_bus_lsu_mem_en     ( core_bus_lsu_mem_en      ),
  .core_bus_lsu_mem_addr   ( core_bus_lsu_mem_addr    ),
  .core_bus_lsu_mem_wdata  ( core_bus_lsu_mem_wdata   ),
  .core_bus_lsu_mem_wen    ( core_bus_lsu_mem_wen     ),
  .CLK                     ( CLK                      ),
  .RSTN                    ( RSTN                     )
);

ForwardUnit i9_ForwardUnit(
  .dec_rs2_p        ( dec_rs2_p             ),
  .dec_rs1_p        ( dec_rs1_p             ),
  .dec_rd_wen       ( dec_rd_wen            ),
  .dec_rd           ( dec_rd                ),
  .dec_rs2          ( dec_rs2               ),
  .dec_rs1          ( dec_rs1               ),
  .dec_LS           ( dec_LS                ),
  .lsu_mem_rvld     ( lsu_mem_rvld          ),
  .alu_flush        ( alu_flush             ),
  .alu_LS           ( alu_LS                ),
  .alu_rd           ( alu_rd                ),
  .alu_rd_wen       ( alu_rd_wen            ),
  .alu_out          ( alu_out               ),
  .alu_csr_vld      ( alu_csr_vld           ),// CSR
  .alu_csr_out      ( alu_csr_out           ),// CSR
  .wb_rd            ( wb_rd                 ),
  .wb_rd_wen        ( wb_rd_wen             ),
  .wb_rd_data       ( wb_rd_data            ),
  .nop_insert       ( nop_insert            ),
  .rs1_forward      ( rs1_forward           ),
  .rs1_forward_data ( rs1_forward_data      ),
  .rs2_forward      ( rs2_forward           ),
  .rs2_forward_data ( rs2_forward_data      ),
  .CLK              ( CLK                   ),
  .RSTN             ( RSTN                  )
);

CSRTop i10_CSRTop(
  .alu_csr_vld      ( alu_csr_vld      ),
  .alu_csr_out      ( alu_csr_out      ),
  .dec_rs1_data     ( dec_rs1_data     ),
  .dec_csr_imm      ( dec_csr_imm      ),
  .dec_csr_addr     ( dec_csr_addr     ),
  .dec_csr_ren      ( dec_csr_ren      ),
  .dec_csr_wen      ( dec_csr_wen      ),
  .is_CSR           ( is_CSR           ),
  .is_CSRI          ( is_CSRI          ),
  .is_CSR_ADD       ( is_CSR_ADD       ),
  .is_CSR_SET       ( is_CSR_SET       ),
  .is_CSR_CLR       ( is_CSR_CLR       ),
  .lsu_ready        ( lsu_ready        ),
  .alu_flush        ( alu_flush        ),
  .CLK              ( CLK              ),
  .RSTN             ( RSTN             ) 
);

endmodule
