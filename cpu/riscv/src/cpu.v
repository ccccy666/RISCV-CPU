// RISCV32I CPU top module
// port modification allowed for debugging purposes
`include "constant.v"
`include "memctrl.v"
`include "ifetch.v"
`include "decoder.v"
`include "registers.v"
`include "rs.v"
`include "lsb.v"
`include "alu.v"
`include "rob.v"
`include "predictor.v"

module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
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
// Reorder Buffer rollback signal
wire rollback;
wire rs_nxt_full;
wire lsb_nxt_full;
wire rob_nxt_full;

wire alu_result;
wire [3:0] alu_result_rob_pos;
wire [31:0] alu_result_val;
wire [31:0] alu_result_pc;
wire alu_result_jump;

wire lsb_result;
wire [3:0] lsb_result_rob_pos;
wire [31:0] lsb_result_val;

wire if_to_mc_en;
wire [31:0] if_to_mc_pc;
wire mc_to_if_done;
wire [511:0] mc_to_if_data;
////////////
wire [31:0] if_to_pred_inst;
wire if_to_pred_flag;
wire [31:0] if_to_pred_pc;
wire [31:0] pred_to_if_pc;
wire pred_to_if_jump;

wire lsb_to_mc_en;
wire lsb_to_mc_wr;
wire [31:0] lsb_to_mc_addr;
wire [2:0] lsb_to_mc_len;
wire [31:0] lsb_to_mc_w_data;
wire mc_to_lsb_done;
wire [31:0] mc_to_lsb_r_data;

wire rob_to_if_set_pc_en;
wire [31:0] rob_to_if_set_pc;
wire rob_to_if_br;
wire rob_to_if_br_jump;
wire [31:0] rob_to_if_br_pc;

wire if_to_dec_inst_rdy;
wire [31:0] if_to_dec_inst;
wire [31:0] if_to_dec_inst_pc;
wire if_to_dec_inst_pred_jump;

wire issue;
wire [3:0] issue_rob_pos;
wire [6:0] issue_opcode;
wire issue_is_store;
wire [2:0] issue_funct3;
wire issue_funct7;
wire [31:0] issue_rs1_val;
wire [4:0] issue_rs1_rob_id;
wire [31:0] issue_rs2_val;
wire [4:0] issue_rs2_rob_id;
wire [31:0] issue_imm;
wire [4:0] issue_rd;
wire [31:0] issue_pc;
wire issue_pred_jump;
wire issue_is_ready;

wire [4:0] dec_ask_reg_rs1;
wire [31:0] dec_ask_reg_rs1_val;
wire [4:0] dec_ask_reg_rs1_rob_id;
wire [4:0] dec_ask_reg_rs2;
wire [31:0] dec_ask_reg_rs2_val;
wire [4:0] dec_ask_reg_rs2_rob_id;

wire [3:0] dec_ask_rob_rs1_pos;
wire dec_ask_rob_rs1_ready;
wire [31:0] dec_ask_rob_rs1_val;
wire [3:0] dec_ask_rob_rs2_pos;
wire dec_ask_rob_rs2_ready;
wire [31:0] dec_ask_rob_rs2_val;

wire dec_to_rs_en;

wire dec_to_lsb_en;

wire [3:0] nxt_rob_pos;

wire [3:0] rob_commit_pos;

wire rob_to_reg_write;
wire [4:0] rob_to_reg_rd;
wire [31:0] rob_to_reg_val;

wire rob_to_lsb_commit_store;

wire [3:0] rob_head_pos;

wire rs_to_alu_en;
wire [6:0] rs_to_alu_opcode;
wire [2:0] rs_to_alu_funct3;
wire rs_to_alu_funct7;
wire [31:0] rs_to_alu_val1;
wire [31:0] rs_to_alu_val2;
wire [31:0] rs_to_alu_imm;
wire [31:0] rs_to_alu_pc;
wire [3:0] rs_to_alu_rob_pos;

Register Registers (
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .rollback(rollback),
  .rs1(dec_ask_reg_rs1),
  .val1(dec_ask_reg_rs1_val),
  .rob_id1(dec_ask_reg_rs1_rob_id),
  .rs2(dec_ask_reg_rs2),
  .val2(dec_ask_reg_rs2_val),
  .rob_id2(dec_ask_reg_rs2_rob_id),
  .issue(issue),
  .issue_rd(issue_rd),
  .issue_rob_pos(issue_rob_pos),
  .commit(rob_to_reg_write),
  .commit_rd(rob_to_reg_rd),
  .commit_val(rob_to_reg_val),
  .commit_rob_pos(rob_commit_pos)
);

