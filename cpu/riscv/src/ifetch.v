`ifndef IFETCH
`define IFETCH
`include "constant.v"
module IFetch (//with branch predictor
  input wire clk,
  input wire rst,
  input wire rdy,
  input wire rs_nxt_full,
  input wire lsb_nxt_full,
  input wire rob_nxt_full,

  input wire rob_set_pc_en,
  input wire [31:0] rob_set_pc,

  input wire rob_br,
  input wire rob_br_jump,
  input wire [31:0] rob_br_pc,

  output reg inst_rdy,
  output reg [31:0] inst,
  output reg [31:0] inst_pc,
  output reg inst_pred_jump,

  output reg mc_en,
  output reg [31:0] mc_pc,
  input wire mc_done,
  input wire [511:0] mc_data
  
);


reg [31:0] pc;
reg status;

// ICache
reg valid[15:0];
reg [21:0] tag[15:0];
reg [511:0] data[15:0];

reg [31:0] pred_pc;
reg pred_jump;


wire [3:0] pc_bs = pc[5:2];
wire [3:0] pc_index = pc[9:6];
wire [21:0] pc_tag = pc[31:10];
wire hit = valid[pc_index] && (tag[pc_index] == pc_tag);
wire [3:0] mc_pc_index = mc_pc[9:6];
wire [21:0] mc_pc_tag = mc_pc[31:10];

wire [511:0] cur_block_raw = data[pc_index];
wire [31:0] cur_block[15:0];
wire [31:0] get_inst = cur_block[pc_bs];
reg [1:0] bht[256-1:0];
wire [7:0] bht_idx = rob_br_pc[9:2];
wire [7:0] pc_bht_idx = pc[9:2];

always @(*) begin
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

genvar _i;
generate
  for (_i = 0; _i < 16; _i = _i + 1) begin
    assign cur_block[_i] = cur_block_raw[_i*32+31:_i*32];
  end
endgenerate

integer i;
always @(posedge clk)begin
    if (rst) begin
      for (i = 0; i < 256; i = i + 1) begin
        bht[i] <= 0;
      end
      for (i = 0; i < 16; i = i + 1) begin
        valid[i] <= 0;
      end
      pc <= 32'h0;
      mc_pc <= 32'h0;
      mc_en <= 0;
      inst_rdy <= 0;
      status <= 0;
      
    end else if (!rdy) begin
      ;
    end else begin
      if (!rob_set_pc_en) begin
        if (hit && !rs_nxt_full && !lsb_nxt_full && !rob_nxt_full) begin
          inst_rdy <= 1;
          inst <= get_inst;
          pc <= pred_pc;
          inst_pc <= pc;
          inst_pred_jump <= pred_jump;
        end else begin
          inst_rdy <= 0;
        end
        
      end else begin
        inst_rdy <= 0;
        pc <= rob_set_pc;
      end
      if (status == 1) begin
        if (mc_done) begin
          mc_en <= 0;
          status <= 0;
          valid[mc_pc_index] <= 1;
          tag[mc_pc_index] <= mc_pc_tag;
          data[mc_pc_index] <= mc_data;
          
        end
        
      end else begin
        if (!hit) begin
          mc_en <= 1;
          mc_pc <= {pc[31:6], 6'b0};
          status <= 1;
        end
      end
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