/* Trap Unit - port shell only.
   Generated from RISCV_design.xlsx, sheet "Trap Units".
   Sits at the EX commit boundary; redirect to IFU has flush 1st priority
   (TRAP > MISPREDICT). CSR state lives inside EXU, accessed via
   tr2csr_* / csr2tr_*. */

module TrapUnit #(
   parameter  ADDR_WIDTH = 32
  ,parameter  DATA_WIDTH = 32
  ,parameter FAULT_WIDTH = 4   // TBD by trap spec ("faults")
  ,parameter CAUSE_WIDTH = 2
)(
  // EXUs to TRAP
    input wire                    ex2tr_valid
  ,output wire                    ex2tr_ready
  , input wire [  ADDR_WIDTH-1:0] ex2tr_pc
  , input wire [  ADDR_WIDTH-1:0] ex2tr_npc
  , input wire [ FAULT_WIDTH-1:0] ex2tr_faults   // misaligned / access fault
  // TRAP to IFU (redirection, flush 1st priority)
  ,output wire                    tr2if_valid
  , input wire                    tr2if_ready
  ,output wire                    tr2if_flush
  ,output wire [  ADDR_WIDTH-1:0] tr2if_pc       // = csr2tr_mtvec
  ,output wire [ CAUSE_WIDTH-1:0] tr2if_cause
  // TRAP to CSR
  ,output wire                    tr2csr_valid
  , input wire                    tr2csr_ready
  ,output wire                    tr2csr_we
  ,output wire [  ADDR_WIDTH-1:0] tr2csr_mepc
  ,output wire [  DATA_WIDTH-1:0] tr2csr_mtval
  ,output wire [  DATA_WIDTH-1:0] tr2csr_mcause
  ,output wire [  DATA_WIDTH-1:0] tr2csr_mstatus
  // CSR to TRAP
  , input wire                    csr2tr_MIE
  , input wire [  DATA_WIDTH-1:0] csr2tr_mie
  , input wire [  DATA_WIDTH-1:0] csr2tr_mip
  , input wire [  ADDR_WIDTH-1:0] csr2tr_mepc
  , input wire [  ADDR_WIDTH-1:0] csr2tr_mtvec
  // clock & reset
  , input wire                    clk_tr
  , input wire                    rstn_tr
);

endmodule
