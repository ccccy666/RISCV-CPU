`ifndef CONSTANT
`define CONSTANT

`define OPCODE_JAL 7'b1101111
`define OPCODE_JALR 7'b1100111
`define OPCODE_BR 7'b1100011
`define OPCODE_L 7'b0000011
`define OPCODE_S 7'b0100011
`define OPCODE_CALCI 7'b0010011
`define OPCODE_CALC 7'b0110011
`define OPCODE_LUI 7'b0110111
`define OPCODE_AUIPC 7'b0010111

`define FUNCT3_ADD 3'h0
`define FUNCT3_SUB 3'h0
`define FUNCT3_XOR 3'h4
`define FUNCT3_OR 3'h6
`define FUNCT3_AND 3'h7
`define FUNCT3_SLL 3'h1
`define FUNCT3_SRL 3'h5
`define FUNCT3_SRA 3'h5
`define FUNCT3_SLT 3'h2
`define FUNCT3_SLTU 3'h3


`define FUNCT3_ADDI 3'h0
`define FUNCT3_XORI 3'h4
`define FUNCT3_ORI 3'h6
`define FUNCT3_ANDI 3'h7
`define FUNCT3_SLLI 3'h1
`define FUNCT3_SRLI 3'h5
`define FUNCT3_SRAI 3'h5
`define FUNCT3_SLTI 3'h2
`define FUNCT3_SLTUI 3'h3


`define FUNCT3_LB 3'h0
`define FUNCT3_LH 3'h1
`define FUNCT3_LW 3'h2
`define FUNCT3_LBU 3'h4
`define FUNCT3_LHU 3'h5

`define FUNCT3_SB 3'h0
`define FUNCT3_SH 3'h1
`define FUNCT3_SW 3'h2

`define FUNCT3_BEQ 3'h0
`define FUNCT3_BNE 3'h1
`define FUNCT3_BLT 3'h4
`define FUNCT3_BGE 3'h5
`define FUNCT3_BLTU 3'h6
`define FUNCT3_BGEU 3'h7

`endif // constant