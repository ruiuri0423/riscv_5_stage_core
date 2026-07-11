module ALUTop(
     output reg [31:0] alu_rs2_data
    ,output reg [31:0] alu_out
    ,output reg        alu_out_vld
    ,output reg [ 4:0] alu_rd
    ,output reg        alu_rd_wen
    ,output reg [ 3:0] alu_LS
    ,output reg        alu_branch // branch predict
    ,output reg        alu_call   // branch predict
    ,output reg        alu_return // branch predict
    ,output reg        alu_taken  // branch predict
    ,output reg        alu_flush  // branch predict
    ,output reg [31:0] alu_target // branch predict
    ,output reg [31:0] alu_pc     // branch predict
    ,output reg        alu_lsign
    // From LSU
    , input            lsu_ready
    // From decoder
    , input            dec_vld
    , input     [ 4:0] dec_rs1
    , input     [ 4:0] dec_rs2
    , input     [31:0] dec_rs1_data
    , input     [31:0] dec_rs2_data
    , input     [31:0] dec_imm
    , input            dec_rd_wen
    , input     [ 4:0] dec_rd
    , input     [ 3:0] dec_LS
    , input     [31:0] dec_pc
    , input            dec_auipc
    , input            dec_jal
    , input            dec_jalr
    , input            dec_branch
    , input            dec_taken
    , input            dec_lsign
    // From InstFetch
    , input     [31:0] inst_pc // for jalr prediction
    // ALU enable
    , input            is_ADD
    , input            is_SUB
    , input            is_AND
    , input            is_OR 
    , input            is_XOR
    , input            is_SLL
    , input            is_SRL
    , input            is_SRA
    , input            is_ASG
    , input            is_EQ 
    , input            is_NE 
    , input            is_LT 
    , input            is_LTU
    , input            is_GT 
    , input            is_GTU
    , input            rs2_sel
    //
    , input            CLK
    , input            RSTN
);

wire [31:0] alu_din1   =   dec_jal ?  dec_pc :
                          dec_jalr ?  dec_pc : 
                         dec_auipc ?  dec_pc : dec_rs1_data;  
                                                
wire [31:0] alu_din2   =   dec_jal ?     'd4 :
                          dec_jalr ?     'd4 : 
                         dec_auipc ? dec_imm :
                           rs2_sel ? dec_imm : dec_rs2_data;

wire        alu_freeze  = ~lsu_ready;
wire [31:0] alu_out_nxt = is_ADD ? ADD(alu_din1, alu_din2) :
                          is_SUB ? SUB(alu_din1, alu_din2) :
                          is_AND ? AND(alu_din1, alu_din2) :
                          is_OR  ? OR (alu_din1, alu_din2) :
                          is_XOR ? XOR(alu_din1, alu_din2) :
                          is_SLL ? SLL(alu_din1, alu_din2) :
                          is_SRL ? SRL(alu_din1, alu_din2) :
                          is_SRA ? SRA(alu_din1, alu_din2) :
                          is_ASG ? ASG(          alu_din2) :
                          is_EQ  ? EQ (alu_din1, alu_din2) :
                          is_NE  ? NE (alu_din1, alu_din2) :
                          is_LT  ? LT (alu_din1, alu_din2) :
                          is_LTU ? LTU(alu_din1, alu_din2) :
                          is_GT  ? GE (alu_din1, alu_din2) :
                          is_GTU ? GEU(alu_din1, alu_din2) : 'd0;

always @(posedge CLK or negedge RSTN) 
    begin
        if (~RSTN)
            alu_out <= 'd0;
        else if (alu_flush)
            alu_out <= 'd0;
        else if (~alu_freeze)
            alu_out <= alu_out_nxt;
    end

always @(posedge CLK or negedge RSTN)
    begin
        if (~RSTN)
            alu_out_vld <= 1'b0;
        else if (alu_flush)
            alu_out_vld <= 1'b0;
        else if (~alu_freeze)
            alu_out_vld <= dec_vld;
    end

