`include "instruction.v"

`define PC_LEN 31:0
`define INS_LEN 31:0
`define INT_LEN 31:0
`define IMM_LEN 31:0
`define OP_LEN 5:0
`define ADDR_LEN 31:0
`define DATA_LEN 31:0

`define CACHE_LEN 7:0
`define CACHE_ARR 255:0
`define CACHE_SIZ 9'b100000000
`define CACHE_TAG_POS 31:8
`define CACHE_TAG_LEN 23:0

`define INSQ_LEN 3:0
`define INSQ_ARR 15:0
`define INSQ_MAX 4'b1111

`define REG_LEN 4:0
`define REG_ARR 31:0
`define REG_SIZ 6'b100000

`define ROB_LEN 3:0
`define ROB_ARR 15:0
`define ROB_MAX 4'b1111

`define RS_LEN 3:0
`define RS_ARR 15:0
`define RS_SIZ 5'b10000

`define LSB_LEN 3:0
`define LSB_ARR 15:0
`define LSB_MAX 4'b1111
`define LSB_SIZ 5'b10000

`define MEM_LEN 1:0

`define PRED_LEN 9:0
`define PRED_ARR 1023:0
`define PRED_SIZ 11'b10000000000

`define IO_LIM 32'h30000

`define MINUS_ONE 32'b11111111111111111111111111111111;