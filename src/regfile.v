`include "def.v"

module regfile (
    input wire clk,
    input wire reset,
    input wire ready,
    input wire clear,

    //ID requests value of registers
    input wire rs1_query,
    input wire [`REG_LEN] rs1_pos,
    input wire rs2_query,
    input wire [`REG_LEN] rs2_pos,

    //lock regfile
    input wire lock,
    input wire [`REG_LEN] lock_rd,
    input wire [`ROB_LEN] lock_robpos,

    //unlock regfile from ROB commit
    input wire unlock,
    input wire [`REG_LEN] unlock_rd,
    input wire [`ROB_LEN] unlock_robpos,
    input wire [`DATA_LEN] unlock_val,

    //send value of registers to issue
    output reg rs1_flag,
    output reg rs1_type,
    output reg [`DATA_LEN] rs1_val,
    output reg rs2_flag,
    output reg rs2_type,
    output reg [`DATA_LEN] rs2_val
);

    reg [`DATA_LEN] val[`REG_ARR];
    reg [`ROB_LEN] qi[`REG_ARR];
    reg busy[`REG_ARR];
    integer i;

    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < `REG_SIZ; i = i + 1) begin
                val[i] <= 0;
                qi[i] <= 0;
                busy[i] <= 0;
            end
        end
        else if (clear) begin
            for (i = 0; i < `REG_SIZ; i = i + 1) begin
                qi[i] <= 0;
                busy[i] <= 0;
            end
            if (unlock && unlock_rd != 0) begin
                val[unlock_rd] <= unlock_val;
            end
        end
        else if (ready) begin
            if (lock && lock_rd != 0 && unlock && unlock_rd == lock_rd) begin
                val[unlock_rd] <= unlock_val;
                qi[lock_rd] <= lock_robpos;
                busy[lock_rd] <= 1;
            end
            else begin
                if (lock && lock_rd != 0) begin
                    qi[lock_rd] <= lock_robpos;
                    busy[lock_rd] <= 1;
                end
                if (unlock && unlock_rd != 0) begin
                    val[unlock_rd] <= unlock_val;  //!!!!!!!!!!!!!!
                    if (qi[unlock_rd] == unlock_robpos) begin
                        busy[unlock_rd] <= 0;
                    end
                end
            end
        end
    end

    always @(*) begin
        if (!rs1_query) begin
            rs1_flag <= 0;
            rs1_type <= 0;
            rs1_val <= 0;
        end
        else begin
            rs1_flag <= 1;
            if (!busy[rs1_pos]) begin
                rs1_type <= 0;
                rs1_val <= val[rs1_pos];
            end
            else begin
                if (unlock && unlock_robpos == qi[rs1_pos]) begin
                    rs1_type <= 0;
                    rs1_val <= unlock_val;
                end
                else begin
                    rs1_type <= 1;
                    rs1_val <= {{28'b0}, qi[rs1_pos]};
                end
            end 
        end
    end

    always @(*) begin
        if (!rs2_query) begin
            rs2_flag <= 0;
            rs2_type <= 0;
            rs2_val <= 0;
        end
        else begin
            rs2_flag <= 1;
            if (!busy[rs2_pos]) begin
                rs2_type <= 0;
                rs2_val <= val[rs2_pos];
            end
            else begin
                if (unlock && unlock_robpos == qi[rs2_pos]) begin
                    rs2_type <= 0;
                    rs2_val <= unlock_val;
                end
                else begin
                    rs2_type <= 1;
                    rs2_val <= {{28'b0}, qi[rs2_pos]};
                end
            end 
        end
    end

endmodule