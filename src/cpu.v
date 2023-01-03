// RISCV32I CPU top module
// port modification allowed for debugging purposes

`include "def.v"

module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [7:0]          mem_din,		// data input bus
  output wire [7:0]          mem_dout,		// data output bus
  output wire [31:0]         mem_a,			// address bus (only 17:0 is used)
  output wire                mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

wire clear;

//mem - ins-cache
wire icache_mem_flag;
wire [`ADDR_LEN] icache_mem_pc;
wire mem_icache_flag;
wire reg [`INS_LEN] icache_mem_ins;

//ins-cache - fetch
wire fetch_icache_flag;
wire [`ADDR_LEN] fetch_pc;
wire icache_fetch_flag;
wire [`INS_LEN] fetch_ins;

//fetch - ins-queue
wire insq_full;
wire insq_push;
wire [`INS_LEN] insq_push_ins;
wire [`PC_LEN] insq_push_pc;
wire [`PC_LEN] insq_push_pred_pc;

//fetch - robuffer
wire jump;
wire [`PC_LEN] pc_jumpto;
wire pred_upd;
wire [`PC_LEN] pred_upd_pc;
wire pred_res;

//ins-queue - decode
wire insq_front;
wire [`INS_LEN] insq_front_ins;
wire [`PC_LEN] insq_front_pc;
wire [`PC_LEN] insq_front_pred_pc;

//decode - issue
wire decode_ok;
wire [`OP_LEN] decode_op;
wire [`REG_LEN] decode_rd;
wire [`IMM_LEN] decode_imm;
wire [`PC_LEN] decode_pc;
wire [`PC_LEN] decode_pred_pc;

//decode - regfile
wire rs1_query;
wire [`REG_LEN] rs1_pos;
wire rs2_query;
wire [`REG_LEN] rs2_pos;

//decode - rsstation
wire rs_full;
wire rs_getpos;

//decode - robuffer
wire rob_full;
wire rob_getpos;

//decode - lsbuffer
wire lsb_full;
wire lsb_getpos;

//regfile - robuffer
wire unlock;
wire [`REG_LEN] unlock_rd;
wire [`ROB_LEN] unlock_robpos;
wire [`DATA_LEN] unlock_val;

//regfile - issue
wire rs1_flag;
wire rs1_type;
wire [`DATA_LEN] rs1_val;
wire rs2_flag;
wire rs2_type;
wire [`DATA_LEN] rs2_val;

//issue - regfile
wire lock;

//issue - rsstation
wire rs_avail;
wire [`RS_LEN] rs_avail_pos;
wire rs_push;
wire [`RS_LEN] rs_push_pos;

wire [`OP_LEN] issue_op;
wire [`REG_LEN] issue_rd;
wire [`IMM_LEN] issue_imm;
wire [`PC_LEN] issue_pc;
wire [`PC_LEN] issue_pred_pc;
wire [`ROB_LEN] issue_robpos;
wire [`LSB_LEN] issue_lsbpos;
wire [`DATA_LEN] issue_vj;
wire issue_qj;
wire [`DATA_LEN] issue_vk;
wire issue_qk;

//issue - robuffer
wire rob_avail;
wire [`ROB_LEN] rob_avail_pos;
wire rob_push;
wire rs1_rob_flag;
wire [`DATA_LEN] rs1_rob_val;
wire rs2_rob_flag;
wire [`DATA_LEN] rs2_rob_val;
wire rs1_rob_ok;
wire [`ROB_LEN] rs1_robpos;
wire rs2_rob_ok;
wire [`ROB_LEN] rs2_robpos;

//issue - lsbuffer
wire lsb_avail;
wire [`LSB_LEN] lsb_avail_pos;
wire lsb_push;

//rsstation - alu
wire rs_ready;
wire [`RS_LEN] rs_ready_pos;
wire rs_front;
wire [`RS_LEN] rs_front_pos;
wire rs_front_ok;
wire [`OP_LEN] rs_front_op;
wire [`IMM_LEN] rs_front_imm;
wire [`ADDR_LEN] rs_front_pc;
wire [`ROB_LEN] rs_front_robpos;
wire [`DATA_LEN] rs_front_vj;
wire [`DATA_LEN] rs_front_vk;

