`ifndef DECODER
`define DECODER
`include "constant.v"

module Decoder (
    input wire rst,
    input wire rdy,

    input wire rollback,

    input wire inst_rdy,
    input wire [31:0] inst,
    input wire [31:0] inst_pc,
    input wire inst_pred_jump,

    output wire [3:0] rob_rs1_pos,
    input wire rob_rs1_ready,
    input wire [31:0] rob_rs1_val,
    output wire [3:0] rob_rs2_pos,
    input wire rob_rs2_ready,
    input wire [31:0] rob_rs2_val,

    output reg rs_en,
    output reg lsb_en,

    input wire [3:0] nxt_rob_pos,


    output wire [4:0] reg_rs1,
    input wire [31:0] reg_rs1_val,
    input wire [4:0] reg_rs1_rob_id,
    output wire [4:0] reg_rs2,
    input wire [31:0] reg_rs2_val,
    input wire [4:0] reg_rs2_rob_id,

    

    input wire alu_result,
    input wire [3:0] alu_result_rob_pos,
    input wire [31:0] alu_result_val,
    input wire lsb_result,
    input wire [3:0] lsb_result_rob_pos,
    input wire [31:0] lsb_result_val,

    output reg issue,
    output reg pred_jump,
    output reg [3:0] rob_pos,
    output reg [6:0] opcode,
    output reg [2:0] funct3,
    output reg funct7,
    output reg [31:0] imm,
    output reg [4:0] rd,
    output reg [31:0] pc,
    output reg [31:0] rs1_val,
    output reg [31:0] rs2_val,
    output reg [4:0] rs1_rob_id,

    output reg [4:0] rs2_rob_id,
    
    output reg is_store,
    output reg is_ready
);
assign reg_rs1 = inst[19:15];
assign reg_rs2 = inst[24:20];
assign rob_rs1_pos = reg_rs1_rob_id[3:0];
assign rob_rs2_pos = reg_rs2_rob_id[3:0];

always @(*) begin
  issue  = 0;
  lsb_en = 0;
  rs_en  = 0;
  is_ready = 0;

  rs1_val = 0;
  rs1_rob_id = 0;
  rs2_val = 0;
  rs2_rob_id = 0;
  opcode = inst[6:0];
  funct3 = inst[14:12];
  funct7 = inst[30];
  rd = inst[11:7];
  imm = 0;
  pc = inst_pc;
  pred_jump = inst_pred_jump;

  rob_pos = nxt_rob_pos;

  

  if (rst || !inst_rdy || rollback || !rdy) begin
    ;
  end else begin
    issue = 1;

    rs1_rob_id = 0;
    rs2_rob_id = 0;
    is_store = 0;
    if (reg_rs1_rob_id[4] == 0) begin
      rs1_val = reg_rs1_val;
    end else if (rob_rs1_ready) begin
      rs1_val = rob_rs1_val;
    end else if (alu_result && rob_rs1_pos == alu_result_rob_pos) begin
      rs1_val = alu_result_val;
    end else if (lsb_result && rob_rs1_pos == lsb_result_rob_pos) begin
      rs1_val = lsb_result_val;
    end else begin
      rs1_rob_id = reg_rs1_rob_id;
      rs1_val = 0;
      
    end
    
    if (reg_rs2_rob_id[4] == 0) begin
      rs2_val = reg_rs2_val;
    end else if (rob_rs2_ready) begin
      rs2_val = rob_rs2_val;
    end else if (alu_result && rob_rs2_pos == alu_result_rob_pos) begin
      rs2_val = alu_result_val;
    end else if (lsb_result && rob_rs2_pos == lsb_result_rob_pos) begin
      rs2_val = lsb_result_val;
    end else begin
      rs2_rob_id = reg_rs2_rob_id;
      rs2_val = 0;
      
    end

    
    case (inst[6:0])
      `OPCODE_LUI: begin
        imm = {inst[31:12], 12'b0};
        rs_en = 1;
        rs1_rob_id = 0;
        rs1_val = 0;
        rs2_rob_id = 0;
        rs2_val = 0;
        
      end
      `OPCODE_AUIPC: begin
        imm = {inst[31:12], 12'b0};
        rs_en = 1;
        rs1_rob_id = 0;
        rs1_val = 0;
        rs2_rob_id = 0;
        rs2_val = 0;
        
      end
      `OPCODE_JALR: begin
        imm = {{21{inst[31]}}, inst[30:20]};
        rs_en = 1;
        rs2_rob_id = 0;
        rs2_val = 0;
        
      end
      `OPCODE_JAL: begin
        imm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
        rs_en = 1;
        rs1_rob_id = 0;
        rs1_val = 0;
        rs2_rob_id = 0;
        rs2_val = 0;
        
      end
      `OPCODE_L: begin//lb,lh,lw,lbu,lhu
        imm = {{21{inst[31]}}, inst[30:20]};
        lsb_en = 1;
        rs2_rob_id = 0;
        rs2_val = 0;
        
      end
      `OPCODE_S: begin//sb,sh,sw
        imm = {{21{inst[31]}}, inst[30:25], inst[11:7]};
        lsb_en = 1;
        is_ready = 1;
        rd = 0;
        
        is_store = 1;
      end
      
      `OPCODE_CALCI: begin//I型指令 addi,etc
        imm = {{21{inst[31]}}, inst[30:20]};
        rs_en = 1;
        rs2_rob_id = 0;
        rs2_val = 0;
        
      end
      `OPCODE_BR: begin//beq,bne...
        imm = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
        rs_en = 1;
        rd = 0;
        
      end
      `OPCODE_CALC: begin
        rs_en = 1;//add,sub,etc
      end
      
      
      
    endcase
  end
end

endmodule
`endif