always @(posedge CLK or negedge RSTN)
    begin
        if (~RSTN)
            begin
                alu_rs2_data <= 'd0;
                alu_rd_wen   <= 'd0;
                alu_rd       <= 'd0;
                alu_LS       <= 'd0;
                alu_lsign    <= 'd0;
            end
        else if (alu_flush)
            begin
                alu_rs2_data <= 'd0;
                alu_rd_wen   <= 'd0;
                alu_rd       <= 'd0;
                alu_LS       <= 'd0;
                alu_lsign    <= 'd0;
            end
        else if (~alu_freeze)
            begin
                alu_rs2_data <= dec_rs2_data;
                alu_rd_wen   <= dec_rd_wen;
                alu_rd       <= dec_rd;
                alu_LS       <= dec_LS;
                alu_lsign    <= dec_lsign;
            end
    end

always @(posedge CLK or negedge RSTN)
    begin
        if (~RSTN)
            begin
                alu_branch <= 'd0;
                alu_call   <= 'd0;
                alu_return <= 'd0;
                alu_taken  <= 'd0;
                alu_flush  <= 'd0;
                alu_target <= 'd0;
                alu_pc     <= 'd0;
            end
        else if (alu_flush)
            begin
                alu_branch <= 'd0;
                alu_call   <= 'd0;
                alu_return <= 'd0;
                alu_taken  <= 'd0;
                alu_flush  <= 'd0;
                alu_target <= 'd0;
                alu_pc     <= 'd0;
            end
        else if (~alu_freeze)
            begin
                alu_branch <= (dec_branch | dec_jal | dec_jalr);

                alu_call   <= ((( dec_rd == 4'd1) | ( dec_rd ==  4'd5)) & dec_jal ) |
                              /******************** JALR Case 1 ********************/
                              ((( dec_rd == 4'd1) | ( dec_rd ==  4'd5)) &
                               ((dec_rs1 != 4'd1) & (dec_rs1 !=  4'd5)) & dec_jalr) |
                              /******************** JALR Case 3 ********************/
                              ((( dec_rd == 4'd1) | ( dec_rd ==  4'd5)) &
                               ((dec_rs1 == 4'd1) | (dec_rs1 ==  4'd5)) &          
                               (                     dec_rs1 != dec_rd) & dec_jalr) |
                              /******************** JALR Case 4 ********************/
                              ((( dec_rd == 4'd1) | ( dec_rd ==  4'd5)) &
                               ((dec_rs1 == 4'd1) | (dec_rs1 ==  4'd5)) &          
                               (                     dec_rs1 == dec_rd) & dec_jalr) ;

                alu_return <=/******************** JALR Case 2 ********************/
                             ((( dec_rd != 4'd1) & ( dec_rd !=  4'd5)) &
                              ((dec_rs1 == 4'd1) | (dec_rs1 ==  4'd5)) & dec_jalr) |
                             /******************** JALR Case 3 ********************/
                             ((( dec_rd == 4'd1) | ( dec_rd ==  4'd5)) &
                              ((dec_rs1 == 4'd1) | (dec_rs1 ==  4'd5)) & 
                              (                     dec_rs1 != dec_rd) & dec_jalr);

                alu_taken  <= ((dec_branch & alu_out_nxt[0]) | dec_jal | dec_jalr);

                alu_flush  <= (((dec_branch & alu_out_nxt[0]) | dec_jal) ^ dec_taken) |
                              (((dec_pc + dec_rs1_data) != inst_pc) & dec_jalr) |
                              (((dec_pc +      dec_imm) != inst_pc) & dec_jal ) ;

                alu_target <=  dec_branch ? (dec_pc       + dec_imm) :
                                  dec_jal ? (dec_pc       + dec_imm) :
                                 dec_jalr ? (dec_rs1_data + dec_imm) : 'd0;

                alu_pc     <=  dec_branch ?  dec_pc :
                                  dec_jal ?  dec_pc :
                                 dec_jalr ?  dec_pc : 'd0;
            end
    end

endmodule