`timescale 1ns / 1ps
//##############################################################
/*
Project/Module : bin2bcd
File name      : bin2bcd.sv
Author         : Lim Chun Sin
Description    : Submodule - Converts 14-bit binary magnitude to 
                 16-bit BCD using the Double Dabble (Shift-Add-3) algorithm.
*/
//##############################################################

module bin2bcd (
    input  logic [13:0] ip_binary_mag,
    output logic [15:0] op_bcd_data
);

    always_comb begin
        op_bcd_data = 16'd0;
        
        // LECTURER NOTE: This uses a serial 'for' loop structure. 
        // Instead of a clocked sequential state machine, this loop is unrolled 
        // by the synthesizer into a long, cascading chain of combinational logic.
        // It processes the conversion serially bit-by-bit from MSB to LSB.
        for (int i = 13; i >= 0; i--) begin
            // If any BCD digit is >= 5, add 3. This corrects the binary-to-decimal
            // alignment before the next shift occurs.
            if (op_bcd_data[3:0]   >= 5) op_bcd_data[3:0]   = op_bcd_data[3:0]   + 3;
            if (op_bcd_data[7:4]   >= 5) op_bcd_data[7:4]   = op_bcd_data[7:4]   + 3;
            if (op_bcd_data[11:8]  >= 5) op_bcd_data[11:8]  = op_bcd_data[11:8]  + 3;
            if (op_bcd_data[15:12] >= 5) op_bcd_data[15:12] = op_bcd_data[15:12] + 3;
            
            // Shift the entire BCD register left by 1, pulling in the next binary bit
            op_bcd_data = {op_bcd_data[14:0], ip_binary_mag[i]};
        end
    end

endmodule