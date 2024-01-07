`ifndef ROB
`define ROB
`include "constant.v"

module rob(
    input wire clk,
    input wire rst,
    input wire rdy,

    output wire rob_nxt_full,
    output reg  rollback,

    // to Instruction Fetcher, set pc
    output reg        if_set_pc_en,
    output reg [31:0] if_set_pc,

    // issue an instruction to Reorder Buffer
    input wire       issue,
    input wire [4:0] issue_rd,
    input wire [6:0] issue_opcode,
    input wire [31:0] issue_pc,
    input wire        issue_pred_jump,
    input wire        issue_is_ready,

    // for LSB to check if I/O read can be done
    output wire [3:0] head_rob_pos,

    // commit
    output reg [3:0] commit_rob_pos,
    // write to Register
    output reg       reg_write,
    output reg [4:0] reg_rd,
    output reg [31:0] reg_val,
    // commit store to Load Store Buffer
    output reg        lsb_store,
    // update predictor
    output reg        commit_br,
    output reg        commit_br_jump,
    output reg [31:0] commit_br_pc,

    // handle the broadcast
    // from Reservation Station
    input wire       alu_result,
    input wire [3:0] alu_result_rob_pos,
    input wire [31:0] alu_result_val,
    input wire        alu_result_jump,
    input wire [31:0] alu_result_pc,
    // from Load Store Buffer
    input wire       lsb_result,
    input wire [3:0] lsb_result_rob_pos,
    input wire [31:0] lsb_result_val,

    // handle the query from Decoder
    input  wire [3:0] rs1_pos,
    output wire       rs1_ready,
    output wire [31:0] rs1_val,
    input  wire [3:0] rs2_pos,
    output wire       rs2_ready,
    output wire [31:0] rs2_val,
    output wire [3:0] nxt_rob_pos
);
  reg [6:0] opcode   [15:0];
  reg [31:0] val      [15:0];

  reg [4:0] rd       [15:0];
  reg [31:0] pc       [15:0];
  reg [31:0] res_pc   [15:0];

  reg       pred_jump[15:0];  // predict whether to jump, 1=jump
  reg       res_jump [15:0];  // execution result
  reg       ready    [15:0];

  reg [3:0] head, tail;
  reg empty;
  wire commit = !empty && ready[head];

  assign nxt_rob_pos = tail;
  wire nxt_empty = (head + commit == tail + issue && (empty || commit && !issue));
  assign rob_nxt_full = (head + commit == tail + issue && !nxt_empty);

  assign head_rob_pos = head;

  // handle the query from Decoder
  assign rs1_ready = ready[rs1_pos];
  assign rs1_val = val[rs1_pos];
  assign rs2_ready = ready[rs2_pos];
  assign rs2_val = val[rs2_pos];

  integer i;
  always @(posedge clk) begin
    if (rst || rollback) begin
      head <= 0;
      tail <= 0;
      empty <= 1;
      rollback <= 0;
      if_set_pc_en <= 0;
      if_set_pc <= 0;
      for (i = 0; i < 16; i = i + 1) begin
        ready[i] <= 0;
        rd[i] <= 0;
        val[i] <= 0;
        pc[i] <= 0;
        opcode[i] <= 0;
        pred_jump[i] <= 0;
        res_jump[i] <= 0;
        res_pc[i] <= 0;
      end
      reg_write <= 0;
      lsb_store <= 0;
      commit_br <= 0;
    end else if (!rdy) begin
      ;
    end else begin
      // add instruction
      empty <= nxt_empty;
      if (issue) begin
        rd[tail]        <= issue_rd;
        opcode[tail]    <= issue_opcode;
        pc[tail]        <= issue_pc;
        pred_jump[tail] <= issue_pred_jump;
        ready[tail]     <= issue_is_ready;
        tail            <= tail + 1'b1;
      end

      // update result
      if (alu_result) begin
        val[alu_result_rob_pos] <= alu_result_val;
        ready[alu_result_rob_pos] <= 1;
        res_jump[alu_result_rob_pos] <= alu_result_jump;
        res_pc[alu_result_rob_pos] <= alu_result_pc;
      end
      if (lsb_result) begin
        val[lsb_result_rob_pos]   <= lsb_result_val;
        ready[lsb_result_rob_pos] <= 1;
      end

      // commit
      reg_write <= 0;
      lsb_store <= 0;
      commit_br <= 0;
      if (commit) begin

        commit_rob_pos <= head;
        if (opcode[head] == `OPCODE_S) begin
          lsb_store <= 1;
        end else if (opcode[head] != `OPCODE_BR) begin
          reg_write <= 1;
          reg_rd    <= rd[head];
          reg_val   <= val[head];
        end
        if (opcode[head] == `OPCODE_BR) begin
          commit_br <= 1;
          commit_br_jump <= res_jump[head];
          commit_br_pc <= pc[head];
          if (pred_jump[head] != res_jump[head]) begin
            rollback <= 1;
            if_set_pc_en <= 1;
            if_set_pc <= res_pc[head];
          end
        end
        if (opcode[head] == `OPCODE_JALR) begin
          if (pred_jump[head] != res_jump[head]) begin  // TODO: check
            rollback <= 1;
            if_set_pc_en <= 1;
            if_set_pc <= res_pc[head];
          end
        end
        head <= head + 1'b1;
      end
    end
  end

endmodule
`endif