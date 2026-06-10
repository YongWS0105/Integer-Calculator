//##############################################################
/*
Project/Module : output_conv
File name      : output_conv.sv
Version        : 1-7 (Single Submodule Architecture)
Author         : Lim Chun Sin
Code type      : RTL / Combinational & Sequential
Description    : Block 4 - Output Conversion & Display routing.
                 Converts ALU results to BCD, manages zero-blanking 
                 for a cleaner human-machine interface, and drives 
                 the time-multiplexed 7-segment display on the FPGA.
*/
//##############################################################

module output_conv (
    input  logic               ip_sys_clk,
    input  logic               ip_sys_reset,
    
    // Inputs from Block 3 (ALU Engine)
    input  logic signed [14:0] ip_result,   
    input  logic [2:0]         ip_status,   
    
    // Outputs to Physical FPGA Pins
    output logic [6:0]         op_calc_seg,     // 7-Segment cathode drivers
    output logic [3:0]         op_calc_seg_en,  // Digit anodes (active high)
    output logic               op_calc_led_neg, // Negative sign LED
    output logic               op_calc_led_ovf  // Overflow warning LED
);

    // ===================================================================
    // 1. Status Codes & Special Display Characters
    // ===================================================================
    localparam STAT_NORMAL  = 3'b000; 
    localparam STAT_PASS    = 3'b001; 
    localparam STAT_SHOW_OP = 3'b010; 
    localparam STAT_ERR_DIV = 3'b011; 
    localparam STAT_ERR_SEQ = 3'b100; 
    localparam STAT_OVF     = 3'b101; 

    // Custom non-hex characters mapped beyond 0-F
    localparam CHAR_BLANK = 5'd16;
    localparam CHAR_DASH  = 5'd17;
    localparam CHAR_r     = 5'd18;

    // ===================================================================
    // 2. Submodule Instantiation: Binary to BCD
    // ===================================================================
    logic [15:0] w_bcd_data;
    logic [13:0] w_binary_mag;
    
    // Extract absolute magnitude: If negative, invert and add 1 (Two's Complement)
    assign w_binary_mag = ip_result[14] ? (~ip_result[13:0] + 1'b1) : ip_result[13:0];

    // Convert the 14-bit binary magnitude into four 4-bit BCD digits
    bin2bcd u_double_dabble (
        .ip_binary_mag (w_binary_mag),
        .op_bcd_data   (w_bcd_data)
    );

    // ===================================================================
    // 3. Display Content Multiplexer (The Screen Router)
    // ===================================================================
    logic [4:0] w_digit_3, w_digit_2, w_digit_1, w_digit_0;
    logic hide_3, hide_2, hide_1;

    // Zero-Blanking Logic: Hides leading zeros to improve UI readability.
    // Example: Displays "  12" instead of "0012".
    assign hide_3 = (w_bcd_data[15:12] == 4'h0);
    assign hide_2 = hide_3 & (w_bcd_data[11:8] == 4'h0);
    assign hide_1 = hide_2 & (w_bcd_data[7:4]  == 4'h0);

    always_comb begin
        // By default, load the BCD numbers into the digit slots
        w_digit_3 = {1'b0, w_bcd_data[15:12]};
        w_digit_2 = {1'b0, w_bcd_data[11:8]};
        w_digit_1 = {1'b0, w_bcd_data[7:4]};
        w_digit_0 = {1'b0, w_bcd_data[3:0]};

        unique case (ip_status)
            STAT_NORMAL, STAT_PASS: begin
                // Apply zero-blanking if in normal or typing modes
                w_digit_3 = hide_3 ? CHAR_BLANK : w_digit_3;
                w_digit_2 = hide_2 ? CHAR_BLANK : w_digit_2;
                w_digit_1 = hide_1 ? CHAR_BLANK : w_digit_1;
            end
            STAT_SHOW_OP: begin
                // Display the operator code on the rightmost digits
                w_digit_3 = CHAR_BLANK;
                w_digit_2 = CHAR_BLANK;
                w_digit_1 = {1'b0, ip_result[7:4]}; 
                w_digit_0 = {1'b0, ip_result[3:0]}; 
            end
            STAT_OVF: begin
                // Show "----" for overflow
                w_digit_3 = CHAR_DASH;
                w_digit_2 = CHAR_DASH;
                w_digit_1 = CHAR_DASH;
                w_digit_0 = CHAR_DASH;
            end
            STAT_ERR_DIV, STAT_ERR_SEQ: begin
                // Show "E rr" for division by zero or sequence errors
                w_digit_3 = CHAR_BLANK;
                w_digit_2 = 5'hE;
                w_digit_1 = CHAR_r;
                w_digit_0 = CHAR_r;
            end
            default: begin end
        endcase
    end

    // ===================================================================
    // 4. Time-Multiplexing Scanner
    // ===================================================================
    // To save FPGA pins, we only turn on one 7-segment digit at a time.
    // We cycle through them so fast that human persistence of vision 
    // makes them all appear to be on simultaneously.
    logic [17:0] r_refresh_cnt; 
    logic [1:0]  w_active_digit;

    always_ff @(posedge ip_sys_clk) begin
        if (ip_sys_reset) begin
            r_refresh_cnt <= 18'd0;
        end else begin
            r_refresh_cnt <= r_refresh_cnt + 1'b1;
        end
    end
    
    // Use the top 2 bits of the counter to select the active digit (0, 1, 2, 3)
    assign w_active_digit = r_refresh_cnt[17:16];
    
    // Active-High digit enable: Shift a '1' to the correct anode position
    assign op_calc_seg_en = 4'b0001 << w_active_digit; 

    logic [4:0] w_current_char;
    always_comb begin
        unique case (w_active_digit)
            2'b00:   w_current_char = w_digit_0; 
            2'b01:   w_current_char = w_digit_1; 
            2'b10:   w_current_char = w_digit_2; 
            2'b11:   w_current_char = w_digit_3; 
        endcase
    end

    // ===================================================================
    // 5. Inline 7-Segment Hex Decoder (Active High)
    // ===================================================================
    always_comb begin
        unique case (w_current_char)
            // Standard Hexadecimal (0-F)
            5'h0:       op_calc_seg = 7'b1111110; 
            5'h1:       op_calc_seg = 7'b0110000; 
            5'h2:       op_calc_seg = 7'b1101101; 
            5'h3:       op_calc_seg = 7'b1111001; 
            5'h4:       op_calc_seg = 7'b0110011; 
            5'h5:       op_calc_seg = 7'b1011011; 
            5'h6:       op_calc_seg = 7'b1011111; 
            5'h7:       op_calc_seg = 7'b1110000; 
            5'h8:       op_calc_seg = 7'b1111111; 
            5'h9:       op_calc_seg = 7'b1111011; 
            5'hA:       op_calc_seg = 7'b1110111; 
            5'hB:       op_calc_seg = 7'b0011111; 
            5'hC:       op_calc_seg = 7'b1001110; 
            5'hD:       op_calc_seg = 7'b0111101; 
            5'hE:       op_calc_seg = 7'b1001111; 
            5'hF:       op_calc_seg = 7'b1000111; 
            
            // Custom Status Characters
            CHAR_DASH:  op_calc_seg = 7'b0000001; // Center segment only
            CHAR_r:     op_calc_seg = 7'b0000101; // Lower half 'r'
            CHAR_BLANK: op_calc_seg = 7'b0000000; // All segments off
            
            default:    op_calc_seg = 7'b0000000;
        endcase
    end

    // ===================================================================
    // 6. LED Status Indicators
    // ===================================================================
    // Drive the negative LED if we have a valid result and the MSB (sign bit) is 1.
    assign op_calc_led_neg = ((ip_status == STAT_NORMAL || ip_status == STAT_PASS) && ip_result[14]);
    
    // Drive the overflow LED if the ALU throws an OVF status.
    assign op_calc_led_ovf = (ip_status == STAT_OVF);

endmodule