module InstFetch (
    // 
     output wire [31:0] inst
    ,output reg  [31:0] inst_pc
    ,output reg         inst_taken
    ,output wire        inst_vld
    // Memory Interface
    ,output wire        mem_en
    ,output wire [31:0] mem_addr
    ,output wire [31:0] mem_wdata
    ,output wire [ 3:0] mem_wen
    , input wire [31:0] mem_rdata
    , input wire        mem_rvld
    //
    ,output wire [31:0] pc
    ,output wire [31:0] pc_nxt
    , input wire [31:0] pc_ret
    , input wire [31:0] pc_imm
    // From ALU
    , input wire        alu_branch
    , input wire        alu_call
    , input wire        alu_return
    , input wire        alu_taken 
    , input wire        alu_flush 
    , input wire [31:0] alu_target
    , input wire [31:0] alu_pc    
    //
    , input wire        lsu_ready
    , input wire        csr_hazard
    , input wire        nop_insert
    , input wire [31:0] boot_addr
    //
    , input wire        CLK
    , input wire        RSTN
);

wire        bp_taken;
wire [31:0] bp_pc;
wire        pc_freeze;
reg         inst_vld_hold;
reg         alu_branch_hold;
reg         alu_taken_hold;
reg         alu_flush_hold;
reg  [31:0] alu_target_hold;
reg  [31:0] alu_pc_hold; 

PcGen i0_PcGen(
    .pc        ( pc        ),
    .pc_nxt    ( pc_nxt    ),
    .pc_vld    ( pc_vld    ),
    .pc_ret    ( pc_ret    ),
    .pc_freeze ( pc_freeze ),
    .pc_imm    ( pc_imm    ),
    .bp_taken  ( bp_taken  ),
    .bp_pc     ( bp_pc     ),
    .mem_rvld  ( mem_rvld  ),
    .mem_addr  ( mem_addr  ),
    .boot_addr ( boot_addr ),
    .CLK       ( CLK       ),
    .RSTN      ( RSTN      )
);

BranchPredict #(
    .BHT_DEPTH ( 16   ),
    .BHT_WIDTH ( 4    ),
    .BTB_DEPTH ( 16   ),
    .BTB_WIDTH ( 4    ),
    .TAG_WIDTH ( 6    )// BTB tag widht
) i1_BranchPredict (  
    .bp_taken   ( bp_taken   ),
    .bp_pc      ( bp_pc      ),
    .pc_freeze  ( pc_freeze  ),
    .pc_vld     ( inst_vld   ),
    .pc         ( inst_pc    ),
    .alu_branch ( alu_branch ),
    .alu_call   ( alu_call   ),
    .alu_return ( alu_return ),
    .alu_taken  ( alu_taken  ),
    .alu_flush  ( alu_flush  ),
    .alu_target ( alu_target ),
    .alu_pc     ( alu_pc     ),
    .CLK        ( CLK        ),
    .RSTN       ( RSTN       )
);

assign inst       = mem_rdata;
assign inst_vld   = mem_rvld | inst_vld_hold;
assign inst_taken = bp_taken;

assign mem_en    = pc_vld;
assign mem_addr  = alu_flush      ? 
                   alu_taken      ? alu_target      :
                                    alu_pc + 4      : /* If miss prediction -> 
                                                    take the pc(branch_inst.) + 4 */
                   alu_flush_hold ? 
                   alu_taken_hold ? alu_target_hold :
                                    alu_pc_hold + 4 :  /* If miss prediction -> 
                                                    take the pc(branch_inst.) + 4 */
                   bp_taken       ? bp_pc           : pc;
assign mem_wdata = 'd0; /* Instruction Memory without write */
assign mem_wen   = 'd0; /* Instruction Memory without write */

assign pc_freeze = nop_insert | ~lsu_ready | csr_hazard;

always @(posedge CLK or negedge RSTN)
    begin
        if (~RSTN)
            inst_vld_hold <= 'd0;
        else if (~pc_freeze)
            inst_vld_hold <= 'd0; 
        else if ( pc_freeze)
            inst_vld_hold <= inst_vld;
    end

always @(posedge CLK or negedge RSTN)
    begin
        if (~RSTN)
            begin
                alu_branch_hold <= 'd0;
                alu_taken_hold  <= 'd0;
                alu_flush_hold  <= 'd0;
                alu_target_hold <= 'd0;
                alu_pc_hold     <= 'd0;
            end
        else if (pc_vld)
            begin
                alu_branch_hold <= 'd0;
                alu_taken_hold  <= 'd0;
                alu_flush_hold  <= 'd0;
                alu_target_hold <= 'd0;
                alu_pc_hold     <= 'd0;
            end
        else if (alu_flush)
            begin
                alu_branch_hold <= alu_branch;
                alu_taken_hold  <= alu_taken ;
                alu_flush_hold  <= alu_flush ;
                alu_target_hold <= alu_target;
                alu_pc_hold     <= alu_pc    ;
            end
    end

always @(posedge CLK or negedge RSTN)
    begin
        if (~RSTN)
            inst_pc    <= 'd0;
        else if (mem_en)
            inst_pc    <= mem_addr;
    end

endmodule