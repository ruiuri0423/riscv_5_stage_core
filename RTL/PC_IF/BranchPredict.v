module BranchPredict #(
     parameter BHT_DEPTH = 16
    ,parameter BHT_WIDTH = 4
    ,parameter BTB_DEPTH = 1023
    ,parameter BTB_WIDTH = 10 
    ,parameter TAG_WIDTH = 22 // BTB tag widht
    ,parameter RAS_DEPTH = 4
    ,parameter RAS_WIDTH = 2
)(  
     output wire        bp_taken
    ,output wire [31:0] bp_pc
    , input             pc_freeze
    , input             pc_vld
    , input      [31:0] pc
    , input             alu_branch
    , input             alu_call
    , input             alu_return
    , input             alu_taken
    , input             alu_flush
    , input      [31:0] alu_target
    , input      [31:0] alu_pc
    //           
    , input             CLK
    , input             RSTN
);

integer i;

parameter [1:0] STRONGLY_TAKEN     = 2'b11;
parameter [1:0] WEAKLY_TAKEN       = 2'b10;
parameter [1:0] WEAKLY_NOT_TAKEN   = 2'b01;
parameter [1:0] STRONGLY_NOT_TAKEN = 2'b00;

// Branch History Table (BHT)
reg  [BHT_WIDTH-1:0] bht_queue;
reg  [BHT_WIDTH-1:0] bht_queue_spec; // speculative queue
reg  [          1:0] bht_counter [BHT_DEPTH-1:0]; // 2-bit saturate counter

// Counter index : gshare
wire [BHT_WIDTH-1:0] bht_alu_idx = bht_queue      ^ alu_pc[BTB_WIDTH+:BHT_WIDTH];
wire [BHT_WIDTH-1:0] bht_pc_idx  = bht_queue_spec ^     pc[BTB_WIDTH+:BHT_WIDTH];

// Speculative taken
wire pc_taken;
wire pc_n_taken;

always @(posedge CLK or negedge RSTN)
  begin : BHT_QUEUE;
    if (~RSTN)
      bht_queue <= 'd0;
    else if (alu_branch)
      bht_queue <= {bht_queue[BHT_WIDTH-2:0], alu_taken};
  end

always @(posedge CLK or negedge RSTN)
  begin : BHT_QUEUE_SPEC;
    if (~RSTN)
      bht_queue_spec <= 'd0;
    else if (alu_flush) // flush the speculative queue if misprediction.
      bht_queue_spec <= {bht_queue[BHT_WIDTH-2:0], alu_taken};
    else if (pc_taken || pc_n_taken)
      bht_queue_spec <= {bht_queue_spec[BHT_WIDTH-2:0], pc_taken};
  end

always @(posedge CLK or negedge RSTN)
  begin : BHT_COUNTER;
    if (~RSTN)
      begin
        for (i=0; i<BHT_DEPTH; i=i+1)
          bht_counter[i] <= STRONGLY_TAKEN; 
      end
    else if (alu_branch)
      begin
        case (bht_counter[bht_alu_idx])
          STRONGLY_TAKEN : 
            if (~alu_taken) 
              bht_counter[bht_alu_idx] <= WEAKLY_TAKEN;

          WEAKLY_TAKEN : 
            if (~alu_taken) 
              bht_counter[bht_alu_idx] <= STRONGLY_NOT_TAKEN;
            else            
              bht_counter[bht_alu_idx] <= STRONGLY_TAKEN;

          WEAKLY_NOT_TAKEN : 
            if ( alu_taken) 
              bht_counter[bht_alu_idx] <= STRONGLY_TAKEN;
            else            
              bht_counter[bht_alu_idx] <= STRONGLY_NOT_TAKEN;

          STRONGLY_NOT_TAKEN : 
            if ( alu_taken) 
              bht_counter[bht_alu_idx] <= WEAKLY_NOT_TAKEN;
        endcase
      end
  end

// Return Adress Stack (RAS)
reg [32:0] ras_stack      [RAS_DEPTH-1:0];
reg [32:0] ras_stack_spec [RAS_DEPTH-1:0]; // speculative queue
wire       pc_call; 
wire       pc_return;