MemCtrl MemCtrl_ (
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .rollback(rollback),
  .mem_din(mem_din),
  .mem_dout(mem_dout),
  .mem_a(mem_a),
  .mem_wr(mem_wr),
  .io_buffer_full(io_buffer_full),
  .if_en(if_to_mc_en),
  .if_pc(if_to_mc_pc),
  .if_done(mc_to_if_done),
  .if_data(mc_to_if_data),
  .lsb_en(lsb_to_mc_en),
  .lsb_wr(lsb_to_mc_wr),
  .lsb_addr(lsb_to_mc_addr),
  .lsb_len(lsb_to_mc_len),
  .lsb_w_data(lsb_to_mc_w_data),
  .lsb_done(mc_to_lsb_done),
  .lsb_r_data(mc_to_lsb_r_data)
);

IFetch IFetch_ (
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .rs_nxt_full(rs_nxt_full),
  .lsb_nxt_full(lsb_nxt_full),
  .rob_nxt_full(rob_nxt_full),
  .inst_rdy(if_to_dec_inst_rdy),
  .inst(if_to_dec_inst),
  .inst_pc(if_to_dec_inst_pc),
  .inst_pred_jump(if_to_dec_inst_pred_jump),
  .mc_en(if_to_mc_en),
  .mc_pc(if_to_mc_pc),
  .mc_done(mc_to_if_done),
  .mc_data(mc_to_if_data),
  .rob_set_pc_en(rob_to_if_set_pc_en),
  .rob_set_pc(rob_to_if_set_pc),
  .rob_br(rob_to_if_br),
  .rob_br_jump(rob_to_if_br_jump),
  .rob_br_pc(rob_to_if_br_pc),

  .inst_to_pred(if_to_pred_inst),
  .true_hit(if_to_pred_flag),
  .to_pred_pc(if_to_pred_pc),
  .pred_pc(pred_to_if_pc),
  .pred_jump(pred_to_if_jump)
);

Predictor Predictor_(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .rob_br(rob_to_if_br),
  .rob_br_jump(rob_to_if_br_jump),
  .rob_br_pc(rob_to_if_br_pc),
  .get_inst(if_to_pred_inst),
  .flag(if_to_pred_flag),
  .pc(if_to_pred_pc),
  .pred_pc(pred_to_if_pc),
  .pred_jump(pred_to_if_jump)
);

Decoder Decoder_ (
  .rst(rst_in),
  .rdy(rdy_in),
  .rollback(rollback),
  .inst_rdy(if_to_dec_inst_rdy),
  .inst(if_to_dec_inst),
  .inst_pc(if_to_dec_inst_pc),
  .inst_pred_jump(if_to_dec_inst_pred_jump),
  .reg_rs1(dec_ask_reg_rs1),
  .reg_rs1_val(dec_ask_reg_rs1_val),
  .reg_rs1_rob_id(dec_ask_reg_rs1_rob_id),
  .reg_rs2(dec_ask_reg_rs2),
  .reg_rs2_val(dec_ask_reg_rs2_val),
  .reg_rs2_rob_id(dec_ask_reg_rs2_rob_id),
  .rob_rs1_pos(dec_ask_rob_rs1_pos),
  .rob_rs1_ready(dec_ask_rob_rs1_ready),
  .rob_rs1_val(dec_ask_rob_rs1_val),
  .rob_rs2_pos(dec_ask_rob_rs2_pos),
  .rob_rs2_ready(dec_ask_rob_rs2_ready),
  .rob_rs2_val(dec_ask_rob_rs2_val),
  .rs_en(dec_to_rs_en),
  .lsb_en(dec_to_lsb_en),
  .nxt_rob_pos(nxt_rob_pos),
  .alu_result(alu_result),
  .alu_result_rob_pos(alu_result_rob_pos),
  .alu_result_val(alu_result_val),
  .lsb_result(lsb_result),
  .lsb_result_rob_pos(lsb_result_rob_pos),
  .lsb_result_val(lsb_result_val),
  .issue(issue),
  .rob_pos(issue_rob_pos),
  .opcode(issue_opcode),
  .is_store(issue_is_store),
  .funct3(issue_funct3),
  .funct7(issue_funct7),
  .rs1_val(issue_rs1_val),
  .rs1_rob_id(issue_rs1_rob_id),
  .rs2_val(issue_rs2_val),
  .rs2_rob_id(issue_rs2_rob_id),
  .imm(issue_imm),
  .rd(issue_rd),
  .pc(issue_pc),
  .pred_jump(issue_pred_jump),
  .is_ready(issue_is_ready)
);

ALU ALU_ (
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .rollback(rollback),
  .alu_en(rs_to_alu_en),
  .opcode(rs_to_alu_opcode),
  .funct3(rs_to_alu_funct3),
  .funct7(rs_to_alu_funct7),
  .val1(rs_to_alu_val1),
  .val2(rs_to_alu_val2),
  .imm(rs_to_alu_imm),
  .pc(rs_to_alu_pc),
  .rob_pos(rs_to_alu_rob_pos),
  .result(alu_result),
  .result_rob_pos(alu_result_rob_pos),
  .result_val(alu_result_val),
  .result_jump(alu_result_jump),
  .result_pc(alu_result_pc)
);

