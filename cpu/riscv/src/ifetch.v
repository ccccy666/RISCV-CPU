`ifndef IFETCH
`define IFETCH
module IFetch (//without branch predictor
    input wire clk,
    input wire rst,
    input wire rdy,

    // Reservation Station
    input wire rs_nxt_full,
    // Load Store Buffer
    input wire lsb_nxt_full,
    // Reorder Buffer
    input wire rob_nxt_full,

    // to Instruction Decoder
    output reg             inst_rdy,
    output reg [31:0] inst,
    

    // to Memory Controller
    output reg                 mc_en,
    output reg  [   31:0] mc_pc,
    input  wire                mc_done,
    input  wire [511:0] mc_data,

    // from Reorder Buffer, set pc
    input wire             rob_set_pc_en,
    input wire [31:0] rob_set_pc,
    
);


localparam IDLE = 0, WAIT_MEM = 1;
reg [31:0] pc;
reg status;

// Instruction Cache
reg valid[15:0];
reg [21:0] tag[15:0];
reg [511:0] data[15:0];


wire [3:0] pc_bs = pc[5:2];
wire [3:0] pc_index = pc[9:6];
wire [21:0] pc_tag = pc[31:10];
wire hit = valid[pc_index] && (tag[pc_index] == pc_tag);
wire [3:0] mc_pc_index = mc_pc[9:6];
wire [21:0] mc_pc_tag = mc_pc[31:10];

wire [511:0] cur_block_raw = data[pc_index];
wire [31:0] cur_block[15:0];
wire [31:0] get_inst = cur_block[pc_bs];

genvar _i;
generate
  for (_i = 0; _i < `ICACHE_BLK_SIZE / `INST_SIZE; _i = _i + 1) begin
    assign cur_block[_i] = cur_block_raw[_i*32+31:_i*32];
  end
endgenerate

integer i;
always @(posedge clk)begin
    if (rst) begin
      pc    <= 32'h0;
      mc_pc <= 32'h0;
      mc_en <= 0;
      for (i = 0; i < `ICACHE_BLK_NUM; i = i + 1) begin
        valid[i] <= 0;
      end
      inst_rdy <= 0;
      status   <= IDLE;
    end else if (!rdy) begin
      ;
    end else begin
      if (rob_set_pc_en) begin
        inst_rdy <= 0;
        pc <= rob_set_pc;
        
      end else begin
        if (hit && !rs_nxt_full && !lsb_nxt_full && !rob_nxt_full) begin
          inst_rdy <= 1;
          inst <= get_inst;
          pc<=pc+4;
          
        end else begin
          inst_rdy <= 0;
        end
      end
      if (status == IDLE) begin
        if (!hit) begin
          mc_en  <= 1;
          mc_pc  <= {pc[31:6], 6'b0};
          status <= WAIT_MEM;
        end
      end else begin
        if (mc_done) begin
          valid[mc_pc_index] <= 1;
          tag[mc_pc_index]   <= mc_pc_tag;
          data[mc_pc_index]  <= mc_data;
          mc_en  <= 0;
          status <= IDLE;
        end
      end
    end
end

endmodule
`endif