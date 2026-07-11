`timescale 1ns / 1ps

`define CLK 10

module testbench();

    reg        clk       = 0;
    reg        rstn      = 0;
    reg [31:0] boot_addr = 32'h0000_0000;

    // HEX_FILE
    int hex_file  = 0;
    int inst_size = 1024;
    int data_size = 512;

    string hex;
    int fcheck;
    int freturn;

    initial forever clk = #(`CLK/2) ~clk;

    initial begin
        $fsdbDumpfile("CoreTop.fsdb");
        $fsdbDumpvars(0);
    end

    initial begin
        //
        hex_file = $fopen("test.hex", "r");
        // Load instruction to memory
        for (int i=0; i<inst_size; i++)
            begin : LOAD_INST_MEM
                fcheck  = $fgets(hex, hex_file);
                freturn = $sscanf(hex, "%x", i_CoreTop.i1_InstMemory.mem[i]);
            end
        // Load data to memory
        for (int i=0; i<data_size; i++)
            begin : LOAD_DATA_MEM
                fcheck  = $fgets(hex, hex_file);
                freturn = $sscanf(hex, "%x\n", i_CoreTop.i6_DataMemory.mem[i]);
            end
        //
        // Set boot address (initial PC)
        boot_addr = 32'hFFFF_0000;
        #100;
        rstn = 1;

        fork
            begin
                wait(testbench.i_CoreTop.i10_CSRTop.i0_CSR.mscratch == 32'h1234_FFFF);
                $display("Code Failed\n");
            end
        
            begin
                wait(testbench.i_CoreTop.i10_CSRTop.i0_CSR.mscratch == 32'hFFFF_1234);
                $display("Code Finish\n");
            end
        join_any
        
        #10;
        $finish;
    end

    CoreTop i_CoreTop (
        boot_addr,
        clk,
        rstn
    );

endmodule