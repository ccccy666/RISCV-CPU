`ifndef ALU
`define ALU
`include "constant.v"

module ALU (
  
  input wire clk,
  input wire rst,
  input wire rdy,

  input wire rollback,

  // from Reservation Station
  input wire       alu_en,
  input wire [6:0] opcode,
  input wire [2:0] funct3,
  input wire       funct7,
  input wire [31:0] val1,
  input wire [31:0] val2,
  input wire [31:0] imm,
  input wire [31:0] pc,
  input wire [3:0] rob_pos,

  // broadcast result
  output reg       result,
  output reg [3:0] result_rob_pos,
  output reg [31:0] result_val,
  output reg        result_jump,
  output reg [31:0] result_pc
);

  wire [31:0] arith_op1 = val1;
  wire [31:0] arith_op2 = opcode == `OPCODE_ARITH ? val2 : imm;
  reg [31:0] arith_res;
  always @(*) begin
    case (funct3)
      `FUNCT3_ADD:  // ADD or SUB
      if (opcode == `OPCODE_ARITH && funct7)   arith_res = arith_op1 - arith_op2;
      else          arith_res = arith_op1 + arith_op2;
      `FUNCT3_XOR:  arith_res = arith_op1 ^ arith_op2;
      `FUNCT3_OR:   arith_res = arith_op1 | arith_op2;
      `FUNCT3_AND:  arith_res = arith_op1 & arith_op2;
      `FUNCT3_SLL:  arith_res = arith_op1 << arith_op2;
      `FUNCT3_SRL:  // SRL or SRA
      if (funct7)   arith_res = $signed(arith_op1) >> arith_op2[5:0];
      else          arith_res = arith_op1 >> arith_op2[5:0];
      `FUNCT3_SLT:  arith_res = ($signed(arith_op1) < $signed(arith_op2));
      `FUNCT3_SLTU: arith_res = (arith_op1 < arith_op2);
    endcase
  end

  reg jump;
  always @(*) begin
    case (funct3)
      `FUNCT3_BEQ:  jump = (val1 == val2);
      `FUNCT3_BNE:  jump = (val1 != val2);
      `FUNCT3_BLT:  jump = ($signed(val1) < $signed(val2));
      `FUNCT3_BGE:  jump = ($signed(val1) >= $signed(val2));
      `FUNCT3_BLTU: jump = (val1 < val2);
      `FUNCT3_BGEU: jump = (val1 >= val2);
      default:      jump = 0;
    endcase
  end

  always @(posedge clk) begin
    if (rst || rollback) begin
      result <= 0;
      result_rob_pos <= 0;
      result_val <= 0;
      result_jump <= 0;
      result_pc <= 0;
    end else if (!rdy) begin
      ;
    end else begin
      result <= 0;
      if (alu_en) begin
        result <= 1;
        result_rob_pos <= rob_pos;
        result_jump <= 0;
        case (opcode)
          `OPCODE_ARITH, `OPCODE_ARITHI: result_val <= arith_res;
          `OPCODE_BR:
          if (jump) begin
            result_jump <= 1;
            result_pc   <= pc + imm;
          end else begin
            result_pc   <= pc + 4;
          end
          `OPCODE_JAL: begin
            result_jump <= 1;
            result_val <= pc + 4;
            result_pc  <= pc + imm;
          end
          `OPCODE_JALR: begin
            result_jump <= 1;
            result_val <= pc + 4;
            result_pc  <= val1 + imm;
          end
          `OPCODE_LUI:   result_val <= imm;
          `OPCODE_AUIPC: result_val <= pc + imm;
        endcase
      end
    end
  end

endmodule
`endif