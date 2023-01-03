`include "def.v"

module fetch (
    input wire clk,
    input wire reset,
    input wire ready,

    //fetch from ins_cache
    input wire fetch_in_flag,
    input wire [`INS_LEN] fetch_ins,
    output reg fetch_out_flag,
    output reg [`PC_LEN] fetch_pc,

    //fetch to ins_queue
    input wire insq_full,
    output reg push,
    output reg [`INS_LEN] push_ins,
    output reg [`PC_LEN] push_pc,
    output reg [`PC_LEN] push_pred_pc,

    //ROB jump
    input wire jump,
    input wire [`PC_LEN] pc_jumpto,
    input wire pred_upd,
    input wire [`PC_LEN] pred_upd_pc,
    input wire pred_res
);

    reg [`PC_LEN] pc;
    reg [1:0] predictor[`PRED_ARR];
    integer i;

    wire [`PRED_LEN] upd_pos = pred_upd_pc[`PRED_LEN];
    wire qry = predictor[pc[`PRED_LEN]][1];
    wire isbranch = (fetch_ins[6:0] == 7'b1100011);
    wire branch_imm = {{20{fetch_ins[31]}}, fetch_ins[7], fetch_ins[30:25], fetch_ins[11:8], {1'b0}};

    always @(*) begin
        if (pred_upd) begin
            case (predictor[upd_pos])
                2'b00: begin
                    predictor[upd_pos] <= (pred_res? 2'b01 : 2'b00);
                end
                2'b01: begin
                    predictor[upd_pos] <= (pred_res? 2'b10 : 2'b00);
                end
                2'b10: begin
                    predictor[upd_pos] <= (pred_res? 2'b11 : 2'b01);
                end
                2'b11: begin
                    predictor[upd_pos] <= (pred_res? 2'b11 : 2'b10);
                end
            endcase
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            pc <= 0;
            fetch_out_flag <= 0;
            push <= 0;
            for (i = 0; i < `PRED_SIZ; i = i + 1) begin
                predictor[i] = 2'b00;
            end
        end
        else if (ready) begin
            if (jump) begin
                pc <= pc_jumpto;
                fetch_out_flag <= 0;
                push <= 0;
            end
            else if (fetch_in_flag) begin
                if (insq_full) begin
                    fetch_out_flag <= 0;
                    push <= 0;
                end
                else begin
                    fetch_out_flag <= 0;
                    push <= 1;
                    push_ins <= fetch_ins;
                    push_pc <= pc;
                    if (isbranch && qry) begin
                        pc <= pc + branch_imm;
                        push_pred_pc <= pc + branch_imm;
                    end
                    else begin
                        pc <= pc + 4;
                        push_pred_pc <= pc + 4;
                    end
                end
            end
            else begin
                fetch_out_flag <= 1;
                fetch_pc <= pc;
                push <= 0;
            end
        end
    end
endmodule