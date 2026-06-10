`timescale 1ns / 1ps
//##############################################################
/*
Project/Module : calc_top
File name      : calc_top.sv
Version        : 1-0 (Integration)
Date created   : 28/04/2026
Author         : Lim Chun Sin
Code type      : RTL / Structural Top-Level
Description    : Top-Level Integration for the 4-digit BCD Integer Calculator.
                 This module instantiates and connects:
                 Block 1: Hex Keypad Scanner
                 Block 2: Input Conversion & Sequencing
                 Block 3: Computation (ALU)
                 Block 4: Output Conversion & Display
*/
//##############################################################

module calc_top (
    // ===================================================================
    // Physical System Clocks & Resets
    // ===================================================================
    input  logic       ip_sys_clk,
    input  logic       ip_sys_reset,

    // ===================================================================
    // Physical Input Pins (Buttons & Keypad)
    // ===================================================================
    input  logic [3:0] ip_calc_keypad_row, // Asynchronous row inputs from keypad
    input  logic       ip_calc_sign,       // Toggle positive/negative button
    input  logic       ip_calc_enter,      // Confirm entry button
    input  logic       ip_calc_clear,      // Hardware clear/reset sequence button

    // ===================================================================
    // Physical Output Pins (LEDs & 7-Segment Display)
    // ===================================================================
    output logic [3:0] op_calc_keypad_col, // Scanning column outputs to keypad
    output logic [6:0] op_calc_seg,        // 7-Segment cathode drivers (A-G)
    output logic [3:0] op_calc_seg_en,     // 7-Segment digit anodes (Active High)
    output logic       op_calc_led_neg,    // LED for negative sign indicator
    output logic       op_calc_led_ovf     // LED for overflow/error indicator
);

    // ===================================================================
    // Internal Interconnects (The "Wires" between blocks)
    // ===================================================================
    
    // Wires from Block 1 (Keypad) to Block 2 (Input Conv)
    logic [3:0] w_key_code;
    logic       w_key_valid;

    // Wires from Block 2 (Input Conv) to Block 3 (ALU)
    logic signed [14:0] w_operand_a;
    logic signed [14:0] w_operand_b;
    logic [3:0]         w_operator_sel;
    logic [3:0]         w_sub_operator;
    logic [13:0]        w_pass_through;
    logic               w_pass_sign;
    logic [2:0]         w_input_status;
    logic               w_execute;

    // Wires from Block 3 (ALU) to Block 4 (Output Conv)
    logic signed [14:0] w_alu_result;
    logic [2:0]         w_alu_status;


    // ===================================================================
    // Block 1 Instantiation: Hex Keypad Scanner
    // ===================================================================
    hex_keypad u_block1_keypad (
        // System
        .ip_sys_clk         (ip_sys_clk),
        .ip_sys_reset       (ip_sys_reset),
        
        // Physical Keypad I/O
        .ip_calc_keypad_row (ip_calc_keypad_row),
        .op_calc_keypad_col (op_calc_keypad_col),
        
        // Output to Block 2
        .op_key_code        (w_key_code),
        .op_key_valid       (w_key_valid)
    );

    // ===================================================================
    // Block 2 Instantiation: Input Conversion & Sequencing
    // ===================================================================
    input_conv u_block2_input (
        // System
        .ip_sys_clk         (ip_sys_clk),
        .ip_sys_reset       (ip_sys_reset),
        
        // Physical Buttons
        .ip_calc_sign       (ip_calc_sign),
        .ip_calc_enter      (ip_calc_enter),
        .ip_calc_clear      (ip_calc_clear),
        
        // Input from Block 1
        .ip_key_code        (w_key_code),
        .ip_key_valid       (w_key_valid),
        
        // Output to Block 3
        .op_operand_a       (w_operand_a),
        .op_operand_b       (w_operand_b),
        .op_operator_sel    (w_operator_sel),
        .op_sub_operator    (w_sub_operator),
        .op_pass_through    (w_pass_through),
        .op_pass_sign       (w_pass_sign),
        .op_status          (w_input_status),
        .op_execute         (w_execute)
    );

    // ===================================================================
    // Block 3 Instantiation: Main ALU Engine
    // ===================================================================
    alu u_block3_alu (
        // Inputs from Block 2
        .ip_operand_a       (w_operand_a),
        .ip_operand_b       (w_operand_b),
        .ip_operator_sel    (w_operator_sel),
        .ip_sub_operator    (w_sub_operator),
        .ip_pass_through    (w_pass_through),
        .ip_pass_sign       (w_pass_sign),
        .ip_status          (w_input_status),
        .ip_execute         (w_execute),
        
        // Outputs to Block 4
        .op_result          (w_alu_result),
        .op_status          (w_alu_status)
    );

    // ===================================================================
    // Block 4 Instantiation: Output Conversion & Display
    // ===================================================================
    output_conv u_block4_output (
        // System
        .ip_sys_clk         (ip_sys_clk),
        .ip_sys_reset       (ip_sys_reset),
        
        // Inputs from Block 3
        .ip_result          (w_alu_result),
        .ip_status          (w_alu_status),
        
        // Physical Display Outputs
        .op_calc_seg        (op_calc_seg),
        .op_calc_seg_en     (op_calc_seg_en),
        .op_calc_led_neg    (op_calc_led_neg),
        .op_calc_led_ovf    (op_calc_led_ovf)
    );

endmodule