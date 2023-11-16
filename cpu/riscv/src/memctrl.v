`ifndef MEM_CTRL
`define MEM_CTRL
module MemCtrl(
    input wire clk,
    input wire rst,
    input wire rdy,
    
    input  wire [ 7:0] mem_din,   // data input bus
    output reg  [ 7:0] mem_dout,  // data output bus
    output reg  [31:0] mem_a,     // address bus (only 17:0 is used)
    output reg         mem_wr,    // write/read signal (1 for write)

    input wire io_buffer_full,  // 1 if uart buffer is full
    
    input wire ifetch_en,
    input wire[31:0] ifetch_pc,
    output reg ifetch_done,
    output wire [511:0] ifetch_data
    );
    localparam IDLE = 0, IF = 1, LOAD = 2, STORE = 3;
    reg [1:0] status;
    reg [7:0] ifetch_data_addr[63:0];
    reg[6:0] cnt;
    wire[6:0] total= 7'b1000000;//总数为64

    genvar i;
    generate
        for(i=0;i<64;i=i+1)begin
            assign ifetch_data[i*8+7:i*8] = ifetch_data_addr[i];
        end
    endgenerate

    always @(posedge clk)begin
        if(rst)begin
            status <= IDLE;
            ifetch_done <= 0;
            mem_a <= 0;
            mem_wr <= 0;
            cnt <= 0;
        end
        else if (!rdy)begin
            ifetch_done <= 0;
            mem_a <= 0;
            mem_wr <= 0;
            cnt<=0;
        end
        else begin
            if(status == IF)begin
                mem_wr <= 0;
                ifetch_data_addr[cnt] <= mem_din;
                if(cnt + 1 == total)mem_a <= 0;
                else mem_a <= mem_a + 1;
                if(cnt == total)begin
                    ifetch_done <= 1;
                    cnt <= 0;
                    status = IDLE;
                end
                else begin
                    cnt <= cnt + 1;
                end
            end
            else if(status == IDLE)begin
                if(ifetch_done)ifetch_done <= 0;
                else if(ifetch_en) begin
                    status <= IF;
                    mem_a <= ifetch_pc;
                    cnt <= 0;
                end
            end
        end
    end
endmodule
`endif