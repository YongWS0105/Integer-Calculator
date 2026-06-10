//##############################################################
/*
Project/Module : adder_15bit
File name      : adder_15bit.sv
Version        : 1-1 (Flattened)
Date created   : 11/04/2026
Author         : Yong Wei Sheng
Code type      : Structural / RTL
Description    : Submodule - 15-bit ripple-carry adder/subtractor.
                 Uses a 'generate' block for clean, structural 
                 full-adder instantiations without verbose coding.
*/
//##############################################################
module adder_15bit
(
    // Outputs
    output logic [14:0] op_sum,
    output logic        op_overflow,

    // Inputs
    input  logic [14:0] ip_a,
    input  logic [14:0] ip_b,
    input  logic        ip_sub_flag // 0 = Addition, 1 = Subtraction
);

    //**********************************************************
    // 1. Internal Carry Routing
    //**********************************************************
    // w_carry[0] feeds the first adder.
    // w_carry[15] is the final carry-out from the MSB adder.
    logic [15:0] w_carry;
    logic [14:0] w_b_in;

    //**********************************************************
    // 2. Two's Complement Inversion (Input B Selection)
    //**********************************************************
    // If subtracting (ip_sub_flag = 1): XOR flips all bits of B (1's complement).
    // If adding (ip_sub_flag = 0): B passes through unchanged.
    assign w_b_in = ip_b ^ {15{ip_sub_flag}};

    // Carry-in for the LSB (+1 for Two's Complement Subtraction)
    assign w_carry[0] = ip_sub_flag;

    //**********************************************************
    // 3. Generate Loop for 15 Full-Adder Stages
    //**********************************************************
    // The compiler unrolls this loop to create physical hardware stages.
    generate
        genvar k; 
        
        for (k = 0; k < 15; k = k + 1) begin : STAGE
            // --- 1-Bit Full Adder ---
            // Sum calculation for the current bit position.
            assign op_sum[k] = ip_a[k] ^ w_b_in[k] ^ w_carry[k];
            
            // Carry-out calculation feeds into the next stage (k+1).
            // Logic: If at least two inputs are '1', generate a carry.
            assign w_carry[k+1] = (ip_a[k] & w_b_in[k]) | (w_b_in[k] & w_carry[k]) | (ip_a[k] & w_carry[k]); 
        end
    endgenerate

    //**********************************************************
    // 4. Signed Overflow Detection
    //**********************************************************
    // In Two's Complement math, structural overflow occurs if the carry 
    // entering the MSB does not match the carry exiting the MSB.
    assign op_overflow = w_carry[14] ^ w_carry[15];

endmodule