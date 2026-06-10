`timescale 1ns / 1ps
//##############################################################
/*
Project/Module : barrel_shifter
File name      : barrel_shifter.sv
Author         : Yong Wei Sheng
Code type      : RTL / Structural Combinational
Description    : Submodule - MUX-based Barrel Shifter.
                 Performs Logical Left (SLL), Logical Right (SRL), 
                 and Arithmetic Right (SRA) shifts without latches 
                 and without using SV shift operators.
*/
//##############################################################
module barrel_shifter
(
    input  logic signed [14:0] ip_data_in,
    input  logic [3:0]         ip_shift_amt, // Extracted from operand B
    input  logic [3:0]         ip_shift_op,  // F0=SLL, F1=SRL, F2=SRA
    output logic signed [14:0] op_data_out
);

    // --- Logical Left Shift (SLL) ---
    // Cascading MUXes shift by powers of 2 (1, 2, 4, 8)
    logic [14:0] sll_1, sll_2, sll_4, sll_8;
    assign sll_1 = ip_shift_amt[0] ? {ip_data_in[13:0], 1'b0} : ip_data_in;
    assign sll_2 = ip_shift_amt[1] ? {sll_1[12:0], 2'b00}     : sll_1;
    assign sll_4 = ip_shift_amt[2] ? {sll_2[10:0], 4'h0}      : sll_2;
    assign sll_8 = ip_shift_amt[3] ? {sll_4[6:0],  8'h00}     : sll_4;

    // --- Logical Right Shift (SRL) ---
    // Pulls in standard 0s from the MSB side
    logic [14:0] srl_1, srl_2, srl_4, srl_8;
    assign srl_1 = ip_shift_amt[0] ? {1'b0,  ip_data_in[14:1]} : ip_data_in;
    assign srl_2 = ip_shift_amt[1] ? {2'b00, srl_1[14:2]}      : srl_1;
    assign srl_4 = ip_shift_amt[2] ? {4'h0,  srl_2[14:4]}      : srl_2;
    assign srl_8 = ip_shift_amt[3] ? {8'h00, srl_4[14:8]}      : srl_4;

    // --- Arithmetic Right Shift (SRA) ---
    // Pulls from the MSB, but copies the original sign bit to preserve negative values
    logic [14:0] sra_1, sra_2, sra_4, sra_8;
    logic        sign_bit;
    assign sign_bit = ip_data_in[14];

    assign sra_1 = ip_shift_amt[0] ? {sign_bit,      ip_data_in[14:1]} : ip_data_in;
    assign sra_2 = ip_shift_amt[1] ? {{2{sign_bit}}, sra_1[14:2]}      : sra_1;
    assign sra_4 = ip_shift_amt[2] ? {{4{sign_bit}}, sra_2[14:4]}      : sra_2;
    assign sra_8 = ip_shift_amt[3] ? {{8{sign_bit}}, sra_4[14:8]}      : sra_4;

    // --- Output Control MUX ---
    always_comb begin
        case (ip_shift_op)
            4'h0: op_data_out = sll_8; // F0 = Logical Left
            4'h1: op_data_out = srl_8; // F1 = Logical Right
            4'h2: op_data_out = sra_8; // F2 = Arithmetic Right
            default: op_data_out = 15'sd0; // Default prevents latches
        endcase
    end

endmodule