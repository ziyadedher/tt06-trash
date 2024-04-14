/*
 * Copyright (c) 2024 Ziyad Edher
 * SPDX-License-Identifier: MIT
 */

`define default_netname none

// input-path IO 0: programming mode
module tt_um_ziyadedher_trash (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
    // Not using uio_out.
    assign uio_out = 0;
    assign uio_oe  = 0;

    wire reset = ! rst_n;

    // 8 bytes of program memory.
    // This can be addressed by 3 bits, which we have a program counter for.
    reg [7:0] program [7:0];
    reg [2:0] pc = 0;

    // 16-byte memory hell yeah.
    // This can be addressed by 4 bits!
    reg [7:0] memory [15:0];

    // 4 8-bit registers.
    // We can reference a specfic register using 2 bits.
    reg [7:0] r0, r1, r2, r3;

    assign in = {ui_in, uio_in};

    // Programming mode.
    // When this is set to 0, the device is in programming mode.
    // When this is set to 1, the device is in execution mode.
    wire prog = in[0];
    
    // PROGRAMMING MODE
    // | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | A | B | C | D | E | F |
    // | 0 |                    DATA TO PROGRAM                        |
    //
    // Every clock cycle, the device will read the 15 bits of data from the input path,
    // and write it to the program memory at the address specified by the program counter.
    // The program counter will increment by 1 every clock cycle.
    always @(posedge clk) begin
        if (reset) begin
            pc <= 0;
        end else if (! prog) begin
            program[pc] <= in[15:1];
            pc <= pc + 1;
        end
    end

    // EXECUTION MODE
    // | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | A | B | C | D | E | F |
    // | 1 | OPERATION |           OPERATION-SPECIFIC DATA             |
    //
    // * NOOP       (0x0)   no operation
    // | 1 |    0x0    |                   <unused>                    |
    // * STORE      (0x1)   stores DATA (1 byte) in REG
    // | 1 |    0x1    |      REG      |              DATA             |
    // * CALC       (0x2)   executes REG_OUT = ALU(OPCODE, REG_IN[7:4], REG_IN[3:0])
    // | 1 |    0x2    |     OPCODE    |     REG_IN    |    REG_OUT    |
    // * MEMSTORE   (0x3)   stores DATA (1 byte) at MEM[ADDR]
    // | 1 |    0x3    |      ADDR     |              DATA             |
    // * MEMLOAD    (0x4)   loads 1 byte of data from MEM[ADDR] to REG
    // | 1 |    0x4    |      ADDR     |      REG      |    <unused>   |
    // * JUMP       (0x5)   jumps to ADDR
    // | 1 |    0x5    |      ADDR     |              <unused>         |
    // * JUMPIF     (0x6)   jumps to ADDR if data at REG_A == data at REG_B
    // | 1 |    0x6    |      ADDR     |     REG_A     |     REG_B     |
    // * OUT        (0x7)   outputs REG to dedicated output
    // | 1 |    0x7    |      REG      |              <unused>         |
    always @(posedge clk) begin
        if (reset) begin
            pc <= 0;
        end else if (prog) begin
            case (in[3:1])
                4'b000 : begin 
                end;
                4'b001 : begin
                    case (in[7:4])
                        2'b0000 : r0 <= in[15:8];
                        2'b0001 : r1 <= in[15:8];
                        2'b0010 : r2 <= in[15:8];
                        2'b0011 : r3 <= in[15:8];
                    endcase
                end;
                4'b010 : begin
                    case (in[15:12])
                        2'b0000 : alu(.clk(clk), .opcode(in[7:4]), .a(r0[7:4]), .b(r0[3:0]), .res(r1[7:0]));
                    endcase
                end;
                // TODO: the rest
                default;
            endcase
            pc <= pc + 1;
        end
    end
endmodule


// 4-bit ALU
module alu (
    input clk,
    input [3:0] opcode,
    input [3:0] a,
    input [3:0] b,
    output [7:0] res,
);
    always @(posedge clk) begin
        case (opcode)
            4'b0000 : op = a + b;
            4'b0001 : op = a - b;
            4'b0010 : op = a * b;
            4'b0011 : op = a / b;
            4'b0100 : op = a % b;
            4'b0101 : op = a & b;
            4'b0110 : op = a | b;
            4'b0111 : op = a && b;
            4'b1000 : op = a || b;
            4'b1001 : op = a ^ b;
            4'b1010 : op = ~ a;  
            4'b1011 : op = ! a;  
            4'b1100 : op = a >> 1;
            4'b1101 : op = a << 1;
            4'b1110 : op = a + 1;
            4'b1111 : op = a - 1;
            default : op = 8'bXXXXXXXX;
        endcase
    end
endmodule