RS RS_ (
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .rollback(rollback),
  .rs_nxt_full(rs_nxt_full),
  .issue(dec_to_rs_en),
  .issue_rob_pos(issue_rob_pos),
  .issue_opcode(issue_opcode),
  .issue_funct3(issue_funct3),
  .issue_funct7(issue_funct7),
  .issue_rs1_val(issue_rs1_val),
  .issue_rs1_rob_id(issue_rs1_rob_id),
  .issue_rs2_val(issue_rs2_val),
  .issue_rs2_rob_id(issue_rs2_rob_id),
  .issue_imm(issue_imm),
  .issue_pc(issue_pc),
  .alu_en(rs_to_alu_en),
  .alu_opcode(rs_to_alu_opcode),
  .alu_funct3(rs_to_alu_funct3),
  .alu_funct7(rs_to_alu_funct7),
  .alu_val1(rs_to_alu_val1),
  .alu_val2(rs_to_alu_val2),
  .alu_imm(rs_to_alu_imm),
  .alu_pc(rs_to_alu_pc),
  .alu_rob_pos(rs_to_alu_rob_pos),
  .alu_result(alu_result),
  .alu_result_rob_pos(alu_result_rob_pos),
  .alu_result_val(alu_result_val),
  .lsb_result(lsb_result),
  .lsb_result_rob_pos(lsb_result_rob_pos),
  .lsb_result_val(lsb_result_val)
);

ROB ROB_ (
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .rob_nxt_full(rob_nxt_full),
  .rollback(rollback),
  .if_set_pc_en(rob_to_if_set_pc_en),
  .if_set_pc(rob_to_if_set_pc),
  .issue(issue),
  .issue_rd(issue_rd),
  .issue_opcode(issue_opcode),
  .issue_pc(issue_pc),
  .issue_pred_jump(issue_pred_jump),
  .issue_is_ready(issue_is_ready),
  .head_rob_pos(rob_head_pos),
  .commit_rob_pos(rob_commit_pos),
  .reg_write(rob_to_reg_write),
  .reg_rd(rob_to_reg_rd),
  .reg_val(rob_to_reg_val),
  .lsb_store(rob_to_lsb_commit_store),
  .commit_br(rob_to_if_br),
  .commit_br_jump(rob_to_if_br_jump),
  .commit_br_pc(rob_to_if_br_pc),
  .alu_result(alu_result),
  .alu_result_rob_pos(alu_result_rob_pos),
  .alu_result_val(alu_result_val),
  .alu_result_jump(alu_result_jump),
  .alu_result_pc(alu_result_pc),
  .lsb_result(lsb_result),
  .lsb_result_rob_pos(lsb_result_rob_pos),
  .lsb_result_val(lsb_result_val),
  .rs1_pos(dec_ask_rob_rs1_pos),
  .rs1_ready(dec_ask_rob_rs1_ready),
  .rs1_val(dec_ask_rob_rs1_val),
  .rs2_pos(dec_ask_rob_rs2_pos),
  .rs2_ready(dec_ask_rob_rs2_ready),
  .rs2_val(dec_ask_rob_rs2_val),
  .nxt_rob_pos(nxt_rob_pos)
);

LSB LSB_ (
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  .rollback(rollback),
  .lsb_nxt_full(lsb_nxt_full),
  .issue(dec_to_lsb_en),
  .issue_rob_pos(issue_rob_pos),
  .issue_is_store(issue_is_store),
  .issue_funct3(issue_funct3),
  .issue_rs1_val(issue_rs1_val),
  .issue_rs1_rob_id(issue_rs1_rob_id),
  .issue_rs2_val(issue_rs2_val),
  .issue_rs2_rob_id(issue_rs2_rob_id),
  .issue_imm(issue_imm),
  .mc_en(lsb_to_mc_en),
  .mc_wr(lsb_to_mc_wr),
  .mc_addr(lsb_to_mc_addr),
  .mc_len(lsb_to_mc_len),
  .mc_w_data(lsb_to_mc_w_data),
  .mc_done(mc_to_lsb_done),
  .mc_r_data(mc_to_lsb_r_data),
  .result(lsb_result),
  .result_rob_pos(lsb_result_rob_pos),
  .result_val(lsb_result_val),
  .alu_result(alu_result),
  .alu_result_rob_pos(alu_result_rob_pos),
  .alu_result_val(alu_result_val),
  .lsb_result(lsb_result),
  .lsb_result_rob_pos(lsb_result_rob_pos),
  .lsb_result_val(lsb_result_val),
  .commit_store(rob_to_lsb_commit_store),
  .commit_rob_pos(rob_commit_pos),
  .head_rob_pos(rob_head_pos)
);

endmodule