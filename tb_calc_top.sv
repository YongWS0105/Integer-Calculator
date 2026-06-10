`timescale 1ns / 1ps

module tb_calc_top();

    // ===================================================================
    // 1. Signal Declarations
    // ===================================================================
    logic       clk;
    logic       reset;
    logic [3:0] keypad_row;
    logic       sign_btn;
    logic       enter_btn;
    logic       clear_btn;
    
    logic [3:0] keypad_col;
    logic [6:0] seg;
    logic [3:0] seg_en;
    logic       led_neg;
    logic       led_ovf;

    // ===================================================================
    // 2. DUT Instantiation
    // ===================================================================
    calc_top dut (
        .ip_sys_clk         (clk),
        .ip_sys_reset       (reset),
        .ip_calc_keypad_row (keypad_row),
        .ip_calc_sign       (sign_btn),
        .ip_calc_enter      (enter_btn),
        .ip_calc_clear      (clear_btn),
        .op_calc_keypad_col (keypad_col),
        .op_calc_seg        (seg),
        .op_calc_seg_en     (seg_en),
        .op_calc_led_neg    (led_neg),
        .op_calc_led_ovf    (led_ovf)
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
            reset = 1'b1; repeat(6) @(posedge clk);
            reset = 1'b0; repeat(6) @(posedge clk);
        end
    endtask

    task press_enter();
        begin
            enter_btn = 1'b1; repeat(4) @(posedge clk);
            enter_btn = 1'b0; repeat(20) @(posedge clk);
        end
    endtask

    task press_sign();
        begin
            sign_btn = 1'b1; repeat(4) @(posedge clk);
            sign_btn = 1'b0; repeat(20) @(posedge clk);
        end
    endtask

    task press_clear();
        begin
            clear_btn = 1'b1; repeat(4) @(posedge clk);
            clear_btn = 1'b0; repeat(20) @(posedge clk);
        end
    endtask

    task press_key(input [3:0] hex_key);
        logic [3:0] target_row, target_col;
        begin
            case(hex_key)
                4'h0: begin target_row = 4'b0001; target_col = 4'b0001; end
                4'h1: begin target_row = 4'b0001; target_col = 4'b0010; end
                4'h2: begin target_row = 4'b0001; target_col = 4'b0100; end
                4'h3: begin target_row = 4'b0001; target_col = 4'b1000; end
                4'h4: begin target_row = 4'b0010; target_col = 4'b0001; end
                4'h5: begin target_row = 4'b0010; target_col = 4'b0010; end
                4'h6: begin target_row = 4'b0010; target_col = 4'b0100; end
                4'h7: begin target_row = 4'b0010; target_col = 4'b1000; end
                4'h8: begin target_row = 4'b0100; target_col = 4'b0001; end
                4'h9: begin target_row = 4'b0100; target_col = 4'b0010; end
                4'hA: begin target_row = 4'b0100; target_col = 4'b0100; end
                4'hB: begin target_row = 4'b0100; target_col = 4'b1000; end
                4'hC: begin target_row = 4'b1000; target_col = 4'b0001; end
                4'hD: begin target_row = 4'b1000; target_col = 4'b0010; end
                4'hE: begin target_row = 4'b1000; target_col = 4'b0100; end
                4'hF: begin target_row = 4'b1000; target_col = 4'b1000; end
                default: begin target_row = 4'b0000; target_col = 4'b0000; end
            endcase
            wait (keypad_col == target_col);
            keypad_row = target_row; repeat(40) @(posedge clk); 
            keypad_row = 4'b0000;    repeat(40) @(posedge clk); 
        end
    endtask

    // ===================================================================
    // 5. Main Test Sequence 
    // ===================================================================
    initial begin
        clk = 0; reset = 0; keypad_row = 0; sign_btn = 0; enter_btn = 0; clear_btn = 0;
        #100;

//        // -----------------------------------------------------------
//        // TC1: Reset input
//        // Estimated Simulation Timeline: 0.10 탎 - 0.22 탎
//        // -----------------------------------------------------------
//        $display("TC1: Reset");
//        apply_reset();

//        // -----------------------------------------------------------
//        // TC2: Decimal digit input (1, 2, 3)
//        // Estimated Simulation Timeline: 0.22 탎 - 2.70 탎
//        // -----------------------------------------------------------
//        $display("TC2: Digit Input");
//        apply_reset(); press_key(4'h1); press_key(4'h2); press_key(4'h3);

        // -----------------------------------------------------------
//        // TC3: Sign input (Toggle Negative)
//        // Estimated Simulation Timeline: 2.70 탎 - 4.50 탎
//        // -----------------------------------------------------------
//        $display("TC3: Sign Toggle");
//        apply_reset(); press_key(4'h4); press_key(4'h5); press_sign();

//        // -----------------------------------------------------------
//        // TC4: Store operand A
//        // Estimated Simulation Timeline: 4.50 탎 - 6.30 탎
//        // -----------------------------------------------------------
//        $display("TC4: Store Op A");
//        apply_reset(); press_key(4'h2); press_key(4'h5); press_enter();

        // -----------------------------------------------------------
        // TC5: Addition (25 + 13 = 38)
        // Estimated Simulation Timeline: 6.30 탎 - 10.90 탎
        // -----------------------------------------------------------
        $display("TC5: Add");
        apply_reset(); 
        press_key(4'h1); press_key(4'h2); press_enter(); 
        press_key(4'hB); 
        press_key(4'h4); press_key(4'h0);press_enter(); repeat(50) @(posedge clk);

//        // -----------------------------------------------------------
//        // TC6: Subtraction (25 - 47 = -22)
//        // Estimated Simulation Timeline: 10.90 탎 - 15.50 탎
//        // -----------------------------------------------------------
//        $display("TC6: Sub");
//        apply_reset(); 
//        press_key(4'h2); press_key(4'h5); press_enter(); 
//        press_key(4'hB); 
//        press_key(4'h4); press_key(4'h7); press_enter(); repeat(50) @(posedge clk);

//        // -----------------------------------------------------------
//        // TC7: Multiplication (12 * 5 = 60)
//        // Estimated Simulation Timeline: 15.50 탎 - 19.30 탎
//        // -----------------------------------------------------------
//        $display("TC7: Mul");
//        apply_reset(); 
//        press_key(4'h1); press_key(4'h2); press_enter(); 
//        press_key(4'hC); 
//        press_key(4'h5); press_enter(); repeat(50) @(posedge clk);

//        // -----------------------------------------------------------
//        // TC8: Division (84 / 7 = 12)
//        // Estimated Simulation Timeline: 19.30 탎 - 23.10 탎
//        // -----------------------------------------------------------
//        $display("TC8: Div");
//        apply_reset(); 
//        press_key(4'h8); press_key(4'h4); press_enter(); 
//        press_key(4'hD); 
//        press_key(4'h7); press_enter(); repeat(50) @(posedge clk);

//        // -----------------------------------------------------------
//        // TC9: Bitwise AND (12 & 10 = 8)
//        // Estimated Simulation Timeline: 23.10 탎 - 28.50 탎
//        // -----------------------------------------------------------
//        $display("TC9: AND");
//        apply_reset(); 
//        press_key(4'h1); press_key(4'h2); press_enter(); 
//        press_key(4'hE); press_key(4'h0); 
//        press_key(4'h1); press_key(4'h0); press_enter(); repeat(50) @(posedge clk);

//        // -----------------------------------------------------------
//        // TC10: Bitwise OR (12 | 10 = 14)
//        // Estimated Simulation Timeline: 28.50 탎 - 33.90 탎
//        // -----------------------------------------------------------
//        $display("TC10: OR");
//        apply_reset(); 
//        press_key(4'h1); press_key(4'h2); press_enter(); 
//        press_key(4'hE); press_key(4'h1); 
//        press_key(4'h1); press_key(4'h0); press_enter(); repeat(50) @(posedge clk);

//        // -----------------------------------------------------------
//        // TC11: Bitwise XOR (12 ^ 10 = 6)
//        // Estimated Simulation Timeline: 33.90 탎 - 39.30 탎
//        // -----------------------------------------------------------
//        $display("TC11: XOR");
//        apply_reset(); 
//        press_key(4'h1); press_key(4'h2); press_enter(); 
//        press_key(4'hE); press_key(4'h2); 
//        press_key(4'h1); press_key(4'h0); press_enter(); repeat(50) @(posedge clk);

//        // -----------------------------------------------------------
//        // TC12: Logical Left Shift (3 << 2 = 12)
//        // Estimated Simulation Timeline: 39.30 탎 - 43.90 탎
//        // -----------------------------------------------------------
//        $display("TC12: SLL");
//        apply_reset(); 
//        press_key(4'h3); press_enter(); 
//        press_key(4'hF); press_key(4'h0); 
//        press_key(4'h2); press_enter(); repeat(50) @(posedge clk);

//        // -----------------------------------------------------------
//        // TC13: Logical Right Shift (12 >> 2 = 3)
//        // Estimated Simulation Timeline: 43.90 탎 - 49.30 탎
//        // -----------------------------------------------------------
//        $display("TC13: SRL");
//        apply_reset(); 
//        press_key(4'h1); press_key(4'h2); press_enter(); 
//        press_key(4'hF); press_key(4'h1); 
//        press_key(4'h2); press_enter(); repeat(50) @(posedge clk);

//        // -----------------------------------------------------------
//        // TC14: Arithmetic Right Shift (-8 >>> 1 = -4)
//        // Estimated Simulation Timeline: 49.30 탎 - 54.10 탎
//        // -----------------------------------------------------------
//        $display("TC14: SRA");
//        apply_reset(); 
//        press_key(4'h8); press_sign(); press_enter(); 
//        press_key(4'hF); press_key(4'h2); 
//        press_key(4'h1); press_enter(); repeat(50) @(posedge clk);

//        // -----------------------------------------------------------
//        // TC15: Divide by Zero (50 / 0 = Err)
//        // Estimated Simulation Timeline: 54.10 탎 - 58.70 탎
//        // -----------------------------------------------------------
//        $display("TC15: Div by 0");
//        apply_reset(); 
//        press_key(4'h5); press_key(4'h0); press_enter(); 
//        press_key(4'hD); 
//        press_key(4'h0); press_enter(); repeat(50) @(posedge clk);

//        // -----------------------------------------------------------
//        // TC16: Overflow (9999 + 1 = ----)
//        // Estimated Simulation Timeline: 58.70 탎 - 64.90 탎
//        // -----------------------------------------------------------
//        $display("TC16: OVF");
//        apply_reset(); 
//        press_key(4'h9); press_key(4'h9); press_key(4'h9); press_key(4'h9); press_enter(); 
//        press_key(4'hA); 
//        press_key(4'h1); press_enter(); repeat(50) @(posedge clk);

//        // -----------------------------------------------------------
//        // TC17: Invalid Sequence (5 -> E -> 5 = Err)
//        // Estimated Simulation Timeline: 64.90 탎 - 68.10 탎
//        // -----------------------------------------------------------
//        $display("TC17: Invalid Seq");
//        apply_reset(); 
//        press_key(4'h5); press_enter(); 
//        press_key(4'hE); press_key(4'h5); repeat(50) @(posedge clk);

//        // -----------------------------------------------------------
//        // TC18: Clear input / restart
//        // Estimated Simulation Timeline: 68.10 탎 - 68.40 탎
//        // -----------------------------------------------------------
//        $display("TC18: Clear Normal");
//        press_clear(); repeat(50) @(posedge clk);

//         //-----------------------------------------------------------
//        // TC19: Four-digit limit (12345 -> 1234)
//        // Estimated Simulation Timeline: 68.40 탎 - 72.60 탎
//        // -----------------------------------------------------------
//        $display("TC19: 4-Digit Limit");
//        apply_reset(); 
//        press_key(4'h1); press_key(4'h2); press_key(4'h3); press_key(4'h4); press_key(4'h5);

//        // -----------------------------------------------------------
//        // TC20: Invalid Operator after A (25 -> Enter -> 5 = Err)
//        // Estimated Simulation Timeline: 72.60 탎 - 75.20 탎
//        // -----------------------------------------------------------
//        $display("TC20: Invalid Op");
//        apply_reset(); 
//        press_key(4'h2); press_key(4'h5); press_enter(); 
//        press_key(4'h5); repeat(50) @(posedge clk);

////         -----------------------------------------------------------
////         TC21: Invalid Shift Sub-operator (8 -> F -> 9 = Err)
////         Estimated Simulation Timeline: 75.20 탎 - 77.80 탎
////         -----------------------------------------------------------
//        $display("TC21: Bad Shift Op");
//        apply_reset(); 
//        press_key(4'h8); press_enter(); 
//        press_key(4'hF); press_key(4'h9); repeat(50) @(posedge clk);

//        // -----------------------------------------------------------
//        // TC22: Add with negative (-2 + 3 = 1)
//        // Estimated Simulation Timeline: 77.80 탎 - 81.80 탎
//        // -----------------------------------------------------------
//        $display("TC22: Add Neg");
//        apply_reset(); 
//        press_key(4'h2); press_sign(); press_enter(); 
//        press_key(4'hA); 
//        press_key(4'h3); press_enter(); repeat(50) @(posedge clk);

//        // -----------------------------------------------------------
//        // TC23: Mul with negative (-12 * 5 = -60)
//        // Estimated Simulation Timeline: 81.80 탎 - 86.60 탎
//        // -----------------------------------------------------------
//        $display("TC23: Mul Neg");
//        apply_reset(); 
//        press_key(4'h1); press_key(4'h2); press_sign(); press_enter(); 
//        press_key(4'hC); 
//        press_key(4'h5); press_enter(); repeat(50) @(posedge clk);

//        // -----------------------------------------------------------
//        // TC24: Div with negative (-84 / 7 = -12)
//        // Estimated Simulation Timeline: 86.60 탎 - 91.40 탎
//        // -----------------------------------------------------------
//        $display("TC24: Div Neg");
//        apply_reset(); 
//        press_key(4'h8); press_key(4'h4); press_sign(); press_enter(); 
//        press_key(4'hD); 
//        press_key(4'h7); press_enter(); repeat(50) @(posedge clk);

//        // -----------------------------------------------------------
//        // TC25: Clear after error
//        // Estimated Simulation Timeline: 91.40 탎 - 91.70 탎
//        // -----------------------------------------------------------
//        $display("TC25: Clear Error");
//        // We are currently showing the valid output from TC24. 
//        // Let's force a quick divide-by-zero error, then clear it.
//        press_key(4'h1); press_enter(); press_key(4'hD); press_key(4'h0); press_enter();
//        repeat(50) @(posedge clk); // Observe Error state
//        press_clear();             // Clear it
//        repeat(50) @(posedge clk); // Observe clear state

//        $display("=== All Top-Level Test Cases Completed Successfully ===");
        $finish;
    end

endmodule