always @(posedge CLK or negedge RSTN)
  begin : RAS_STACK
    if (~RSTN)
      for (i=0; i<RAS_DEPTH; i=i+1)
        ras_stack[i] <= 'd0;
    else if (alu_branch)
      begin
        if (alu_call & ~alu_return) // push
          begin
            ras_stack[RAS_DEPTH-1][31:0] <= (alu_pc + 3'd4);
            ras_stack[RAS_DEPTH-1][32  ] <= 1'b1; // stack data is valid
            for (i=0; i<RAS_DEPTH-1; i=i+1)
              begin
                ras_stack[i] <= ras_stack[i+1];   
              end
          end
        else if (~alu_call & alu_return) // pop
          begin
            ras_stack[0] <= 'd0;
            for (i=1; i<RAS_DEPTH; i=i+1)
              ras_stack[i] <= ras_stack[i-1];   
          end
        else if (alu_call & alu_return) // pop then push
          begin
            ras_stack[RAS_DEPTH-1][31:0] <= (alu_pc + 3'd4);
            ras_stack[RAS_DEPTH-1][32  ] <= 1'b1; // stack data is valid
          end
      end
  end

always @(posedge CLK or negedge RSTN)
  begin : RAS_STACK_SPEC
    if (~RSTN)
      for (i=0; i<RAS_DEPTH; i=i+1)
        ras_stack_spec[i] <= 'd0;
    else if (alu_flush) // miss predict
      begin
        if (alu_call & ~alu_return) // push
          begin
            ras_stack_spec[RAS_DEPTH-1][31:0] <= (alu_pc + 3'd4);
            ras_stack_spec[RAS_DEPTH-1][32  ] <= 1'b1; // stack data is valid
            for (i=0; i<RAS_DEPTH-1; i=i+1)
              ras_stack_spec[i] <= ras_stack[i+1];   
          end
        else if (~alu_call & alu_return) // pop
          begin
            ras_stack_spec[0] <= 'd0;
            for (i=1; i<RAS_DEPTH; i=i+1)
              ras_stack_spec[i] <= ras_stack[i-1];   
          end
        else if (alu_call & alu_return)
          begin
            ras_stack_spec[RAS_DEPTH-1][31:0] <= (alu_pc + 3'd4);
            ras_stack_spec[RAS_DEPTH-1][32  ] <= 1'b1; // stack data is valid
            for (i=1; i<RAS_DEPTH; i=i+1)
              ras_stack_spec[i] <= ras_stack[i];   
          end
        else // not a call or return
          begin
            for (i=0; i<RAS_DEPTH; i=i+1)
              ras_stack_spec[i] <= ras_stack[i];   
          end
      end
    else // speculative
      begin
        if (pc_call & ~pc_return) // push
          begin
            ras_stack_spec[RAS_DEPTH-1][31:0] <= (pc + 3'd4);
            ras_stack_spec[RAS_DEPTH-1][32  ] <= 1'b1;
            for (i=0; i<RAS_DEPTH-1; i=i+1)
              begin
                ras_stack_spec[i] <= ras_stack_spec[i+1];   
              end
          end
        else if (~pc_call & pc_return) // pop
          begin
            ras_stack_spec[0] <= 'd0;
            for (i=1; i<RAS_DEPTH; i=i+1)
              ras_stack_spec[i] <= ras_stack_spec[i-1];   
          end
        else if (~pc_call & pc_return) // pop then push
          begin
            ras_stack_spec[RAS_DEPTH-1][31:0] <= (pc + 3'd4);
            ras_stack_spec[RAS_DEPTH-1][32  ] <= 1'b1;  
          end
      end
  end

// Branch Target Buffer (BTB)
reg                  btb_valid  [BTB_DEPTH-1:0];
reg                  btb_call   [BTB_DEPTH-1:0];
reg                  btb_return [BTB_DEPTH-1:0];
reg [ TAG_WIDTH-1:0] btb_tag    [BTB_DEPTH-1:0];
reg [          31:0] btb_target [BTB_DEPTH-1:0];

assign tag_match  = btb_tag   [pc[0+:BTB_WIDTH]] == pc[BTB_WIDTH+:TAG_WIDTH]; 
assign tag_valid  = btb_valid [pc[0+:BTB_WIDTH]] & tag_match;

assign pc_taken   =  bht_counter[bht_pc_idx][1] & pc_vld & ~pc_freeze & tag_valid;
assign pc_n_taken = ~bht_counter[bht_pc_idx][1] & pc_vld & ~pc_freeze & tag_valid;

assign bp_taken   = pc_taken;

assign bp_pc      = (pc_return & ras_stack_spec[RAS_DEPTH-1][32]) ? 
                     ras_stack_spec[RAS_DEPTH-1][31:0] : btb_target[pc[0+:BTB_WIDTH]];

assign pc_call    = btb_call   [pc[0+:BTB_WIDTH]];
assign pc_return  = btb_return [pc[0+:BTB_WIDTH]];

always @(posedge CLK or negedge RSTN)
  begin : BTB_VALID
    if (~RSTN)
      for (i=0; i<BTB_DEPTH; i=i+1)
        btb_valid[i] <= 'd0;
    else if (alu_branch)
        btb_valid[alu_pc[0+:BTB_WIDTH]] <= 1'b1;
  end

always @(posedge CLK or negedge RSTN)
  begin : BTB_CALL
    if (~RSTN)
      for (i=0; i<BTB_DEPTH; i=i+1)
        btb_call[i] <= 'd0;
    else if (alu_branch)
        btb_call[alu_pc[0+:BTB_WIDTH]] <= alu_call;
  end

always @(posedge CLK or negedge RSTN)
  begin : BTB_RETURN
    if (~RSTN)
      for (i=0; i<BTB_DEPTH; i=i+1)
        btb_return[i] <= 'd0;
    else if (alu_branch)
        btb_return[alu_pc[0+:BTB_WIDTH]] <= alu_return;
  end

always @(posedge CLK or negedge RSTN)
  begin : BTB_TAG
    if (~RSTN)
      for (i=0; i<BTB_DEPTH; i=i+1)
        btb_tag[i] <= 'd0;
    else if (alu_branch)
        btb_tag[alu_pc[0+:BTB_WIDTH]] <= alu_pc[BTB_WIDTH+:TAG_WIDTH];
  end

always @(posedge CLK or negedge RSTN)
  begin : BTB_TARGET
    if (~RSTN)
      for (i=0; i<BTB_DEPTH; i=i+1)
        btb_target[i] <= 'd0;
    else if (alu_branch)
        btb_target[alu_pc[0+:BTB_WIDTH]] <= alu_target;
  end

endmodule