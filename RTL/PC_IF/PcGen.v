module PcGen(
     output reg  [31:0] pc
    ,output wire [31:0] pc_nxt
    ,output wire        pc_vld
    , input wire [31:0] pc_ret
    , input      [31:0] pc_imm
    , input             pc_freeze
    , input             bp_taken
    , input      [31:0] bp_pc
    , input             mem_rvld
    , input      [31:0] mem_addr
    , input wire [31:0] boot_addr
    , input             CLK
    , input             RSTN
);

reg mem_rvld_hold;

assign pc_nxt = mem_addr + 3'd4;

assign pc_vld = ~pc_freeze & (mem_rvld | mem_rvld_hold);

always @(posedge CLK or negedge RSTN)
    begin
        if (~RSTN)
            mem_rvld_hold <= 'd1;
        else if (pc_vld)
            mem_rvld_hold <= 'd0;
        else if (mem_rvld)
            mem_rvld_hold <= 'd1;
    end

always @(posedge CLK or negedge RSTN)
    begin
        if (~RSTN)
            pc <= boot_addr;
        else if (pc_vld)
            pc <= pc_nxt;
    end

endmodule