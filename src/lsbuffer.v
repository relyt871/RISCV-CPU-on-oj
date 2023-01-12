`include "def.v"

module lsbuffer (
    input wire clk,
    input wire reset,
    input wire ready,
    input wire clear,

    //interact with mem
    input wire mem_in_flag,
    input [`DATA_LEN] mem_input,
    output reg mem_out_flag,
    output reg mem_out_type,
    output reg [`ADDR_LEN] mem_pc,
    output reg [`MEM_LEN] mem_len,
    output reg [`DATA_LEN] mem_output,

    //provide pos to issue
    input wire getpos,
    output reg lsb_full,
    output reg lsb_avail,
    output reg [`LSB_LEN] lsb_avail_pos,

    //push new ins
    input wire push,
    input wire [`OP_LEN] push_op,
    input wire [`IMM_LEN] push_imm,
    input wire [`ROB_LEN] push_robpos,
    input wire [`DATA_LEN] push_vj,
    input wire push_qj,
    input wire [`DATA_LEN] push_vk,
    input wire push_qk,

    //update from ROB commit
    input wire rob_store_flag,
    input wire [`LSB_LEN] rob_store_lsbpos,
    input wire [`ROB_LEN] rob_head,

    //update from ALU
    input wire alu_flag,
    input wire [`DATA_LEN] alu_val,
    input wire [`ROB_LEN] alu_robpos,

    //update from load
    input wire load_flag,
    input wire [`DATA_LEN] load_val,
    input wire [`ROB_LEN] load_robpos,
    
    //output to ROB (load)
    output reg lsb_out_flag,
    output reg [`DATA_LEN] lsb_out_val,
    output reg [`ROB_LEN] lsb_out_robpos
);

    reg [`OP_LEN] lsb_op[`LSB_ARR];
    reg [`IMM_LEN] lsb_imm[`LSB_ARR];
    reg [`ROB_LEN] lsb_robpos[`LSB_ARR];
    reg [`DATA_LEN] lsb_vj[`LSB_ARR];
    reg lsb_qj[`LSB_ARR];
    reg [`DATA_LEN] lsb_vk[`LSB_ARR];
    reg lsb_qk[`LSB_ARR];
    reg cancommit[`LSB_ARR], del[`LSB_ARR];
    reg [`LSB_LEN] head, tail;
    integer i;
    integer siz;

    always @(*) begin
        if (getpos) begin
            lsb_avail <= 1;
            lsb_avail_pos <= tail;
        end
        else begin
            lsb_avail <= 0;
            lsb_avail_pos <= 0;
        end
    end
    
    always @(posedge clk) begin
        if (reset) begin
            head <= 0;
            tail <= 0;
            siz <= 0;
            lsb_full <= 0;
            mem_out_flag <= 0;
            lsb_out_flag <= 0;
        end
        else if (clear) begin
            for (i = 0; i < `LSB_SIZ; i = i + 1) begin  //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                if (!cancommit[i]) begin
                    del[i] <= 1;
                end
            end
            if (siz && cancommit[head] && mem_in_flag) begin
                head <= ((head == `LSB_MAX)? 0 : head + 1);
                siz <= siz - 1;
                lsb_full <= (siz - 1 == `LSB_MAX);
            end
            else begin
                lsb_full <= (siz == `LSB_MAX);
            end
            mem_out_flag <= 0;
            lsb_out_flag <= 0;
        end
        else if (ready) begin
            if (rob_store_flag) begin
                cancommit[rob_store_lsbpos] <= 1;
            end
            if (alu_flag) begin
                for (i = 0; i < `LSB_SIZ; i = i + 1) begin
                    if (lsb_qj[i] && lsb_vj[i][`ROB_LEN] == alu_robpos) begin
                        lsb_vj[i] <= alu_val;
                        lsb_qj[i] <= 0;
                    end
                    if (lsb_qk[i] && lsb_vk[i][`ROB_LEN] == alu_robpos) begin
                        lsb_vk[i] <= alu_val;
                        lsb_qk[i] <= 0;
                    end
                end
            end
            if (load_flag) begin
                for (i = 0; i < `LSB_SIZ; i = i + 1) begin
                    if (lsb_qj[i] && lsb_vj[i][`ROB_LEN] == load_robpos) begin
                        lsb_vj[i] <= load_val;
                        lsb_qj[i] <= 0;
                    end
                    if (lsb_qk[i] && lsb_vk[i][`ROB_LEN] == load_robpos) begin
                        lsb_vk[i] <= load_val;
                        lsb_qk[i] <= 0;
                    end
                end
            end

            if (push) begin
                lsb_op[tail] <= push_op;
                lsb_imm[tail] <= push_imm;
                lsb_robpos[tail] <= push_robpos;
                cancommit[tail] <= 0;
                del[tail] <= 0;
                if (!push_qj) begin
                    lsb_vj[tail] <= push_vj;
                    lsb_qj[tail] <= 0;
                end
                else begin //current update may affect push
                    if (alu_flag && push_vj[`ROB_LEN] == alu_robpos) begin
                        lsb_vj[tail] <= alu_val;
                        lsb_qj[tail] <= 0;
                    end
                    else if (load_flag && push_vj[`ROB_LEN] == load_robpos) begin
                        lsb_vj[tail] <= load_val;
                        lsb_qj[tail] <= 0;
                    end
                    else begin
                        lsb_vj[tail] <= push_vj;
                        lsb_qj[tail] <= 1;
                    end
                end
                if (!push_qk) begin
                    lsb_vk[tail] <= push_vk;
                    lsb_qk[tail] <= 0;
                end
                else begin
                    if (alu_flag && push_vk[`ROB_LEN] == alu_robpos) begin
                        lsb_vk[tail] <= alu_val;
                        lsb_qk[tail] <= 0;
                    end
                    else if (load_flag && push_vk[`ROB_LEN] == load_robpos) begin
                        lsb_vk[tail] <= load_val;
                        lsb_qk[tail] <= 0;
                    end
                    else begin
                        lsb_vk[tail] <= push_vk;
                        lsb_qk[tail] <= 1;
                    end
                end
                tail <= ((tail == `LSB_MAX)? 0 : tail + 1);
            end

            if (head != tail && del[head]) begin
                mem_out_flag <= 0;
                lsb_out_flag <= 0;
                head <= ((head == `LSB_MAX)? 0 : head + 1);
                siz <= siz + push - 1;
                lsb_full <= (siz + push - 1 == `LSB_MAX);
            end
            else if (head != tail && !lsb_qj[head] && !lsb_qk[head]) begin
                case (lsb_op[head])
                    `LB, `LH, `LW, `LBU, `LHU: begin
                        if (lsb_vj[head] + lsb_imm[head] >= `IO_LIM && lsb_robpos[head] != rob_head) begin  //input corner case
                            mem_out_flag <= 0;
                            lsb_out_flag <= 0;
                            siz <= siz + push;
                            lsb_full <= (siz + push == `LSB_MAX);
                        end
                        else if (mem_in_flag) begin
                            mem_out_flag <= 0;
                            head <= ((head == `LSB_MAX)? 0 : head + 1);
                            siz <= siz + push - 1;
                            lsb_full <= (siz + push - 1 == `LSB_MAX);
                            lsb_out_flag <= 1;
                            lsb_out_robpos <= lsb_robpos[head];
                            case (lsb_op[head])
                                `LB: begin
                                    lsb_out_val <= {{24{mem_input[7]}}, mem_input[7:0]};
                                end
                                `LH: begin
                                    lsb_out_val <= {{16{mem_input[15]}}, mem_input[15:0]};
                                end
                                `LW: begin
                                    lsb_out_val <= mem_input;
                                end
                                `LBU: begin
                                    lsb_out_val <= {{24{1'b0}}, mem_input[7:0]};
                                end
                                `LHU: begin
                                    lsb_out_val <= {{16{1'b0}}, mem_input[15:0]};
                                end
                            endcase
                        end
                        else begin
                            mem_out_flag <= 1;
                            mem_out_type <= 0;
                            mem_pc <= lsb_vj[head] + lsb_imm[head];
                            case (lsb_op[head])
                                `LB, `LBU: begin
                                    mem_len <= 2'b00;
                                end
                                `LH, `LHU: begin
                                    mem_len <= 2'b01;
                                end
                                `LW: begin
                                    mem_len <= 2'b11;
                                end
                            endcase
                            siz <= siz + push;
                            lsb_full <= (siz + push == `LSB_MAX);
                            lsb_out_flag <= 0;
                        end
                    end
                    `SB, `SH, `SW: begin
                        lsb_out_flag <= 0;
                        if (cancommit[head]) begin
                            if (mem_in_flag) begin
                                mem_out_flag <= 0;
                                head <= ((head == `LSB_MAX)? 0 : head + 1);
                                siz <= siz + push - 1;
                                lsb_full <= (siz + push - 1 == `LSB_MAX);
                            end
                            else begin
                                mem_out_flag <= 1;
                                mem_out_type <= 1;
                                mem_pc <= lsb_vj[head] + lsb_imm[head];
                                case (lsb_op[head])
                                    `SB: begin
                                        mem_len <= 2'b00;
                                    end
                                    `SH: begin
                                        mem_len <= 2'b01;
                                    end
                                    `SW: begin
                                        mem_len <= 2'b11;
                                    end
                                endcase
                                mem_output <= lsb_vk[head];
                                siz <= siz + push;
                                lsb_full <= (siz + push == `LSB_MAX);
                            end
                        end
                        else begin
                            mem_out_flag <= 0;
                            siz <= siz + push;
                            lsb_full <= (siz + push == `LSB_MAX);
                        end
                    end
                endcase
            end
            else begin
                mem_out_flag <= 0;
                lsb_out_flag <= 0;
                siz <= siz + push;
                lsb_full <= (siz + push == `LSB_MAX);
            end
        end
    end
endmodule