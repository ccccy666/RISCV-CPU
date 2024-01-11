`ifndef ALU
`define ALU
`include "constant.v"

module ALU (
  
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire rollback,

    input wire alu_en,
    input wire [6:0] opcode,
    input wire [2:0] funct3,
    input wire funct7,
    input wire [31:0] val1,
    input wire [31:0] val2,
    input wire [31:0] imm,
    input wire [31:0] pc,
    input wire [3:0] rob_pos,

    output reg result,
    output reg [3:0] result_rob_pos,
    output reg [31:0] result_val,
    output reg result_jump,
    output reg [31:0] result_pc
);
reg jump;
wire [31:0] vi = val1;
wire [31:0] vj = opcode == `OPCODE_CALC ? val2 : imm;
reg [31:0] A;
always @(*) begin
  case (funct3)
    `FUNCT3_ADD:
    if (opcode == `OPCODE_CALC && funct7)begin
      A = vi - vj;
    end else begin
      A = vi + vj;
    end
    
    `FUNCT3_XOR:A = vi ^ vj;
    `FUNCT3_OR:A = vi | vj;
    `FUNCT3_AND:A = vi & vj;
    `FUNCT3_SLL:A = vi << vj;
    `FUNCT3_SRL:
    if (funct7)begin
      A = $signed(vi) >> vj[5:0];
    end
    else begin
      A = vi >> vj[5:0];
    end
    `FUNCT3_SLT:A = ($signed(vi) < $signed(vj));
    `FUNCT3_SLTU:A = (vi < vj);
    
  endcase
  case (funct3)
    `FUNCT3_BEQ:jump = (val1 == val2);
    `FUNCT3_BNE:jump = (val1 != val2);
    `FUNCT3_BLT:jump = ($signed(val1) < $signed(val2));
    `FUNCT3_BGE:jump = ($signed(val1) >= $signed(val2));
    `FUNCT3_BLTU:jump = (val1 < val2);
    `FUNCT3_BGEU:jump = (val1 >= val2);
    default:jump = 0;
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
        `OPCODE_LUI:result_val <= imm;
        `OPCODE_AUIPC:result_val <= pc + imm;
        `OPCODE_JAL:begin
          result_jump <= 1;
          result_val <= pc + 4;
          result_pc <= pc + imm;
        end
        `OPCODE_JALR: begin
          result_jump <= 1;
          result_val <= pc + 4;
          result_pc <= val1 + imm;
        end
        `OPCODE_CALC: result_val <= A;
        `OPCODE_CALCI: result_val <= A;
        `OPCODE_BR:
        if (jump) begin
          result_jump <= 1;
          result_pc <= pc + imm;
        end else begin
          result_pc <= pc + 4;
        end
        
        
      endcase
    end
  end
end

endmodule
`endif