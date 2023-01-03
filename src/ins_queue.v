`include "def.v"

module ins_queue (
    input wire clk,
    input wire reset,
    input wire ready,
    input wire clear,

    //push new ins
    input wire push,
    input wire [`INS_LEN] push_ins,
    input wire [`PC_LEN] push_pc,
    input wire [`PC_LEN] push_pred_pc,
    output reg full,  

    //pop front to decode
    input wire decode_ok,
    output reg front,
    output reg [`INS_LEN] front_ins,
    output reg [`PC_LEN] front_pc,
    output reg [`PC_LEN] front_pred_pc
);
    reg [`INSQ_LEN] head, tail;
    integer siz;
    reg [`INS_LEN] q_ins[`INSQ_ARR];
    reg [`PC_LEN] q_pc[`INSQ_ARR];
    reg [`PC_LEN] q_pred_pc[`INSQ_ARR];

    always @(posedge clk) begin
        if (reset || clear) begin
            head <= 0;
            tail <= 0;
            siz <= 0;
            front <= 0;
            full <= 0;
        end
        else if (ready) begin
            if (push) begin
                q_ins[tail] <= push_ins;
                q_pc[tail] <= push_pc;
                q_pred_pc[tail] <= push_pred_pc;
                tail <= ((tail == `INSQ_MAX)? 0 : tail + 1);
            end
            if (siz - decode_ok > 0) begin
                front <= 1;
                if (decode_ok) begin
                    front_ins <= q_ins[(head == `INSQ_MAX)? 0 : head + 1];
                    front_pc <= q_pc[(head == `INSQ_MAX)? 0 : head + 1];
                    front_pred_pc <= q_pred_pc[(head == `INSQ_MAX)? 0 : head + 1];
                    head <= ((head == `INSQ_MAX)? 0 : head + 1);
                end
                else begin
                    front_ins <= q_ins[head];
                    front_pc <= q_pc[head];
                    front_pred_pc <= q_pred_pc[head];
                end
            end
            else begin
                front <= 0;
                if (decode_ok) begin
                    head <= ((head == `INSQ_MAX)? 0 : head + 1);
                end
            end
            siz <= (siz - decode_ok + push);
            full <= (siz - decode_ok + push == `INSQ_MAX);
        end
    end
endmodule
