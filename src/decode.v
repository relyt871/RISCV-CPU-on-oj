`include "def.v"

module decode (
    input wire decode_flag,
    input wire [`INS_LEN] ins,
    input wire [`PC_LEN] ins_pc,
    input wire [`PC_LEN] ins_pred_pc,

    //send decoded info to issue
    output reg decode_ok,
    output reg [`OP_LEN] op,
    output reg [`REG_LEN] rd,
    output reg [`IMM_LEN] imm,
    output reg [`PC_LEN] pc,
    output reg [`PC_LEN] pred_pc,

    //request value from regfile
    output reg rs1_query,
    output reg [`REG_LEN] rs1_pos,
    output reg rs2_query,
    output reg [`REG_LEN] rs2_pos,

    //rob and station must be available
    input wire rob_full,
    input wire rs_full,
    input wire lsb_full,
    output reg rob_getpos,
    output reg rs_getpos,
    output reg lsb_getpos
);
    wire [6:0] opcode;
    wire [2:0] func3;
    assign opcode = ins[6:0];
    assign func3 = ins[14:12];
    
    always @(*) begin
        if (!decode_flag || rob_full || rs_full || lsb_full) begin
            decode_ok <= 0;
            rs1_query <= 0;
            rs2_query <= 0;
            rob_getpos <= 0;
            rs_getpos <= 0;
            lsb_getpos <= 0;
        end 
        else begin
            decode_ok <= 1;
            rob_getpos <= 1;
            rs_getpos <= 1;
            lsb_getpos <= 1;
            rd <= ins[11:7];
            rs1_pos <= ins[19:15];
            rs2_pos <= ins[24:20];
            pc <= ins_pc;
            pred_pc <= ins_pred_pc;
            case (opcode)
                7'b0110111: begin   //37
                    op <= `LUI;
                    imm <= {ins[31:12], {12'b0}};
                    rs1_query <= 0;
                    rs2_query <= 0;
                end
                7'b0010111: begin   //17
                    op <= `AUIPC;
                    imm <= {ins[31:12], {12'b0}};
                    rs1_query <= 0;
                    rs2_query <= 0;
                end
                7'b1101111: begin   //6f
                    op <= `JAL;
                    imm <= {{13{ins[31]}}, ins[19:12], ins[20], ins[30:21], {1'b0}};
                    rs1_query <= 0;
                    rs2_query <= 0;
                end
                7'b1100111: begin   //67
                    op <= `JALR;
                    imm <= {{20{ins[31]}}, ins[31:20]};
                    rs1_query <= 1;
                    rs2_query <= 0;
                end
                7'b1100011: begin   //63
                    case (func3)
                        3'b000: op <= `BEQ;
                        3'b001: op <= `BNE;
                        3'b100: op <= `BLT;
                        3'b101: op <= `BGE;
                        3'b110: op <= `BLTU;
                        3'b111: op <= `BGEU;
                        default: op <= `WOW;
                    endcase
                    imm <= {{20{ins[31]}}, ins[7], ins[30:25], ins[11:8], {1'b0}};
                    rs1_query <= 1;
                    rs2_query <= 1;
                end
                7'b0000011: begin   //03
                    case (func3)
                        3'b000: op <= `LB;
                        3'b001: op <= `LH;
                        3'b010: op <= `LW;
                        3'b011: op <= `LD;
                        3'b100: op <= `LBU;
                        3'b101: op <= `LHU;
                        default: op <= `WOW;
                    endcase
                    imm <= {{20{ins[31]}}, ins[31:20]};
                    rs1_query <= 1;
                    rs2_query <= 0;
                end
                7'b0100011: begin   //23
                    case (func3)
                        3'b000: op <= `SB;
                        3'b001: op <= `SH;
                        3'b010: op <= `SW;
                        3'b011: op <= `SD;
                    endcase
                    imm <= {{20{ins[31]}}, ins[31:25], ins[11:7]};
                    rs1_query <= 1;
                    rs2_query <= 1;
                end
                7'b0010011: begin   //13
                    case (func3)
                        3'b000: op <= `ADDI;
                        3'b001: op <= `SLLI;
                        3'b010: op <= `SLTI;
                        3'b011: op <= `SLTIU;
                        3'b100: op <= `XORI;
                        3'b101: op <= (ins[30]? `SRAI : `SRLI);
                        3'b110: op <= `ORI;
                        3'b111: op <= `ANDI;
                    endcase
                    imm <= {{20{ins[31]}}, ins[31:20]};
                    rs1_query <= 1;
                    rs2_query <= 0;
                end
                7'b0110011: begin   //33
                    case (func3) 
                        3'b000: op <= (ins[30]? `SUB : `ADD);
                        3'b001: op <= `SLL;
                        3'b010: op <= `SLT;
                        3'b011: op <= `SLTU;
                        3'b100: op <= `XOR;
                        3'b101: op <= (ins[30]? `SRA : `SRL);
                        3'b110: op <= `OR;
                        3'b111: op <= `AND;
                    endcase
                    rs1_query <= 1;
                    rs2_query <= 1;
                end
                default: begin
                    op <= `WOW;
                end
            endcase
        end
    end
endmodule
