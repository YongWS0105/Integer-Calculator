`timescale 1ns / 1ps
//##############################################################
/*
Project/Module : tb_hex_keypad
File name      : tb_hex_keypad.sv
Author         : Lim Chun Sin
Description    : Testbench for Block 1 (Hex Keypad Generator).
                 Executes Test Cases 1 through 6 from the Verification Spec.
*/
//##############################################################

module tb_hex_keypad();

    // ===================================================================
    // 1. Signal Declarations
    // ===================================================================
    logic       clk;
    logic       reset;
    logic [3:0] row_in;
    
    logic [3:0] col_out;
    logic [3:0] key_code;
    logic       key_valid;

    // ===================================================================
    // 2. DUT (Device Under Test) Instantiation
    // ===================================================================
    hex_keypad dut (
        .ip_sys_clk         (clk),
        .ip_sys_reset       (reset),
        .ip_calc_keypad_row (row_in),
        .op_calc_keypad_col (col_out),
        .op_key_code        (key_code),
        .op_key_valid       (key_valid)
    );

    // ===================================================================
    // 3. Clock Generation (100MHz)
    // ===================================================================
    always #5 clk = ~clk; // 10ns period

    // ===================================================================
    // 4. Main Test Sequence (Your Test Plan)
    // ===================================================================
    initial begin
        // Initialize inputs
        clk    = 0;
        reset  = 0;
        row_in = 4'b0000;

        // Global wait for simulator stabilization
        #100;

        // -----------------------------------------------------------
        // TEST CASE 1: Reset state
        // -----------------------------------------------------------
        $display("--- Running TC1: Reset state ---");
        reset  = 1'b1;
        row_in = 4'b0000;
        @(posedge clk); // Hold for at least 1 clock cycle
        @(posedge clk);
        reset  = 1'b0;
        
        // Wait a bit to observe initial state
        repeat(5) @(posedge clk);


        // -----------------------------------------------------------
        // TEST CASE 2: Idle scanning
        // -----------------------------------------------------------
        $display("--- Running TC2: Idle scanning ---");
        // Keep reset = 0, row_in = 0000. 
        // Observe col_out rotate 0001 -> 0010 -> 0100 -> 1000 in waveform
        repeat(30) @(posedge clk); 


        // -----------------------------------------------------------
        // TEST CASE 3: Key press Hex 0 (Row 1, Col 1)
        // -----------------------------------------------------------
        $display("--- Running TC3: Key press Hex 0 ---");
        reset = 1'b1; @(posedge clk); reset = 1'b0; // Apply reset
        
        wait(col_out == 4'b0001); // Wait until scanner is at col 1
        
        row_in = 4'b0001; // Set row 1
        // Hold stable for > debounce period (DUT DEBOUNCE_MAX is 5)
        repeat(20) @(posedge clk); 
        
        row_in = 4'b0000; // Return to 0
        repeat(10) @(posedge clk); // Wait to observe release


        // -----------------------------------------------------------
        // TEST CASE 4: Key press Hex 8 (Row 3, Col 1)
        // -----------------------------------------------------------
        $display("--- Running TC4: Key press Hex 8 ---");
        reset = 1'b1; @(posedge clk); reset = 1'b0; 
        
        wait(col_out == 4'b0001); // Wait until scanner is at col 1
        
        row_in = 4'b0100; // Set row 3
        repeat(20) @(posedge clk); // Hold stable
        
        row_in = 4'b0000; 
        repeat(10) @(posedge clk);


        // -----------------------------------------------------------
        // TEST CASE 5: Key press Hex F (Row 4, Col 4)
        // -----------------------------------------------------------
        $display("--- Running TC5: Key press Hex F ---");
        reset = 1'b1; @(posedge clk); reset = 1'b0; 
        
        wait(col_out == 4'b1000); // Wait until scanner is at col 4
        
        row_in = 4'b1000; // Set row 4
        repeat(20) @(posedge clk); // Hold stable
        
        row_in = 4'b0000; 
        repeat(10) @(posedge clk);


        // -----------------------------------------------------------
        // TEST CASE 6: Debounce rejection (short glitch)
        // -----------------------------------------------------------
        $display("--- Running TC6: Debounce rejection ---");
        reset = 1'b1; @(posedge clk); reset = 1'b0; 
        
        wait(col_out == 4'b0010); // Wait until scanner is at col 2
        
        row_in = 4'b0001; // Glitch occurs on row 1
        
        // Hold for LESS than the debounce period (e.g., 2 clock cycles)
        repeat(2) @(posedge clk); 
        
        row_in = 4'b0000; // Glitch disappears before FSM accepts it
        
        // Wait to prove key_valid never goes high
        repeat(20) @(posedge clk);

        $display("--- All Block 1 Test Cases Completed ---");
        $finish;
    end

endmodule