//lsb load cdb
wire lsb_load_flag;
wire [`DATA_LEN] lsb_load_val;
wire [`ROB_LEN] lsb_load_robpos;

//alu cdb
wire alu_flag;
wire [`DATA_LEN] alu_val;
wire [`DATA_LEN] alu_jumpto;
wire [`ROB_LEN] alu_robpos;

//robuffer - lsbuffer
wire rob_store_flag;
wire [`LSB_LEN] rob_store_lsbpos;

//lsbuffer - mem
wire lsb_mem_flag;
wire lsb_mem_type;
wire [`ADDR_LEN] lsb_mem_pc;
wire [`MEM_LEN] lsb_mem_len;
wire [`DATA_LEN] lsb_mem_output;
wire mem_lsb_flag;
wire [`DATA_LEN] lsb_mem_input;


ins_cache Ins_Cache(
  .clk(clk_in),
  .reset(rst_in),
  .ready(rdy_in),
  .clear(clear),

  .fetch_in_flag(fetch_icache_flag),
  .fetch_pc(fetch_pc),
  .fetch_out_flag(icache_fetch_flag),
  .fetch_ins(fetch_ins),

  .mem_in_flag(mem_icache_flag),
  .mem_ins(icache_mem_ins),
  .mem_out_flag(icache_mem_flag),
  .mem_pc(icache_mem_pc)
);

fetch Fetch(
  .clk(clk_in),
  .reset(rst_in),
  .ready(rdy_in),

  .fetch_in_flag(icache_fetch_flag),
  .fetch_ins(fetch_ins),
  .fetch_out_flag(fetch_icache_flag),
  .fetch_pc(fetch_pc),

  .insq_full(insq_full),
  .push(insq_push),
  .push_ins(insq_push_ins),
  .push_pc(insq_push_pc),
  .push_pred_pc(insq_push_pred_pc),

  .jump(jump),
  .pc_jumpto(pc_jumpto),
  .pred_upd(pred_upd),
  .pred_upd_pc(pred_upd_pc),
  .pred_res(pred_res)
);

ins_queue Ins_Queue(
  .clk(clk_in),
  .reset(rst_in),
  .ready(rdy_in),
  .clear(clear),

  .push(insq_push),
  .push_ins(insq_push_ins),
  .push_pc(insq_push_pc),
  .push_pred_pc(insq_push_pred_pc),
  .full(insq_full),

  .decode_ok(decode_ok),
  .front(insq_front),
  .front_ins(insq_front_ins),
  .front_pc(insq_front_pc),
  .front_pred_pc(insq_front_pred_pc)
);

decode Decode(
  .decode_flag(insq_front),
  .ins(insq_front_ins),
  .ins_pc(insq_front_pc),
  .ins_pred_pc(insq_front_pred_pc),

  .decode_ok(decode_ok),
  .op(decode_op),
  .rd(decode_rd),
  .imm(decode_imm),
  .pc(decode_pc),
  .pred_pc(decode_pred_pc),

  .rs1_query(rs1_query),
  .rs1_pos(rs1_pos),
  .rs2_query(rs2_query),
  .rs2_pos(rs2_pos),

  .rob_full(rob_full),
  .rs_full(rs_full),
  .lsb_full(lsb_full),
  .rob_getpos(rob_getpos),
  .rs_getpos(rs_getpos),
  .lsb_getpos(lsb_getpos)
);

regfile RegFile(
  .clk(clk_in),
  .reset(rst_in),
  .ready(rdy_in),
  .clear(clear),

  .rs1_query(rs1_query),
  .rs1_pos(rs1_pos),
  .rs2_query(rs2_query),
  .rs2_pos(rs2_pos),

  .lock(lock),
  .lock_rd(issue_rd),
  .lock_robpos(issue_robpos),
  .unlock(unlock),
  .unlock_rd(unlock_rd),
  .unlock_robpos(unlock_robpos),
  .unlock_val(unlock_val),

  .rs1_flag(rs1_flag),
  .rs1_type(rs1_type),
  .rs1_val(rs1_val),
  .rs2_flag(rs2_flag),
  .rs2_type(rs2_type),
  .rs2_val(rs2_val)
);

