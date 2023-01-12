`include "def.v"

module rsstation (
    input wire clk,
    input wire reset,
    input wire ready,
    input wire clear,

    //1) find ins ready to execute 2) provide available pos
    input wire getpos,
    output reg rs_full,
    output reg rs_avail,
    output reg [`RS_LEN] rs_avail_pos,
    output reg rs_ready,
    output reg [`RS_LEN] rs_ready_pos,

    //input an instruction, here only robpos is sufficient, rd is in ROB
    input wire push,
    input wire [`RS_LEN] push_pos,
    input wire [`OP_LEN] push_op,
    input wire [`IMM_LEN] push_imm,
    input wire [`ADDR_LEN] push_pc,
    input wire [`ROB_LEN] push_robpos,
    input wire [`DATA_LEN] push_vj,
    input wire push_qj,
    input wire [`DATA_LEN] push_vk,
    input wire push_qk,

    //send an instruction to ALU
    input wire front,
    input wire [`RS_LEN] front_pos,
    output reg front_ok,
    output reg [`OP_LEN] front_op,
    output reg [`IMM_LEN] front_imm,
    output reg [`ADDR_LEN] front_pc,
    output reg [`ROB_LEN] front_robpos,
    output reg [`DATA_LEN] front_vj,
    output reg [`DATA_LEN] front_vk,

    //update from alu
    input alu_in_flag,
    input wire [`DATA_LEN] alu_val,
    input wire [`ROB_LEN] alu_robpos,

    //update from lsb
    input lsb_in_flag,
    input wire [`DATA_LEN] lsb_val,
    input wire [`ROB_LEN] lsb_robpos
);
    reg [`OP_LEN] rs_op[`RS_ARR];
    reg [`IMM_LEN] rs_imm[`RS_ARR];
    reg [`ADDR_LEN] rs_pc[`RS_ARR];
    reg [`ROB_LEN] rs_robpos[`RS_ARR];
    reg [`DATA_LEN] rs_vj[`RS_ARR];
    reg rs_qj[`RS_ARR];
    reg [`DATA_LEN] rs_vk[`RS_ARR];
    reg rs_qk[`RS_ARR];
    reg busy[`RS_ARR];
    integer siz;

    integer i;
    always @(*) begin
        if (reset || clear || !getpos) begin
            rs_avail <= 0;
            rs_avail_pos <= 0;
        end
        else begin
            rs_avail <= 0;
            rs_avail_pos <= 0;
            for (i = 0; i < `RS_SIZ; i = i + 1) begin
                if (!busy[i]) begin
                    rs_avail <= 1;
                    rs_avail_pos <= i;
                end
            end
        end
    end

    integer j;
    always @(*) begin
        if (reset || clear) begin
            rs_ready <= 0;
            rs_ready_pos <= 0;
        end
        else begin
            rs_ready <= 0;
            rs_ready_pos <= 0;
            for (j = 0; j < `RS_SIZ; j = j + 1) begin
                if (busy[j]) begin
                    if (!rs_qj[j] && !rs_qk[j]) begin
                        rs_ready <= 1;
                        rs_ready_pos <= j;
                    end
                end
            end
        end 
    end

    integer k;
    always @(posedge clk) begin
        if (reset || clear) begin
            for (k = 0; k < `RS_SIZ; k = k + 1) begin
                busy[k] <= 0;
            end
            front_ok <= 0;
            siz <= 0;
            rs_full <= 0;
            front_ok <= 0;
        end
        else if (ready) begin
            //update values in the station
            if (alu_in_flag) begin
                for (k = 0; k < `RS_SIZ; k = k + 1) begin
                    if (busy[k]) begin
                        if (rs_qj[k] && rs_vj[k][`ROB_LEN] == alu_robpos) begin
                            rs_vj[k] <= alu_val;
                            rs_qj[k] <= 0;
                        end
                        if (rs_qk[k] && rs_vk[k][`ROB_LEN] == alu_robpos) begin
                            rs_vk[k] <= alu_val;
                            rs_qk[k] <= 0;
                        end
                    end
                end
            end
            if (lsb_in_flag) begin
                for (k = 0; k < `RS_SIZ; k = k + 1) begin
                    if (busy[k]) begin
                        if (rs_qj[k] && rs_vj[k][`ROB_LEN] == lsb_robpos) begin
                            rs_vj[k] <= lsb_val;
                            rs_qj[k] <= 0;
                        end
                        if (rs_qk[k] && rs_vk[k][`ROB_LEN] == lsb_robpos) begin
                            rs_vk[k] <= lsb_val;
                            rs_qk[k] <= 0;
                        end
                    end
                end
            end
            //push and front
            siz <= (siz + push - front);
            rs_full <= (siz + push - front == `RS_SIZ); 
            if (push) begin
                rs_op[push_pos] <= push_op;
                rs_imm[push_pos] <= push_imm;
                rs_pc[push_pos] <= push_pc;
                rs_robpos[push_pos] <= push_robpos;
                if (!push_qj) begin
                    rs_vj[push_pos] <= push_vj;
                    rs_qj[push_pos] <= 0;
                end
                else begin //current update may affect push
                    if (alu_in_flag && push_vj[`ROB_LEN] == alu_robpos) begin
                        rs_vj[push_pos] <= alu_val;
                        rs_qj[push_pos] <= 0;
                    end
                    else if (lsb_in_flag && push_vj[`ROB_LEN] == lsb_robpos) begin
                        rs_vj[push_pos] <= lsb_val;
                        rs_qj[push_pos] <= 0;
                    end
                    else begin
                        rs_vj[push_pos] <= push_vj;
                        rs_qj[push_pos] <= 1;
                    end
                end
                if (!push_qk) begin
                    rs_vk[push_pos] <= push_vk;
                    rs_qk[push_pos] <= 0;
                end
                else begin
                    if (alu_in_flag && push_vk[`ROB_LEN] == alu_robpos) begin
                        rs_vk[push_pos] <= alu_val;
                        rs_qk[push_pos] <= 0;
                    end
                    else if (lsb_in_flag && push_vk[`ROB_LEN] == lsb_robpos) begin
                        rs_vk[push_pos] <= lsb_val;
                        rs_qk[push_pos] <= 0;
                    end
                    else begin
                        rs_vk[push_pos] <= push_vk;
                        rs_qk[push_pos] <= 1;
                    end
                end
                busy[push_pos] <= 1;
            end
            if (front) begin
                front_ok <= 1;
                front_op <= rs_op[front_pos];
                front_imm <= rs_imm[front_pos];
                front_pc <= rs_pc[front_pos];
                front_robpos <= rs_robpos[front_pos];
                front_vj <= rs_vj[front_pos];
                front_vk <= rs_vk[front_pos];
                busy[front_pos] <= 0;
            end
            else begin
                front_ok <= 0;
            end
        end
    end
endmodule