`include "def.v"

module alu(
    input wire clk,
    input wire reset,
    input wire ready,
    input wire clear,

    input wire work,
    input wire[`OP_LEN] op,
    input wire[`IMM_LEN] imm,
    input wire[`PC_LEN] pc,
    input wire[`ROB_LEN] robpos,
    input wire[`INT_LEN] rs1,
    input wire[`INT_LEN] rs2,

    output reg alu_flag,
    output reg [`DATA_LEN] alu_val,
    output reg [`DATA_LEN] alu_jumpto,
    output reg [`ROB_LEN] alu_robpos
);
    
    always @(posedge clk) begin
        if (reset || clear) begin
            alu_flag <= 0;
        end
        else if (ready) begin
            if (work) begin
                alu_flag <= 1;
                alu_robpos <= robpos;
                case (op) 
                    `LUI: begin
                        alu_val <= imm;
                    end
                    `AUIPC: begin
                        alu_val <= pc + imm;
                    end
                    `JAL: begin
                        alu_val <= pc + 4;
                        alu_jumpto <= pc + imm;
                    end
                    `JALR: begin
                        alu_val <= pc + 4;
                        alu_jumpto <= (rs1 + imm) & `MINUS_ONE;
                    end
                    `BEQ: begin
                        if (rs1 == rs2) begin
                            alu_jumpto <= pc + imm;
                        end
                        else begin
                            alu_jumpto <= pc + 4;
                        end
                    end
                    `BNE: begin
                        if (rs1 != rs2) begin
                            alu_jumpto <= pc + imm;
                        end
                        else begin
                            alu_jumpto <= pc + 4;
                        end
                    end
                    `BLT: begin
                        if ($signed(rs1) < $signed(rs2)) begin
                            alu_jumpto <= pc + imm;
                        end
                        else begin
                            alu_jumpto <= pc + 4;
                        end
                    end
                    `BGE: begin
                        if ($signed(rs1) >= $signed(rs2)) begin
                            alu_jumpto <= pc + imm;
                        end
                        else begin
                            alu_jumpto <= pc + 4;
                        end
                    end
                    `BLTU: begin
                        if (rs1 < rs2) begin
                            alu_jumpto <= pc + imm;
                        end
                        else begin
                            alu_jumpto <= pc + 4;
                        end
                    end
                    `BGEU: begin
                        if (rs1 >= rs2) begin
                            alu_jumpto <= pc + imm;
                        end
                        else begin
                            alu_jumpto <= pc + 4;
                        end
                    end
                    `ADDI: begin
                        alu_val <= rs1 + imm;
                    end
                    `SLTI: begin
                        alu_val <= ($signed(rs1) < $signed(rs2));
                    end
                    `SLTIU: begin
                        alu_val <= (rs1 < imm);
                    end
                    `XORI: begin
                        alu_val <= rs1 ^ imm;
                    end
                    `ORI: begin
                        alu_val <= rs1 | imm;
                    end
                    `ANDI: begin
                        alu_val <= rs1 & imm;
                    end
                    `SLLI: begin
                        alu_val <= (rs1 << imm[5:0]);
                    end
                    `SRLI: begin
                        alu_val <= (rs1 >> imm[5:0]);
                    end
                    `SRAI: begin
                        alu_val <= ($signed(rs1) >> imm[5:0]);
                    end
                    `ADD: begin
                        alu_val <= rs1 + rs2;
                    end
                    `SUB: begin
                        alu_val <= rs1 - rs2;
                    end
                    `SLL: begin
                        alu_val <= (rs1 << rs2[5:0]);
                    end
                    `SLT: begin
                        alu_val <= ($signed(rs1) < $signed(rs2));
                    end
                    `SLTU: begin
                        alu_val <= (rs1 < rs2);
                    end
                    `XOR: begin
                        alu_val <= (rs1 ^ rs2);
                    end
                    `SRL: begin
                        alu_val <= (rs1 >> rs2[5:0]);
                    end
                    `SRA: begin
                        alu_val <= ($signed(rs1) >> rs2[5:0]);
                    end
                    `OR: begin
                        alu_val <= (rs1 | rs2);
                    end
                    `AND: begin
                        alu_val <= (rs1 & rs2);
                    end
                    default: begin
                        alu_flag <= 0;
                    end
                endcase
            end
            else begin
                alu_flag <= 0;
            end
        end
    end
endmodule