issue Issue(
  .decode_flag(decode_ok),
  .op(decode_op),
  .rd(decode_rd),
  .imm(decode_imm),
  .pc(decode_pc),
  .pred_pc(decode_pred_pc),

  .rs1_flag(rs1_flag),
  .rs1_type(rs1_type),
  .rs1_val(rs1_val),
  .rs2_flag(rs2_flag),
  .rs2_type(rs2_type),
  .rs2_val(rs2_val),

  .rs_avail(rs_avail),
  .rs_avail_pos(rs_avail_pos),
  .rs_push(rs_push),
  .rs_push_pos(rs_push_pos),
  .rs_ready(rs_ready),
  .rs_ready_pos(rs_ready_pos),
  .rs_front(rs_front),
  .rs_front_pos(rs_front_pos),

  .issue_op(issue_op),
  .issue_rd(issue_rd),
  .issue_imm(issue_imm),
  .issue_pc(issue_pc),
  .issue_pred_pc(issue_pred_pc),
  .issue_robpos(issue_robpos),
  .issue_lsbpos(issue_lsbpos),
  .issue_vj(issue_vj),
  .issue_qj(issue_qj),
  .issue_vk(issue_vk),
  .issue_qk(issue_qk),

  .lock(lock),

  .rob_avail(rob_avail),
  .rob_avail_pos(rob_avail_pos),
  .rs1_rob_flag(rs1_rob_flag),
  .rs1_rob_val(rs1_rob_val),
  .rs2_rob_flag(rs2_rob_flag),
  .rs2_rob_val(rs2_rob_val),
  .rob_push(rob_push),
  .rs1_rob_ok(rs1_rob_ok),
  .rs1_robpos(rs1_robpos),
  .rs2_rob_ok(rs2_rob_ok),
  .rs2_robpos(rs2_robpos),

  .lsb_avail(lsb_avail),
  .lsb_avail_pos(lsb_avail_pos),
  .lsb_push(lsb_push)
);

rsstation Reservation_Station(
  .clk(clk_in),
  .reset(rst_in),
  .ready(rdy_in),
  .clear(clear),

  .getpos(rs_getpos),
  .rs_full(rs_full),
  .rs_avail(rs_avail),
  .rs_avail_pos(rs_avail_pos),
  .rs_ready(rs_ready),
  .rs_ready_pos(rs_ready_pos),

  .push(rs_push),
  .push_pos(rs_push_pos),
  .push_op(issue_op),
  .push_imm(issue_imm),
  .push_pc(issue_pc),
  .push_robpos(issue_robpos),
  .push_vj(issue_vj),
  .push_qj(issue_qj),
  .push_vk(issue_vk),
  .push_qk(issue_qk),

  .front(rs_front),
  .front_pos(rs_front_pos),
  .front_ok(rs_front_ok),
  .front_op(rs_front_op),
  .front_imm(rs_front_imm),
  .front_pc(rs_front_pc),
  .front_robpos(rs_front_robpos),
  .front_vj(rs_front_vj),
  .front_vk(rs_front_vk),

  .alu_in_flag(alu_flag),
  .alu_val(alu_val),
  .alu_robpos(alu_robpos),

  .lsb_in_flag(lsb_load_flag),
  .lsb_val(lsb_load_val),
  .lsb_robpos(lsb_load_robpos)
);

alu ALU(
  .clk(clk_in),
  .reset(rst_in),
  .ready(rdy_in),
  .clear(clear),

  .work(rs_front_ok),
  .op(rs_front_op),
  .imm(rs_front_imm),
  .pc(rs_front_pc),
  .robpos(rs_front_robpos),
  .rs1(rs_front_vj),
  .rs2(rs_front_vk),

  .alu_flag(alu_flag),
  .alu_val(alu_val),
  .alu_jumpto(alu_jumpto),
  .alu_robpos(alu_robpos)
);

