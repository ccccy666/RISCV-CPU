`ifndef LSB
`define LSB
`include "constant.v"

module LSB (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire rollback,

    output wire lsb_nxt_full,

    // issue instruction
    input wire issue,
    input wire [3:0] issue_rob_pos,
    input wire issue_is_store,
    input wire [2:0] issue_funct3,
    input wire [31:0] issue_rs1_val,
    input wire [4:0] issue_rs1_rob_id,
    input wire [31:0] issue_rs2_val,
    input wire [4:0] issue_rs2_rob_id,
    input wire [31:0] issue_imm,

    // Memory Controller
    output reg mc_en,
    output reg mc_wr,      // 1 = write
    output reg [31:0] mc_addr,
    output reg [2:0] mc_len,
    output reg [31:0] mc_w_data,
    input wire mc_done,
    input wire [31:0] mc_r_data,

    // broadcast result
    output reg result,
    output reg [3:0] result_rob_pos,
    output reg [31:0] result_val,

    // handle the broadcast
    // from Reservation Station
    input wire alu_result,
    input wire [3:0] alu_result_rob_pos,
    input wire [31:0] alu_result_val,
    // from Load Store Buffer
    input wire lsb_result,
    input wire [3:0] lsb_result_rob_pos,
    input wire [31:0] lsb_result_val,

    // Reorder Buffer commits store
    input wire commit_store,
    input wire [3:0] commit_rob_pos,

    // check if I/O read can be done
    input wire [3:0] head_rob_pos
);
integer i;
reg empty;

reg busy[15:0];
reg is_store[15:0];
reg [2:0] funct3[15:0];
reg [31:0] rs1_val[15:0];
reg [31:0] rs2_val[15:0];
reg [4:0] rs1_rob_id[15:0];
reg [4:0] rs2_rob_id[15:0];
reg [31:0] imm [15:0];
reg [3:0] rob_pos[15:0];
reg committed[15:0];

reg [3:0] head, tail;
reg [4:0] last_commit_pos;
reg [1:0] status;

wire [31:0] head_addr = rs1_val[head] + imm[head];
wire head_is_io = head_addr[17:16] == 2'b11;
wire ready = !empty && rs1_rob_id[head][4] == 0 && rs2_rob_id[head][4] == 0;
wire isload = !is_store[head] && !rollback && (!head_is_io || rob_pos[head] == head_rob_pos);
wire check = isload || committed[head];

wire execute = ready && check;

wire pop = status == 1 && mc_done;
wire nxt_empty = (head + pop == tail + issue && (empty || pop && !issue));
assign lsb_nxt_full = (head + pop == tail + issue && !nxt_empty);

always @(posedge clk) begin
  if (rst || (rollback && last_commit_pos == 16)) begin
    status <= 0;
    mc_en <= 0;
    head <= 0;
    tail <= 0;
    last_commit_pos <= 16;
    empty <= 1;
    for (i = 0; i < 16; i = i + 1) begin
      busy[i] <= 0;
      is_store[i] <= 0;
      funct3[i] <= 0;
      rs1_rob_id[i] <= 0;
      rs1_val[i] <= 0;
      rs2_rob_id[i] <= 0;
      rs2_val[i] <= 0;
      imm[i] <= 0;
      rob_pos[i] <= 0;
      committed[i] <= 0;
    end
  end else if (!rdy) begin
    ;
  end else if (!rollback) begin
    
    if (commit_store) begin
      for (i = 0; i < 16; i = i + 1)
        if (busy[i] && rob_pos[i] == commit_rob_pos && !committed[i]) begin
          committed[i] <= 1;
          last_commit_pos <= {1'b0, i[3:0]};
        end
    end
    
    if (alu_result)//类似rs,拿到vi,vj
      for (i = 0; i < 16; i = i + 1) begin
        if (rs1_rob_id[i] == {1'b1, alu_result_rob_pos}) begin
          rs1_rob_id[i] <= 0;
          rs1_val[i] <= alu_result_val;
        end
        if (rs2_rob_id[i] == {1'b1, alu_result_rob_pos}) begin
          rs2_rob_id[i] <= 0;
          rs2_val[i] <= alu_result_val;
        end
      end

    if (lsb_result)
      for (i = 0; i < 16; i = i + 1) begin
        if (rs1_rob_id[i] == {1'b1, lsb_result_rob_pos}) begin
          rs1_rob_id[i] <= 0;
          rs1_val[i] <= lsb_result_val;
        end
        if (rs2_rob_id[i] == {1'b1, lsb_result_rob_pos}) begin
          rs2_rob_id[i] <= 0;
          rs2_val[i] <= lsb_result_val;
        end
      end

    if (issue) begin
      busy[tail] <= 1;
      is_store[tail] <= issue_is_store;
      funct3[tail] <= issue_funct3;
      rs1_rob_id[tail] <= issue_rs1_rob_id;
      rs1_val[tail] <= issue_rs1_val;
      rs2_rob_id[tail] <= issue_rs2_rob_id;
      rs2_val[tail] <= issue_rs2_val;
      imm[tail] <= issue_imm;
      rob_pos[tail] <= issue_rob_pos;
    end
    result <= 0;
    if (status == 1) begin
      if (mc_done) begin  // finish
        busy[head] <= 0;
        committed[head] <= 0;
        result_rob_pos <= rob_pos[head];//load需要
        status <= 0;
        mc_en <= 0;
        if (last_commit_pos[3:0] == head)begin//commit已经执行完了
          last_commit_pos <= 16;
        end
        if (!is_store[head]) begin//load
          result <= 1;
          case (funct3[head])
            `FUNCT3_LB:result_val <= {{24{mc_r_data[7]}}, mc_r_data[7:0]};
            `FUNCT3_LBU:result_val <= {24'b0, mc_r_data[7:0]};
            `FUNCT3_LH:result_val <= {{16{mc_r_data[15]}}, mc_r_data[15:0]};
            `FUNCT3_LHU:result_val <= {16'b0, mc_r_data[15:0]};
            `FUNCT3_LW:result_val <= mc_r_data;
          endcase
          
        end
        
      end
    end else begin  // status == 0
      
      mc_en <= 0;
      if (execute) begin//传给mc
        mc_en <= 1;
        mc_addr <= head_addr;
        mc_wr <= 0;
        if (is_store[head]) begin
          mc_wr <= 1;
          mc_w_data <= rs2_val[head];
          case (funct3[head])
            `FUNCT3_SB:mc_len <= 3'd1;
            `FUNCT3_SH:mc_len <= 3'd2;
            `FUNCT3_SW:mc_len <= 3'd4;
          endcase
          
        end else begin
          case (funct3[head])
            `FUNCT3_LB:mc_len <= 3'd1;
            `FUNCT3_LBU:mc_len <= 3'd1;
            `FUNCT3_LH:mc_len <= 3'd2;
            `FUNCT3_LHU:mc_len <= 3'd2;
            `FUNCT3_LW:mc_len <= 3'd4;
          endcase

        end
        status <= 1;
      end
    end


    
    empty <= nxt_empty;
    head  <= head + pop;
    tail  <= tail + issue;
  end else begin
    tail <= last_commit_pos + 1;
    for (i = 0; i < 16; i = i + 1) begin
      if (!committed[i]) begin
        busy[i] <= 0;
      end
    end
    if (status == 1 && mc_done) begin  // finish
      busy[head] <= 0;
      committed[head] <= 0;
      
      if (last_commit_pos[3:0] == head) begin
        last_commit_pos <= 16;
        empty <= 1;
      end
      status <= 0;
      mc_en <= 0;
      head <= head + 1;
    end
    // execute Load or Store
    
  end
end
endmodule
`endif