`include "def.v"

module ins_cache (
    input wire clk,
    input wire reset,
    input wire ready,
    input wire clear,

    //read ins from memory
    input wire mem_in_flag,
    input wire [`INS_LEN] mem_ins,
    output reg mem_out_flag,
    output reg [`ADDR_LEN] mem_pc,

    //fetch ins
    input wire fetch_in_flag,
    input wire [`ADDR_LEN] fetch_pc,
    output reg fetch_out_flag,
    output reg [`INS_LEN] fetch_ins
);
    wire [`CACHE_LEN] now_pos = fetch_pc[`CACHE_LEN];
    wire [`CACHE_TAG_LEN] now_tag = fetch_pc[`CACHE_TAG_POS];
    reg [`INS_LEN] icache[`CACHE_ARR];
    reg [`CACHE_TAG_LEN] tag[`CACHE_ARR];
    reg busy[`CACHE_ARR];
    integer i;
    reg stall;

    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < `CACHE_SIZ; i = i + 1) begin
                icache[i] <= 0;
                tag[i] <= 0;
                busy[i] <= 0;
            end
            mem_out_flag <= 0;
            fetch_out_flag <= 0;
            stall <= 0;
        end
        else if (clear) begin
            mem_out_flag <= 0;
            fetch_out_flag <= 0;
            stall <= 0;
        end
        else if (ready) begin
            if (fetch_in_flag) begin
                if (stall) begin
                    mem_out_flag <= 0;
                    fetch_out_flag <= 0;
                    stall <= 0;
                end
                else if (busy[now_pos] && tag[now_pos] == now_tag) begin  //cache hit
                    fetch_out_flag <= 1;
                    fetch_ins <= icache[now_pos];
                    mem_out_flag <= 0;
                    stall <= 1;
                end
                else begin
                    if (mem_in_flag) begin
                        icache[now_pos] <= mem_ins;
                        tag[now_pos] <= now_tag;
                        busy[now_pos] <= 1;
                        fetch_out_flag <= 1;
                        fetch_ins <= mem_ins;
                        mem_out_flag <= 0;
                        stall <= 1;
                    end
                    else begin
                        mem_out_flag <= 1;
                        mem_pc <= fetch_pc;
                        fetch_out_flag <= 0;
                    end
                end
            end
            else begin
                fetch_out_flag <= 0;
                mem_out_flag <= 0;
            end
        end
    end

endmodule