robuffer Reorder_Buffer(
  .clk(clk_in),
  .reset(rst_in),
  .ready(rdy_in),
  .clear(clear),
  .rob_clear(clear),

  .getpos(rob_getpos),
  .rob_full(rob_full),
  .rob_avail(rob_avail),
  .rob_avail_pos(rob_avail_pos),

  .push(rob_push),
  .push_op(issue_op),
  .push_rd(issue_rd),
  .push_pc(issue_pc),
  .push_pred_pc(issue_pred_pc),
  .push_lsbpos(issue_lsbpos),

  .alu_flag(alu_flag),
  .alu_val(alu_val),
  .alu_jumpto(alu_jumpto),
  .alu_robpos(alu_robpos),

  .unlock(unlock),
  .unlock_rd(unlock_rd),
  .unlock_robpos(unlock_robpos),
  .unlock_val(unlock_val),

  .rs1_flag(rs1_rob_ok),
  .rs1_robpos(rs1_robpos),
  .rs2_flag(rs2_rob_ok),
  .rs2_robpos(rs2_robpos),
  .rs1_ok(rs1_rob_flag),
  .rs1_val(rs1_rob_val),
  .rs2_ok(rs2_rob_flag),
  .rs2_val(rs2_rob_val),

  .rob_store_flag(rob_store_flag),
  .rob_store_lsbpos(rob_store_lsbpos),
  .lsb_in_flag(lsb_load_flag),
  .lsb_val(lsb_load_val),
  .lsb_robpos(lsb_load_robpos),

  .jump(jump),
  .pc_jumpto(pc_jumpto),
  .pred_upd(pred_upd),
  .pred_upd_pc(pred_upd_pc),
  .pred_res(pred_res)
);

lsbuffer LoadStore_buffer(
  .clk(clk_in),
  .reset(rst_in),
  .ready(rdy_in),
  .clear(clear),

  .mem_in_flag(mem_lsb_flag),
  .mem_input(lsb_mem_input),
  .mem_out_flag(lsb_mem_flag),
  .mem_out_type(lsb_mem_type),
  .mem_pc(lsb_mem_pc),
  .mem_len(lsb_mem_len),
  .mem_output(lsb_mem_output),

  .getpos(lsb_getpos),
  .lsb_full(lsb_full),
  .lsb_avail(lsb_avail),
  .lsb_avail_pos(lsb_avail_pos),

  .push(lsb_push),
  .push_op(issue_op),
  .push_imm(issue_imm),
  .push_robpos(issue_robpos),
  .push_vj(issue_vj),
  .push_qj(issue_qj),
  .push_vk(issue_vk),
  .push_qk(issue_qk),

  .rob_store_flag(rob_store_flag),
  .rob_store_lsbpos(rob_store_lsbpos),

  .alu_flag(alu_flag),
  .alu_val(alu_val),
  .alu_robpos(alu_robpos),

  .load_flag(lsb_load_flag),
  .load_val(lsb_load_val),
  .load_robpos(lsb_load_robpos),

  .lsb_out_flag(lsb_load_flag),
  .lsb_out_val(lsb_load_val),
  .lsb_out_robpos(lsb_load_robpos)
);

memctrl Memctrl(
  .clk(clk_in),
  .reset(rst_in),
  .ready(rdy_in),
  .clear(clear),

  .mem_din(mem_din),
  .mem_dout(mem_dout),
  .mem_a(mem_a),
  .mem_wr(mem_wr),
  .io_buffer_full(io_buffer_full),

  .icache_mem_in_flag(icache_mem_flag),
  .icache_mem_pc(icache_mem_pc),
  .icache_mem_out_flag(mem_icache_flag),
  .icache_mem_ins(icache_mem_ins),

  .lsb_mem_in_flag(lsb_mem_flag),
  .lsb_mem_type(lsb_mem_type),
  .lsb_mem_pc(lsb_mem_pc),
  .lsb_mem_len(lsb_mem_len),
  .lsb_mem_output(lsb_mem_output),
  .lsb_mem_out_flag(mem_lsb_flag),
  .lsb_mem_input(lsb_mem_input)
);

endmodule