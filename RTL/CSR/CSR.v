module CSR (
   output wire [31:0] csr_rdata
  , input wire [31:0] csr_wdata
  , input wire        csr_ren   // read
  , input wire        csr_wen   // write
  , input wire [11:0] csr_addr  // address
  , input wire        CLK
  , input wire        RSTN
);

// Mapping and Write
// ADDR == 0xF11
reg [31:0]     mvendorid;
wire       hit_mvendorid = csr_addr == 12'hF11;

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      mvendorid <= 'd0;
    else if (hit_mvendorid && csr_wen)
      mvendorid <= csr_wdata;
  end

// ADDR == 0xF12
reg [31:0]     marchid;
wire       hit_marchid = csr_addr == 12'hF12;

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      marchid <= 'd0;
    else if (hit_marchid && csr_wen)
      marchid <= csr_wdata;
  end

// ADDR == 0xF13
reg [31:0]     mimpid;
wire       hit_mimpid = csr_addr == 12'hF13;

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      mimpid <= 'd0;
    else if (hit_mimpid && csr_wen)
      mimpid <= csr_wdata;
  end

// ADDR == 0xF14
reg [31:0]     mhartid;
wire       hit_mhartid = csr_addr == 12'hF14;

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      mhartid <= 'd0;
    else if (hit_mhartid && csr_wen)
      mhartid <= csr_wdata;
  end

// ADDR == 0xF15
reg [31:0]     mconfigptr;
wire       hit_mconfigptr = csr_addr == 12'hF15;

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      mconfigptr <= 'd0;
    else if (hit_mconfigptr && csr_wen)
      mconfigptr <= csr_wdata;
  end

// ADDR == 0x340
reg  [31:0]     mscratch;
wire        hit_mscratch = csr_addr == 12'h340;

always @(posedge CLK or negedge RSTN)
  begin
    if (~RSTN)
      mscratch <= 'd0;
    else if (hit_mscratch && csr_wen)
      mscratch <= csr_wdata;
  end

// Mapping and Read
assign csr_rdata = (hit_mvendorid  && csr_ren) ? mvendorid  :
                   (hit_marchid    && csr_ren) ? marchid    :
                   (hit_mimpid     && csr_ren) ? mimpid     :
                   (hit_mhartid    && csr_ren) ? mhartid    :
                   (hit_mconfigptr && csr_ren) ? mconfigptr :
                   (hit_mscratch   && csr_ren) ? mscratch   : 'd0;

endmodule