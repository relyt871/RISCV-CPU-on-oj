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

    //ROB jump
    input wire jump,
    input wire [`PC_LEN] pc_jumpto
);

    reg [`PC_LEN] pc;

    always @(posedge clk) begin
        if (reset) begin
            pc <= 0;
            fetch_out_flag <= 0;
            push <= 0;
        end
        else if (ready) begin
            if (jump) begin
                //$display("jump to %h", pc_jumpto);
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
                    pc <= pc + 4;
                    fetch_out_flag <= 0;
                    push <= 1;
                    push_ins <= fetch_ins;
                    push_pc <= pc;
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