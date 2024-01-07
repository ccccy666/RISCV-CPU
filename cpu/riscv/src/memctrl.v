`ifndef MEM_CTRL
`define MEM_CTRL
`include "constant.v"

module MemCtrl (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire rollback,

    input  wire [ 7:0] mem_din,   // data input bus
    output reg  [ 7:0] mem_dout,  // data output bus
    output reg  [31:0] mem_a,     // address bus (only 17:0 is used)
    output reg         mem_wr,    // write/read signal (1 for write)

    input wire io_buffer_full,  // 1 if uart buffer is full
  // Load Store Buffer
    input  wire        lsb_en,
    input  wire        lsb_wr,      
    input  wire [31:0] lsb_addr,
    input  wire [2:0] lsb_len,
    input  wire [31:0] lsb_w_data,
    output reg         lsb_done,
    output reg  [31:0] lsb_r_data,
    // instruction fetch
    input  wire        if_en,
    input  wire [31:0] if_pc,
    output reg         if_done,
    output wire [511:0] if_data

    
);

  reg [1:0] status;
  reg [6:0] cur_len;
  reg [6:0] len;

  reg [31:0] store_addr;

  reg [7:0] if_data_arr[64-1:0];
  genvar _i;
  generate
    for (_i = 0; _i < 64; _i = _i + 1) begin
      assign if_data[_i*8+7:_i*8] = if_data_arr[_i];
    end
  endgenerate

  always @(posedge clk) begin
    if (rst) begin
      status   <= 0;
      
      mem_wr   <= 0;
      mem_a    <= 0;
      if_done  <= 0;
      lsb_done <= 0;
    end else if (!rdy) begin
      
      mem_wr   <= 0;
      mem_a    <= 0;
      if_done  <= 0;
      lsb_done <= 0;
    end else begin
      mem_wr <= 0;
      case (status)
        2'b01: begin
          if_data_arr[cur_len-1] <= mem_din;
          if (cur_len + 1 != len) begin
            mem_a <= mem_a + 1;
            
          end
          else begin
            mem_a <= 0;
          end
          if (cur_len != len) begin
            cur_len <= cur_len + 1;
            
          end else begin
            if_done <= 1;
            mem_wr  <= 0;
            mem_a   <= 0;
            cur_len   <= 0;
            status  <= 0;
          end
        end
        2'b10: begin//load
          if (!rollback) begin
            case (cur_len)
              1: lsb_r_data[7:0] <= mem_din;
              2: lsb_r_data[15:8] <= mem_din;
              3: lsb_r_data[23:16] <= mem_din;
              4: lsb_r_data[31:24] <= mem_din;
            endcase
            if (cur_len + 1 != len) begin
              mem_a <= mem_a + 1;
              
            end
            else begin
              mem_a <= 0;
            end
            if (cur_len != len) begin
              cur_len <= cur_len + 1;
              
            end else begin
              cur_len <= 0;
              status <= 0;
              lsb_done <= 1;
              mem_wr <= 0;
              mem_a <= 0;
              
            end
            
          end else begin
            cur_len <= 0;
            status <= 0;
            lsb_done <= 0;
            mem_wr <= 0;
            mem_a <= 0;
            
          end
        end
        2'b11: begin//store
          if ( !io_buffer_full|| store_addr[17:16] != 2'b11) begin
            mem_wr <= 1;
            case (cur_len)
              0: mem_dout <= lsb_w_data[7:0];
              1: mem_dout <= lsb_w_data[15:8];
              2: mem_dout <= lsb_w_data[23:16];
              3: mem_dout <= lsb_w_data[31:24];
            endcase
            if (cur_len != 0) begin
              mem_a <= mem_a + 1;
              
            end
            else begin
              mem_a <= store_addr;
            end
            if (cur_len != len) begin
              cur_len <= cur_len + 1;
              
            end else begin
              cur_len <= 0;
              status <= 0;
              lsb_done <= 1;
              mem_wr <= 0;
              mem_a <= 0;
              
            end
          end
        end
        2'b00: begin
          if (if_done || lsb_done) begin
            if_done  <= 0;
            lsb_done <= 0;
          end else if (!rollback) begin
            if (if_en) begin
              cur_len  <= 0;
              len    <= 64;
              status <= 1;
              mem_a  <= if_pc;
              
              
            end else if (lsb_en) begin
              if (lsb_wr) begin
                status <= 3;
                store_addr <= lsb_addr;
              end else begin
                status <= 2;
                mem_a <= lsb_addr;
                lsb_r_data <= 0;
              end
              cur_len <= 0;
              len   <= {4'b0, lsb_len};
            end
          end
        end
      endcase
    end
  end
endmodule
`endif