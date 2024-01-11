`ifndef Predictor
`define Predictor
`include "constant.v"
module Predictor (
    input wire clk,  // system clock signal
    input wire rst,  // reset signal
    input wire rdy,  // ready signal, pause cpu when low


    input wire rob_br,
    input wire rob_br_jump,
    input wire [31:0] rob_br_pc,
    input wire [31:0] get_inst,
    input wire flag,

    input wire [31:0] pc,
    output reg [31:0] pred_pc,
    output reg pred_jump


    
);
reg [1:0] bht[255:0];
wire [7:0] bht_idx = rob_br_pc[9:2];
wire [7:0] pc_bht_idx = pc[9:2];

always @(*) begin
  if(flag)begin
    pred_pc = pc + 4;
    pred_jump = 0;
    case (get_inst[6:0])
        `OPCODE_BR: 
        if (bht[pc_bht_idx] >= 2) begin
        pred_pc = pc + {{20{get_inst[31]}}, get_inst[7], get_inst[30:25], get_inst[11:8], 1'b0};
        pred_jump = 1;
        end
        
        `OPCODE_JAL:begin
        pred_pc = pc + {{12{get_inst[31]}}, get_inst[19:12], get_inst[20], get_inst[30:21], 1'b0};
        pred_jump = 1;
        end
        
    endcase
  end
  
end
integer i;
always @(*) begin
  if (rst) begin
    for (i = 0; i < 256; i = i + 1) begin
      bht[i] <= 0;
    end
  end else if (!rdy)begin
    ;
  end else begin
    if (rob_br) begin
      if (!rob_br_jump) begin
        if (bht[bht_idx] >= 1) begin
          bht[bht_idx] <= bht[bht_idx] - 1;
        end
        
      end else begin
        if (bht[bht_idx] <= 2) begin
          bht[bht_idx] <= bht[bht_idx] + 1;
        end
      end
    end
  end
end
endmodule
`endif