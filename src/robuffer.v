`include "def.v"

module robuffer (
    input wire clk,
    input wire reset,
    input wire ready,
    input wire clear,
    output reg rob_clear,

    //provide available pos to new ins
    input wire getpos,
    output reg rob_full,
    output reg rob_avail,
    output reg [`ROB_LEN] rob_avail_pos,

    //push new ins
    input wire push,
    input wire [`OP_LEN] push_op,
    input wire [`REG_LEN] push_rd,
    input wire [`PC_LEN] push_pc,
    input wire [`PC_LEN] push_pred_pc,
    input wire [`LSB_LEN] push_lsbpos,

    //input from ALU
    input wire alu_flag,
    input wire [`DATA_LEN] alu_val,
    input wire [`DATA_LEN] alu_jumpto,
    input wire [`ROB_LEN] alu_robpos,

    //commit to regfile
    output reg unlock,
    output reg [`REG_LEN] unlock_rd,
    output reg [`ROB_LEN] unlock_robpos,
    output reg [`DATA_LEN] unlock_val,

    //update ins rs when issue
    input wire rs1_flag,
    input wire [`ROB_LEN] rs1_robpos,
    input wire rs2_flag,
    input wire [`ROB_LEN] rs2_robpos,
    output reg rs1_ok,
    output reg [`DATA_LEN] rs1_val,
    output reg rs2_ok,
    output reg [`DATA_LEN] rs2_val,

    //commit to load-store-buffer
    output reg rob_store_flag,
    output reg [`ROB_LEN] rob_store_lsbpos,
    output wire [`ROB_LEN] rob_head,

    //input from lsb load
    input wire lsb_in_flag,
    input wire [`DATA_LEN] lsb_val,
    input wire [`ROB_LEN] lsb_robpos,

    //need to jump
    output reg jump,
    output reg [`PC_LEN] pc_jumpto,

    //predictor update
    output reg pred_upd,
    output reg [`PC_LEN] pred_upd_pc,
    output reg pred_res
);
    reg [`OP_LEN] rob_op[`ROB_ARR];
    reg [`REG_LEN] rob_rd[`ROB_ARR];
    reg [`PC_LEN] rob_pc[`ROB_ARR];
    reg [`PC_LEN] rob_pred_pc[`ROB_ARR];
    reg [`DATA_LEN] rob_val[`ROB_ARR];
    reg [`LSB_LEN] rob_lsbpos[`ROB_ARR];
    reg rob_isjump[`ROB_ARR];
    reg [`ADDR_LEN] rob_jumpto[`ROB_ARR];
    reg cancommit[`ROB_ARR];
    reg [`ROB_LEN] head, tail;
    integer i, siz;

    assign rob_head = head;

    //provide available pos to new ins
    always @(*) begin  
        if (getpos) begin
            rob_avail <= 1;
            rob_avail_pos <= tail;
        end
        else begin
            rob_avail <= 0;
            rob_avail_pos <= 0;
        end
    end

    always @(*) begin
        if (rs1_flag && cancommit[rs1_robpos]) begin
            rs1_ok <= 1;
            rs1_val <= rob_val[rs1_robpos];
        end
        else begin
            rs1_ok <= 0;
            rs1_val <= 0;
        end
    end

    always @(*) begin
        if (rs2_flag && cancommit[rs2_robpos]) begin
            rs2_ok <= 1;
            rs2_val <= rob_val[rs2_robpos];
        end
        else begin
            rs2_ok <= 0;
            rs2_val <= 0;
        end
    end

    always @(posedge clk) begin
        if (reset || clear) begin
            rob_clear <= 0;
            head <= 0;
            tail <= 0;
            siz <= 0;
            rob_full <= 0;
            unlock <= 0;
            rob_store_flag <= 0;
            jump <= 0;
        end
        else if (ready) begin
            if (push) begin   //push new ins
                rob_op[tail] <= push_op;
                rob_rd[tail] <= push_rd;
                rob_pc[tail] <= push_pc;
                rob_pred_pc[tail] <= push_pred_pc;
                rob_lsbpos[tail] <= push_lsbpos;
                cancommit[tail] <= (push_op == `SB || push_op == `SH || push_op == `SW);
                tail <= ((tail == `ROB_MAX)? 0 : tail + 1);
            end
            if (alu_flag) begin  //update by alu
                rob_val[alu_robpos] <= alu_val;
                rob_jumpto[alu_robpos] <= alu_jumpto;
                cancommit[alu_robpos] <= 1;
            end
            if (lsb_in_flag) begin  //update by lsb load
                rob_val[lsb_robpos] <= lsb_val;
                cancommit[lsb_robpos] <= 1;
            end
            if (head != tail && cancommit[head]) begin  //commit
//$display("%h", rob_pc[head]);
                case (rob_op[head])
                    `JAL, `JALR, `BEQ, `BNE, `BLT, `BGE, `BLTU, `BGEU: begin
                        if (rob_jumpto[head] != rob_pred_pc[head]) begin
                            rob_clear <= 1;
                            jump <= 1;
                            pc_jumpto <= rob_jumpto[head];
                        end
                        else begin
                            rob_clear <= 0;
                            jump <= 0;
                        end
                        if (rob_op[head] == `JAL || rob_op[head] == `JALR) begin
                            pred_upd <= 0;
                            unlock <= 1;
                            unlock_rd <= rob_rd[head];
                            unlock_robpos <= head;
                            unlock_val <= rob_val[head];
                        end 
                        else begin
                            unlock <= 0;
                            pred_upd <= 1;
                            pred_upd_pc <= rob_pc[head];
                            pred_res <= (rob_jumpto[head] != rob_pc[head] + 4);
                        end
                        rob_store_flag <= 0;
                    end
                    `SB, `SH, `SW: begin
                        rob_clear <= 0;
                        jump <= 0;
                        pred_upd <= 0;
                        unlock <= 0;
                        rob_store_flag <= 1;
                        rob_store_lsbpos <= rob_lsbpos[head];
                    end
                    default: begin
                        rob_clear <= 0;
                        jump <= 0;
                        pred_upd <= 0;
                        unlock <= 1;
                        unlock_rd <= rob_rd[head];
                        unlock_robpos <= head;
                        unlock_val <= rob_val[head];
                        rob_store_flag <= 0;
                    end
                endcase
                head <= ((head == `ROB_MAX)? 0 : head + 1);
            end
            else begin
                rob_clear <= 0;
                unlock <= 0;
                jump <= 0;
            end
            siz <= siz - (head != tail && cancommit[head]) + push;
            rob_full <= (siz - (head != tail && cancommit[head]) + push == `ROB_MAX);
        end
        else begin
            rob_clear <= 0;
            unlock <= 0;
            jump <= 0;
        end
    end
endmodule