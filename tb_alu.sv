`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/28/2026 09:59:47 AM
// Design Name: 
// Module Name: tb_b_computation_alu
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_b_computation_alu;

    // Inputs to DUT
    logic signed [14:0] ip_operand_a;
    logic signed [14:0] ip_operand_b;
    logic [3:0]         ip_operator_sel;
    logic [3:0]         ip_sub_operator;
    logic [13:0]        ip_pass_through;
    logic               ip_pass_sign;
    logic [2:0]         ip_status;
    logic               ip_execute;

    // Outputs from DUT
    logic signed [14:0] op_result;
    logic [2:0]         op_status;

    // Status constants
    localparam STAT_NORMAL  = 3'b000;
    localparam STAT_PASS    = 3'b001;
    localparam STAT_SHOW_OP = 3'b010;
    localparam STAT_ERR_DIV = 3'b011;
    localparam STAT_ERR_SEQ = 3'b100;
    localparam STAT_OVF     = 3'b101;

    // Instantiate DUT
    alu uut (
        .ip_operand_a    (ip_operand_a),
        .ip_operand_b    (ip_operand_b),
        .ip_operator_sel (ip_operator_sel),
        .ip_sub_operator (ip_sub_operator),
        .ip_pass_through (ip_pass_through),
        .ip_pass_sign    (ip_pass_sign),
        .ip_status       (ip_status),
        .ip_execute      (ip_execute),
        .op_result       (op_result),
        .op_status       (op_status)
    );

    initial begin
        // Default initial values
        ip_operand_a     = 15'sd0;
        ip_operand_b     = 15'sd0;
        ip_operator_sel  = 4'h0;
        ip_sub_operator  = 4'h0;
        ip_pass_through  = 14'd0;
        ip_pass_sign     = 1'b0;
        ip_status        = STAT_NORMAL;
        ip_execute       = 1'b0;

        #10;

        // =====================================================
        // Test Case 1: Input Pass-Through
        // Expected:
        // op_result = 15'b0_0000_0000_001010
        // op_status = 3'b001
        // =====================================================
        ip_status       = STAT_PASS;
        ip_pass_sign    = 1'b0;
        ip_pass_through = 14'd10;
        ip_execute      = 1'b0;
        #10;

        // =====================================================
        // Test Case 2: Operator Display
        // Expected:
        // op_result = 15'd10 / 15'h000A
        // op_status = 3'b010
        // =====================================================
        ip_status       = STAT_SHOW_OP;
        ip_pass_sign    = 1'b0;
        ip_pass_through = 14'h000A;
        ip_execute      = 1'b0;
        ip_operator_sel = 4'hA;
        #10;

        // =====================================================
        // Test Case 3: Addition Normal
        // 20 + 15 = 35
        // Expected:
        // op_result = 15'd35
        // op_status = 3'b000
        // =====================================================
        ip_status       = STAT_NORMAL;
        ip_execute      = 1'b1;
        ip_operator_sel = 4'hA;
        ip_operand_a    = 15'sd20;
        ip_operand_b    = 15'sd15;
        #10;

        // =====================================================
        // Test Case 4: Subtraction Negative Result
        // 10 - 15 = -5
        // Expected:
        // op_result = -15'sd5
        // op_status = 3'b000
        // =====================================================
        ip_status       = STAT_NORMAL;
        ip_execute      = 1'b1;
        ip_operator_sel = 4'hB;
        ip_operand_a    = 15'sd10;
        ip_operand_b    = 15'sd15;
        #10;

        // =====================================================
        // Test Case 5: Division by Zero Error
        // 50 / 0
        // Expected:
        // op_result = 15'd0
        // op_status = 3'b011
        // =====================================================
        ip_status       = STAT_NORMAL;
        ip_execute      = 1'b1;
        ip_operator_sel = 4'hD;
        ip_operand_a    = 15'sd50;
        ip_operand_b    = 15'sd0;
        #10;

        // =====================================================
        // Test Case 6: Addition Overflow
        // 16380 + 10 exceeds signed 15-bit / display range
        // Expected:
        // op_status = 3'b101
        // op_result may be 0 or invalid because overflow state is active
        // =====================================================
        ip_status       = STAT_NORMAL;
        ip_execute      = 1'b1;
        ip_operator_sel = 4'hA;
        ip_operand_a    = 15'sd16380;
        ip_operand_b    = 15'sd10;
        #10;

        // =====================================================
        // Test Case 7: Sequence Error Override
        // Expected:
        // op_status = 3'b100
        // =====================================================
        ip_status       = STAT_ERR_SEQ;
        ip_execute      = 1'b1;
        ip_operator_sel = 4'hA;
        ip_operand_a    = 15'sd10;
        ip_operand_b    = 15'sd5;
        #10;

        // =====================================================
        // Test Case 8: Idle / Wait
        // Expected:
        // op_result = 15'd0
        // op_status = 3'b000
        // =====================================================
        ip_status       = STAT_NORMAL;
        ip_execute      = 1'b0;
        ip_operator_sel = 4'hA;
        ip_operand_a    = 15'sd10;
        ip_operand_b    = 15'sd5;
        #10;

        $finish;
    end

endmodule