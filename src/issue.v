`include "def.v"

module issue (
    //input from decode
    input wire decode_flag,
    input wire [`OP_LEN] op,
    input wire [`REG_LEN] rd,
    input wire [`IMM_LEN] imm,
    input wire [`ADDR_LEN] pc,

    //get value from regfile
    input wire rs1_flag,
    input wire rs1_type,
    input wire [`DATA_LEN] rs1_val,
    input wire rs2_flag,
    input wire rs2_type,
    input wire [`DATA_LEN] rs2_val,

    //interact with reservation station
    input wire rs_avail,
    input wire [`RS_LEN] rs_avail_pos,
    output reg rs_push,
    output reg [`RS_LEN] rs_push_pos,

    input wire rs_ready,
    input wire [`RS_LEN] rs_ready_pos,
    output reg rs_front,
    output reg [`RS_LEN] rs_front_pos,

    //issue ins
    output reg [`OP_LEN] issue_op,
    output reg [`REG_LEN] issue_rd,
    output reg [`IMM_LEN] issue_imm,
    output reg [`PC_LEN] issue_pc,
    output reg [`ROB_LEN] issue_robpos,
    output reg [`LSB_LEN] issue_lsbpos,
    output reg [`DATA_LEN] issue_vj,
    output reg issue_qj,
    output reg [`DATA_LEN] issue_vk,
    output reg issue_qk,

    //lock corresponding regfile
    output reg lock,

    //interact with reorder buffer
    input wire rob_avail,
    input wire [`ROB_LEN] rob_avail_pos,
    input wire rs1_rob_flag,
    input wire [`DATA_LEN] rs1_rob_val,
    input wire rs2_rob_flag,
    input wire [`DATA_LEN] rs2_rob_val,
    output reg rob_push,
    output reg rs1_rob_ok,
    output reg [`ROB_LEN] rs1_robpos,
    output reg rs2_rob_ok,
    output reg [`ROB_LEN] rs2_robpos,

    //interact with loadstore buffer
    input wire lsb_avail,
    input wire [`LSB_LEN] lsb_avail_pos,
    output reg lsb_push
);
    wire[1:0] op_type = ((op == `LB || op == `LH || op == `LW || op == `LBU || op == `LHU)? 2'b01 : 
                         (op == `SB || op == `SH || op == `SW)? 2'b10 : 
                         (op == `BEQ ||op == `BNE || op == `BLT || op == `BGE || op == `BLTU || op == `BGEU)? 2'b11 : 2'b00);

    always @(*) begin
        if (decode_flag) begin
            issue_op <= op;
            issue_rd <= rd;
            issue_imm <= imm;
            issue_pc <= pc;
            issue_robpos <= rob_avail_pos;
            issue_lsbpos <= lsb_avail_pos;
            if (rs_avail && op_type == 2'b00 || op_type == 2'b11) begin
                rs_push <= 1;
                rs_push_pos <= rs_avail_pos;
            end
            else begin
                rs_push <= 0;
            end
            if (rob_avail) begin
                rob_push <= 1;
            end
            else begin
                rob_push <= 0;
            end
            if (op_type == 2'b00 || op_type == 2'b01) begin
                lock <= 1;
            end
            else begin
                lock <= 0;
            end
            if (lsb_avail && op_type == 2'b01 || op_type == 2'b10) begin
                lsb_push <= 1;
            end
            else begin
                lsb_push <= 0;
            end
        end
        else begin
            rs_push <= 0;
            rob_push <= 0;
            lock <= 0;
            lsb_push <= 0;
        end
    end

    always @(*) begin
        if (rs_ready) begin
            rs_front <= 1;
            rs_front_pos <= rs_ready_pos;
        end
        else begin
            rs_front <= 0;
        end
    end

    always @(*) begin
        if (decode_flag && rs1_flag) begin
            if (rs1_type == 0) begin
                issue_vj <= rs1_val;
                issue_qj <= 0;
                rs1_rob_ok <= 0;
            end
            else begin
                rs1_rob_ok <= 1;
                rs1_robpos <= rs1_val;
                if (rs1_rob_flag) begin
                    issue_vj <= rs1_rob_val;
                    issue_qj <= 0;
                end
                else begin
                    issue_vj <= rs1_val;
                    issue_qj <= 1;
                end
            end
        end
        else begin
            rs1_rob_ok <= 0;
            issue_vj <= 0;
            issue_qj <= 0;
        end
    end

    always @(*) begin
        if (decode_flag && rs2_flag) begin
            if (rs2_type == 0) begin
                issue_vk <= rs2_val;
                issue_qk <= 0;
                rs2_rob_ok <= 0;
            end
            else begin
                rs2_rob_ok <= 1;
                rs2_robpos <= rs2_val;
                if (rs2_rob_flag) begin
                    issue_vk <= rs2_rob_val;
                    issue_qk <= 0;
                end
                else begin
                    issue_vk <= rs2_val;
                    issue_qk <= 1;
                end
            end
        end
        else begin
            rs2_rob_ok <= 0;
            issue_vk <= 0;
            issue_qk <= 0;
        end
    end

endmodule