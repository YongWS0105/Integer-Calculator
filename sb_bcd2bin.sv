`timescale 1ns / 1ps
//##############################################################
/*
Project/Module : bcd2bin
File name      : bcd2bin.sv
Author         : Lim Chun Sin
Description    : Submodule - Converts up to four 4-bit BCD digits 
                 into a single 14-bit binary magnitude.
*/
//##############################################################

module bcd2bin (
    input  logic [3:0]  ip_digit_3,   // Thousands
    input  logic [3:0]  ip_digit_2,   // Hundreds
    input  logic [3:0]  ip_digit_1,   // Tens
    input  logic [3:0]  ip_digit_0,   // Ones
    input  logic [2:0]  ip_digit_cnt, // Number of digits entered
    output logic [13:0] op_bin_val
);

    logic [13:0] w_val_0, w_val_1, w_val_2, w_val_3;

    always_comb begin
        // Pad the 4-bit BCD data to 14-bits to prevent overflow during multiplication
        w_val_0 = {10'd0, ip_digit_0};
        w_val_1 = {10'd0, ip_digit_1};
        w_val_2 = {10'd0, ip_digit_2};
        w_val_3 = {10'd0, ip_digit_3};

        // Dynamically calculate binary value based on how many digits were typed.
        // E.g., 3 digits = (Hundreds * 100) + (Tens * 10) + Ones
        case (ip_digit_cnt)
            3'd1: op_bin_val = w_val_0;
            3'd2: op_bin_val = (w_val_0 * 4'd10)   + w_val_1;
            3'd3: op_bin_val = (w_val_0 * 7'd100)  + (w_val_1 * 4'd10)  + w_val_2;
            3'd4: op_bin_val = (w_val_0 * 10'd1000) + (w_val_1 * 7'd100) + (w_val_2 * 4'd10) + w_val_3;
            default: op_bin_val = 14'd0;
        endcase
    end

endmodule