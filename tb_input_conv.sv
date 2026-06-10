`timescale 1ns / 1ps
//##############################################################
/*
Project/Module : tb_input_conv
File name      : tb_input_conv.sv
Author         : Lim Chun Sin
Description    : Testbench for Block 2 (Input Conversion).
                 Verifies FSM sequencing, 2-stage button syncs, 
                 and error state trapping.
*/
//##############################################################

module tb_input_conv();

    // ===================================================================
    // 1. Signal Declarations
    // ===================================================================
    logic        clk;
    logic        reset;
    
    logic        sign_btn;
    logic        enter_btn;
    logic        clear_btn;
    
    logic [3:0]  key_code;
    logic        key_valid;
    
    logic signed [14:0] op_a;
    logic signed [14:0] op_b;
    logic [3:0]  op_sel;
    logic [3:0]  sub_op;
    logic [13:0] pass_through;
    logic        pass_sign;
    logic [2:0]  status;
    logic        execute;

    // ===================================================================
    // 2. DUT Instantiation
    // ===================================================================
    input_conv dut (
        .ip_sys_clk      (clk),
        .ip_sys_reset    (reset),
        .ip_calc_sign    (sign_btn),
        .ip_calc_enter   (enter_btn),
        .ip_calc_clear   (clear_btn),
        .ip_key_code     (key_code),
        .ip_key_valid    (key_valid),
        .op_operand_a    (op_a),
        .op_operand_b    (op_b),
        .op_operator_sel (op_sel),
        .op_sub_operator (sub_op),
        .op_pass_through (pass_through),
        .op_pass_sign    (pass_sign),
        .op_status       (status),
        .op_execute      (execute)
    );

    // ===================================================================
    // 3. Clock Generation (100MHz)
    // ===================================================================
    always #5 clk = ~clk;

    // ===================================================================
    // 4. Automated Helper Tasks
    // ===================================================================
    task apply_reset();
        begin
            reset = 1'b1; repeat(2) @(posedge clk);
            reset = 1'b0; repeat(2) @(posedge clk);
        end
    endtask

    // Simulates a 1-cycle valid pulse coming from Block 1
    task send_key(input [3:0] code);
        begin
            key_code  = code;
            key_valid = 1'b1;
            @(posedge clk); // Hold for exactly 1 clock cycle
            key_valid = 1'b0;
            repeat(4) @(posedge clk); // Gap between simulated keypresses
        end
    endtask

    // Simulates physical button presses requiring 2-stage sync detection
    task press_button(input int btn_type); // 0=Enter, 1=Sign, 2=Clear
        begin
            if (btn_type == 0) enter_btn = 1'b1;
            if (btn_type == 1) sign_btn = 1'b1;
            if (btn_type == 2) clear_btn = 1'b1;
            
            repeat(4) @(posedge clk); // Hold physical button down
            
            enter_btn = 1'b0; sign_btn = 1'b0; clear_btn = 1'b0;
            repeat(10) @(posedge clk); // Wait for sync registers and edge detector to process
        end
    endtask

    // ===================================================================
    // 5. Main Test Sequence 
    // ===================================================================
    initial begin
        clk = 0; reset = 0;
        sign_btn = 0; enter_btn = 0; clear_btn = 0;
        key_code = 0; key_valid = 0;

        #100; // Global wait

        // -----------------------------------------------------------
        // TC1: Reset State
        // Estimated Simulation Timeline: ~100ns to ~140ns
        // -----------------------------------------------------------
        $display("TC1: Reset");
        apply_reset();

        // -----------------------------------------------------------
        // TC2: Digit Entry (Operand A)
        // Estimated Simulation Timeline: ~140ns to ~200ns
        // -----------------------------------------------------------
        $display("TC2: Enter Digit A (5)");
        send_key(4'h5);

        // -----------------------------------------------------------
        // TC9: Toggle Sign Button 
        // (Moved up slightly to test sign logic while typing A)
        // Estimated Simulation Timeline: ~200ns to ~340ns
        // -----------------------------------------------------------
        $display("TC9: Toggle Sign");
        press_button(1); // Press Sign

        // -----------------------------------------------------------
        // Lock in Operand A (Needed to test TC3)
        // -----------------------------------------------------------
        press_button(0); // Press Enter

        // -----------------------------------------------------------
        // TC3: Operator Selection
        // Estimated Simulation Timeline: ~340ns to ~390ns
        // -----------------------------------------------------------
        $display("TC3: Select Operator A");
        send_key(4'hA); // FSM goes to S_GET_B

        // -----------------------------------------------------------
        // TC4: Digit Entry (Operand B)
        // Estimated Simulation Timeline: ~390ns to ~440ns
        // -----------------------------------------------------------
        $display("TC4: Enter Digit B (3)");
        send_key(4'h3);

        // -----------------------------------------------------------
        // TC8: Button Sync & Execute
        // Estimated Simulation Timeline: ~440ns to ~580ns
        // -----------------------------------------------------------
        $display("TC8: Execute Calculation");
        press_button(0); // Press Enter in S_GET_B triggers S_EXECUTE

        // -----------------------------------------------------------
        // TC5: Error: Invalid Sequence
        // Estimated Simulation Timeline: ~580ns to ~770ns
        // -----------------------------------------------------------
        $display("TC5: Invalid Sequence (Number instead of Operator)");
        apply_reset();
        send_key(4'h5);  // Type A
        press_button(0); // Enter (Now in S_GET_OP)
        send_key(4'h5);  // INVALID: Typing a number while expecting an operator -> S_ERROR
        
        // Wait and clear the error using the hardware clear button
        repeat(10) @(posedge clk);
        press_button(2); // Press Clear

        // -----------------------------------------------------------
        // TC6: Sub-Operator Start & Entry
        // Estimated Simulation Timeline: ~770ns to ~970ns
        // -----------------------------------------------------------
        $display("TC6: Complex Sub-Operator Entry");
        send_key(4'h5);  // Type A
        press_button(0); // Enter (Now in S_GET_OP)
        send_key(4'hE);  // Select Bitwise (Transitions to S_WAIT_SUB_OP)
        send_key(4'h1);  // Sub-op 1 (OR) (Transitions to S_GET_B)

        // -----------------------------------------------------------
        // TC7: Error: Invalid Sub-Op Key
        // Estimated Simulation Timeline: ~970ns to ~1160ns
        // -----------------------------------------------------------
        $display("TC7: Invalid Sub-Op Key");
        press_button(2); // Press clear to start over
        send_key(4'h5);  // Type A
        press_button(0); // Enter (Now in S_GET_OP)
        send_key(4'hF);  // Select Shift (Transitions to S_WAIT_SUB_OP)
        send_key(4'h9);  // INVALID: '9' is not a valid shift sub-op -> S_ERROR

        repeat(20) @(posedge clk);
        $display("=== All Block 2 Test Cases Completed ===");
        $finish;
    end

endmodule