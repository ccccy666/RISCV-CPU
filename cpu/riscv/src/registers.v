`ifndef RegFile
`define RegFile
`include "constant.v"

module RegFile (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire rollback,
    // ReorderBuffer commit
    input wire commit,
    input wire [4:0] commit_rd,
    input wire [31:0] commit_val,
    input wire [3:0] commit_rob_pos,
    // Decoder issue instruction
    input wire issue,
    input wire [4:0] issue_rd,
    input wire [3:0] issue_rob_pos,
    // query from Decoder, combinational
    input wire [4:0] rs1,
    output reg [31:0] val1,
    output reg [4:0] rob_id1,
    input wire [4:0] rs2,
    output reg [31:0] val2,
    output reg [4:0] rob_id2

    
);

reg [31:0] val[31:0];
reg [4:0] rob_id[31:0];  // {flag, rob_id}; flag: 0=ready, 1=renamed
wire is_latest_commit = rob_id[commit_rd] == {1'b1, commit_rob_pos};
wire nonzero_commit = commit && commit_rd != 0;
  

integer i;
always @(*) begin
  if (!nonzero_commit || rs1 != commit_rd || !is_latest_commit) begin
    rob_id1 = rob_id[rs1];
    val1 = val[rs1];
  end else begin
    val1 = commit_val;
    rob_id1 = 5'b0;
  end

  if (!nonzero_commit || rs2 != commit_rd || !is_latest_commit) begin
    
    rob_id2 = rob_id[rs2];
    val2 = val[rs2];
  end else begin
    val2 = commit_val;
    rob_id2 = 5'b0;
  end
end


always @(posedge clk) begin
  if (rst) begin
    for (i = 0; i < 32; i = i + 1) begin
      val[i] <= 32'b0;
      rob_id[i] <= 5'b0;
    end
  end else if (!rdy) begin
    ;
  end else begin
    
    if (nonzero_commit) begin
      val[commit_rd] <= commit_val;
      if (is_latest_commit) begin
        rob_id[commit_rd] <= 5'b0;
      end
    end
    if (issue && issue_rd != 0) begin
      rob_id[issue_rd] <= {1'b1, issue_rob_pos};
    end

    if (rollback) begin
      for (i = 0; i < 32; i = i + 1) begin
        rob_id[i] <= 5'b0;
      end
    end
  end
end


endmodule
`endif