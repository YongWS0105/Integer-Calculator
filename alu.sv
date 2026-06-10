`timescale 1ns / 1ps
//##############################################################
/*
Project/Module : comp_alu
File name      : alu.sv
Version        : 1-3 (Refactored Shifter)
Date created   : 11/04/2026
Author         : Yong Wei Sheng
Code type      : RTL / Structural Combinational
Description    : Block 3 - Main ALU Engine. 
                 Instantiates the 15-bit adder and barrel shifter.
                 Contains division-by-zero protection and hardware 
                 overflow detection.
*/
//##############################################################
module alu 
(
    // Inputs from Block 2 (Input Conversion)
    input  logic signed [14:0] ip_operand_a,
    input  logic signed [14:0] ip_operand_b,
    input  logic [3:0]         ip_operator_sel,
    input  logic [3:0]         ip_sub_operator,
    input  logic [13:0]        ip_pass_through,   
    input  logic               ip_pass_sign,
    input  logic [2:0]         ip_status,
    input  logic               ip_execute,

    // Outputs to Block 4 (Output Conversion & Display)
    output logic signed [14:0] op_result,
    output logic [2:0]         op_status
);

    //**********************************************************
    // 1. Status Constants (FSM Tracking)
    //**********************************************************
    localparam STAT_NORMAL  = 3'b000;
    localparam STAT_PASS    = 3'b001;
    localparam STAT_SHOW_OP = 3'b010;
    localparam STAT_ERR_DIV = 3'b011;
    localparam STAT_ERR_SEQ = 3'b100;
    localparam STAT_OVF     = 3'b101;

    //**********************************************************
    // 2. Structural Addition / Subtraction
    //**********************************************************
    logic signed [14:0] w_addsub_res; 
    logic               w_addsub_ovf;
    logic               w_is_sub;

    assign w_is_sub = (ip_operator_sel == 4'hB);

    adder_15bit u_adder_subtractor (
        .op_sum      (w_addsub_res),
        .op_overflow (w_addsub_ovf),
        .ip_a        (ip_operand_a),
        .ip_b        (ip_operand_b),
        .ip_sub_flag (w_is_sub)
    );

    //**********************************************************
    // 3. Algorithmic Math (Multiplication & Division)
    //**********************************************************
    logic signed [29:0] w_mul_res;
    logic signed [14:0] w_div_res;
    logic               w_err_div_zero;

    assign w_mul_res      = ip_operand_a * ip_operand_b;
    assign w_err_div_zero = (ip_operand_b == 15'sd0);
    assign w_div_res      = w_err_div_zero ? 15'sd0  : (ip_operand_a / ip_operand_b);

    //**********************************************************
    // 4. Bitwise Logic
    //**********************************************************
    logic signed [14:0] w_and_res, w_or_res, w_xor_res;

    assign w_and_res = ip_operand_a & ip_operand_b;
    assign w_or_res  = ip_operand_a | ip_operand_b;
    assign w_xor_res = ip_operand_a ^ ip_operand_b;

    //**********************************************************
    // 5. Custom Barrel Shifter Submodule
    //**********************************************************
    logic signed [14:0] w_shift_res;

    // Submodule Instantiation
    barrel_shifter u_shifter (
        .ip_data_in   (ip_operand_a),
        .ip_shift_amt (ip_operand_b[3:0]), // Only need lower 4 bits for shift amount
        .ip_shift_op  (ip_sub_operator),
        .op_data_out  (w_shift_res)
    );

    //**********************************************************
    // 6. The Core ALU Multiplexer
    //**********************************************************
    logic signed [14:0] w_alu_final_val;
    logic               w_err_overflow;

    always_comb begin
        w_alu_final_val = 15'sd0;
        w_err_overflow  = 1'b0;

        case (ip_operator_sel)
            // A & B: Addition / Subtraction
            4'hA, 4'hB: begin
                w_alu_final_val = w_addsub_res;
                if (w_addsub_ovf || w_addsub_res > 15'sd9999 || w_addsub_res < -15'sd9999) begin
                    w_err_overflow = 1'b1;
                end
            end

            // C: Multiplication
            4'hC: begin
                w_alu_final_val = w_mul_res[14:0];
                if (w_mul_res > 30'sd9999 || w_mul_res < -30'sd9999) begin
                    w_err_overflow = 1'b1;
                end
            end

            // D: Division
            4'hD: begin
                w_alu_final_val = w_div_res;
                if (w_div_res > 15'sd9999 || w_div_res < -15'sd9999) begin
                    w_err_overflow = 1'b1;
                end
            end

            // E: Bitwise Operations
            4'hE: begin
                case (ip_sub_operator)
                    4'h0: w_alu_final_val = w_and_res;
                    4'h1: w_alu_final_val = w_or_res; 
                    4'h2: w_alu_final_val = w_xor_res;
                    default: w_alu_final_val = 15'sd0;
                endcase
                if (w_alu_final_val > 15'sd9999 || w_alu_final_val < -15'sd9999) begin
                    w_err_overflow = 1'b1;
                end
            end

            // F: Shift Operations (Routed from new Submodule)
            4'hF: begin
                w_alu_final_val = w_shift_res;
                if (w_alu_final_val > 15'sd9999 || w_alu_final_val < -15'sd9999) begin
                    w_err_overflow = 1'b1;
                end
            end

            default: begin
                w_alu_final_val = 15'sd0;
                w_err_overflow  = 1'b0;
            end
        endcase
    end

    //**********************************************************
    // 7. Final Output Control MUX
    //**********************************************************
    always_comb begin
        op_result = 15'sd0;
        op_status = ip_status;

        if (ip_status == STAT_PASS) begin
            // While typing: Convert Sign + Magnitude into proper Two's Complement
            op_result = ip_pass_sign ? (~{1'b0, ip_pass_through} + 1'b1) : {1'b0, ip_pass_through};
        end
        else if (ip_status == STAT_SHOW_OP) begin
            op_result = {1'b0, ip_pass_through};
        end
        else if (ip_status == STAT_ERR_SEQ) begin
            op_status = STAT_ERR_SEQ;
        end
        else if (ip_execute) begin
            if (ip_operator_sel == 4'hD && w_err_div_zero) begin
                op_status = STAT_ERR_DIV; 
            end
            else if (w_err_overflow) begin
                op_status = STAT_OVF;     
            end
            else begin
                op_status = STAT_NORMAL;  
                op_result = w_alu_final_val;
            end
        end
    end

endmodule