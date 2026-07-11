for i in range(32):
    print("always @(posedge CLK or negedge RSTN)")
    print("  begin")
    print("    if (~RSTN)")
    print("      x{:02d} <= 'd0;".format(i))
    print("    else if (w{:02d}_en)".format(i))
    print("      x{:02d} <= x_data;".format(i))
    print("  end\n")