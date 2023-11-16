module buffer
(//保证了队列中始终有格子是空的
input wire clk,
input wire rst,
input wire write,//add
input wire[7:0] writedata,
input wire read,//pop
output wire[7:0] readdata,
output wire full,   
output wire empty

);
reg[7:0] cur_rd_ptr;
wire[7:0] nxt_rd_ptr;
reg  [7:0] cur_wr_ptr;//指向的地方一直为空
wire [7:0] nxt_wr_ptr;
reg cur_empty;
wire nxt_empty;
reg cur_full;
wire nxt_full;
reg[7:0] data[7:0];
wire [7:0] datawrite;

always @(posedge clk) begin
    if(rst) begin
        cur_rd_ptr <= 1'b0;
        cur_wr_ptr <= 1'b0;
        cur_empty <= 1'b1;
        cur_full <= 1'b0;
    end
    else begin//上周期的值赋给当前周期
        cur_rd_ptr <= nxt_rd_ptr;
        cur_wr_ptr <= nxt_wr_ptr;
        cur_empty <= nxt_empty;
        cur_full <= nxt_full;
        data[cur_wr_ptr] <= datawrite;//curwrptr还是上周期的curwrptr
    end
end
assign empty = cur_empty;
assign full = cur_full;

wire canread;
wire canwrite;
assign canread = (read && !cur_empty);
assign canwrite = (write && !cur_full);

assign nxt_rd_ptr = canread ? cur_rd_ptr + 1'b1 : cur_rd_ptr;
assign nxt_wr_ptr = canwrite ? cur_wr_ptr + 1'b1 : cur_wr_ptr;
assign datawrite = canwrite ? writedata : data[cur_wr_ptr];
assign readdata = data[cur_rd_ptr];

assign nxt_empty = (cur_empty && !canwrite) || (cur_wr_ptr - cur_rd_ptr == 1'b1 && canread);
assign nxt_full = (cur_full && !canread) || (cur_rd_ptr - cur_wr_ptr == 1'b1 && canwrite);


endmodule