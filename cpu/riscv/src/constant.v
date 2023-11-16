`ifndef CONSTANT
`define CONSTANT


`define INST_WID 31:0
`define DATA_WID 31:0
`define ADDR_WID 31:0

// Instruction Cache
// total size 1024 Bytes
`define ICACHE_BLK_NUM 16
`define ICACHE_BLK_SIZE 64  // Bytes (16 instructions)
`define ICACHE_BLK_WID 511:0  // ICACHE_BLK_SIZE*8 - 1 : 0
`define ICACHE_BS_RANGE 5:2
`define ICACHE_BS_WID 3:0
`define ICACHE_IDX_RANGE 9:6
`define ICACHE_IDX_WID 3:0
`define ICACHE_TAG_RANGE 31:10
`define ICACHE_TAG_WID 21:0

`define MEM_CTRL_LEN_WID 6:0  // 2^6 = 64 = ICACHE_BLK_SIZE
`define MEM_CTRL_IF_DATA_LEN 64  // ICACHE_BLK_SIZE
`define IF_DATA_WID 511:0  // = ICACHE_BLK_WID
`define INST_SIZE 4

`endif // constant