//##############################################################
/*
Project/Module : tb_output_conv
File name      : tb_output_conv.sv
Version        : 2-0 (Updated for output_conv module)
Date created   : 29/04/2026
Author         : Shawn Arun Javier
Code type      : Testbench / Verification
Description    : Block 4 Testbench - Tests all 6 test cases from
                 section 4.4.9 of the assignment report.
                 DUT: output_conv (which instantiates bin2bcd internally).
                 Tests: Reset, Positive, Negative, Operator display,
                 Error (Err), Overflow (----).
*/
//##############################################################
`timescale 1ns / 1ps
`default_nettype none

module tb_output_conv;

    // ===================================================================
    // 1. Testbench Signals (mirror DUT ports, tb_ prefix)
    // ===================================================================
    logic               tb_ip_sys_clk;
    logic               tb_ip_sys_reset;
    logic signed [14:0] tb_ip_result;
    logic [2:0]         tb_ip_status;

    logic [6:0]         tb_op_calc_seg;
    logic [3:0]         tb_op_calc_seg_en;
    logic               tb_op_calc_led_neg;
    logic               tb_op_calc_led_ovf;

    // ===================================================================
    // 2. DUT Instantiation
    //    Module name: output_conv
    //    Submodule bin2bcd is instantiated inside output_conv automatically.
    //    Both output_conv.sv AND bin2bcd.sv must be added as design sources.
    // ===================================================================
    output_conv u_dut (
        .ip_sys_clk      (tb_ip_sys_clk),
        .ip_sys_reset    (tb_ip_sys_reset),
        .ip_result       (tb_ip_result),
        .ip_status       (tb_ip_status),
        .op_calc_seg     (tb_op_calc_seg),
        .op_calc_seg_en  (tb_op_calc_seg_en),
        .op_calc_led_neg (tb_op_calc_led_neg),
        .op_calc_led_ovf (tb_op_calc_led_ovf)
    );

    // ===================================================================
    // 3. Clock Generation — 10 ns period = 100 MHz
    // ===================================================================
    initial tb_ip_sys_clk = 1'b0;
    always #5 tb_ip_sys_clk = ~tb_ip_sys_clk;

    // ===================================================================
    // 4. Status Code Constants (must match localparams in output_conv)
    // ===================================================================
    localparam STAT_NORMAL  = 3'b000;
    localparam STAT_PASS    = 3'b001;
    localparam STAT_SHOW_OP = 3'b010;
    localparam STAT_ERR_DIV = 3'b011;
    localparam STAT_ERR_SEQ = 3'b100;
    localparam STAT_OVF     = 3'b101;

    // Expected 7-segment patterns (active-high: 1=ON, 0=OFF)
    // Format [6:0] = a b c d e f g
    localparam SEG_DASH  = 7'b0000001; // Center segment only (overflow "----")
    localparam SEG_BLANK = 7'b0000000; // All off
    localparam SEG_E     = 7'b1001111; // "E" for Err
    localparam SEG_r     = 7'b0000101; // "r" for Err

    // ===================================================================
    // 5. Helper Task: wait N rising clock edges then settle
    // ===================================================================
    task wait_clk(input int n);
        repeat(n) @(posedge tb_ip_sys_clk);
        #1;
    endtask

    // ===================================================================
    // 6. Helper Task: apply synchronous reset
    // ===================================================================
    task apply_reset();
        tb_ip_sys_reset = 1'b1;
        wait_clk(4);
        tb_ip_sys_reset = 1'b0;
        wait_clk(2);
    endtask

    // ===================================================================
    // 7. Main Stimulus — runs all test cases sequentially
    // ===================================================================
    initial begin
        // Safe initial values
        tb_ip_sys_reset = 1'b0;
        tb_ip_result    = 15'sd0;
        tb_ip_status    = STAT_NORMAL;

        $display("========================================================");
        $display("  tb_output_conv  |  Block 4 Verification");
        $display("  Author: Shawn Arun Javier");
        $display("========================================================");

        // ------------------------------------------------------------
        // TC1: Reset State
        // Verify r_refresh_cnt resets to 0 and seg_en starts cycling
        // Expected: op_calc_seg_en starts from 4'b0001 after reset
        // ------------------------------------------------------------
        $display("\n[TC1] Reset State");
        tb_ip_result = 15'sd0;
        tb_ip_status = STAT_NORMAL;
        apply_reset();
        wait_clk(4);
        $display("  op_calc_seg_en = 4'b%b  (should be cycling from 0001)", tb_op_calc_seg_en);
        $display("  op_calc_led_neg = %b | op_calc_led_ovf = %b  (expect: 0 | 0)",
                  tb_op_calc_led_neg, tb_op_calc_led_ovf);

        // ------------------------------------------------------------
        // TC2: Normal Numeric Display — Positive result (+40)
        // ip_result = 15'b0_0000_0000_101000 = decimal 40
        // ip_status = STAT_NORMAL
        // Expected: Display [blank][blank][4][0], NEG=0, OVF=0
        // ------------------------------------------------------------
        $display("\n[TC2] Normal Numeric — Positive (+40)");
        apply_reset();
        tb_ip_status = STAT_NORMAL;
        tb_ip_result = 15'b0_0000_0000_101000; // +40
        wait_clk(20); // wait enough cycles to see all 4 digit slots cycle
        $display("  ip_status = 3'b%b (STAT_NORMAL)", tb_ip_status);
        $display("  ip_result = 15'b%b  (= decimal +40)", tb_ip_result);
        $display("  op_calc_led_neg = %b  (expect: 0)", tb_op_calc_led_neg);
        $display("  op_calc_led_ovf = %b  (expect: 0)", tb_op_calc_led_ovf);
        $display("  op_calc_seg_en  = 4'b%b  (time-multiplexing)", tb_op_calc_seg_en);
        $display("  op_calc_seg     = 7'b%b  (current digit pattern)", tb_op_calc_seg);

        assert (tb_op_calc_led_neg === 1'b0)
            else $error("[TC2 FAIL] NEG LED should be 0 for positive result");
        assert (tb_op_calc_led_ovf === 1'b0)
            else $error("[TC2 FAIL] OVF LED should be 0");

        // ------------------------------------------------------------
        // TC3: Normal Numeric Display — Negative result (-10)
        // -10 in 15-bit two's complement:
        //   magnitude 10 = 14'b00_0000_0000_1010
        //   invert + 1   = 14'b11_1111_1111_0110
        //   with sign bit: 15'b1_1111_1111_110110
        // Expected: Display [blank][blank][1][0], NEG=1, OVF=0
        // ------------------------------------------------------------
        $display("\n[TC3] Normal Numeric — Negative (-10)");
        apply_reset();
        tb_ip_status = STAT_NORMAL;
        tb_ip_result = 15'b1_1111_1111_110110; // -10
        wait_clk(20);
        $display("  ip_status = 3'b%b (STAT_NORMAL)", tb_ip_status);
        $display("  ip_result = 15'b%b  (= decimal -10)", tb_ip_result);
        $display("  op_calc_led_neg = %b  (expect: 1)", tb_op_calc_led_neg);
        $display("  op_calc_led_ovf = %b  (expect: 0)", tb_op_calc_led_ovf);

        assert (tb_op_calc_led_neg === 1'b1)
            else $error("[TC3 FAIL] NEG LED should be 1 for negative result");
        assert (tb_op_calc_led_ovf === 1'b0)
            else $error("[TC3 FAIL] OVF LED should be 0");

        // ------------------------------------------------------------
        // TC4: Operator Display Mode — showing 'B' (subtraction key)
        // ip_status = STAT_SHOW_OP
        // ip_result = 15'b0_0000_0000_001011 = hex 0x0B
        //   bits[7:4]=0 → digit 1 shows '0'
        //   bits[3:0]=B → digit 0 shows 'b'
        // Expected: [blank][blank][0][b], NEG=0, OVF=0
        // ------------------------------------------------------------
        $display("\n[TC4] Operator Display Mode ('B' = subtraction)");
        apply_reset();
        tb_ip_status = STAT_SHOW_OP;
        tb_ip_result = 15'b0_0000_0000_001011; // 0x0B
        wait_clk(20);
        $display("  ip_status = 3'b%b (STAT_SHOW_OP)", tb_ip_status);
        $display("  ip_result = 15'b%b  (= hex 0x0B)", tb_ip_result);
        $display("  op_calc_led_neg = %b  (expect: 0)", tb_op_calc_led_neg);
        $display("  op_calc_led_ovf = %b  (expect: 0)", tb_op_calc_led_ovf);
        $display("  op_calc_seg     = 7'b%b  (cycles through 0, b, blank, blank)", tb_op_calc_seg);

        assert (tb_op_calc_led_neg === 1'b0)
            else $error("[TC4 FAIL] NEG LED should be 0 in SHOW_OP mode");
        assert (tb_op_calc_led_ovf === 1'b0)
            else $error("[TC4 FAIL] OVF LED should be 0 in SHOW_OP mode");

        // ------------------------------------------------------------
        // TC5: Error State — Divide by Zero
        // ip_status = STAT_ERR_DIV, ip_result = don't care (use 0)
        // Expected: Display [blank][E][r][r], NEG=0, OVF=0
        // ------------------------------------------------------------
        $display("\n[TC5] Error State — Divide by Zero (Err)");
        apply_reset();
        tb_ip_status = STAT_ERR_DIV;
        tb_ip_result = 15'sd0; // don't care, use 0
        wait_clk(20);
        $display("  ip_status = 3'b%b (STAT_ERR_DIV)", tb_ip_status);
        $display("  op_calc_led_neg = %b  (expect: 0)", tb_op_calc_led_neg);
        $display("  op_calc_led_ovf = %b  (expect: 0)", tb_op_calc_led_ovf);
        $display("  op_calc_seg     = 7'b%b  (cycles: blank, r, r, E)", tb_op_calc_seg);

        assert (tb_op_calc_led_neg === 1'b0)
            else $error("[TC5 FAIL] NEG LED should be 0 in ERR_DIV mode");
        assert (tb_op_calc_led_ovf === 1'b0)
            else $error("[TC5 FAIL] OVF LED should be 0 in ERR_DIV mode");

        // Manually verify E and r patterns appear by cycling through digits
        // (seg_en will scan 0001→0010→0100→1000; seg shows r,r,E,blank)
        wait_clk(600); // let counter cycle through all 4 digit positions many times
        $display("  (after cycling) op_calc_seg = 7'b%b", tb_op_calc_seg);

        // ------------------------------------------------------------
        // TC6: Overflow State
        // ip_status = STAT_OVF, ip_result = don't care
        // Expected: Display [—][—][—][—], NEG=0, OVF=1
        // op_calc_seg should always be SEG_DASH (7'b0000001)
        // ------------------------------------------------------------
        $display("\n[TC6] Overflow State (----)");
        apply_reset();
        tb_ip_result = 15'sd0;
        tb_ip_status = STAT_OVF;
        wait_clk(20);
        $display("  ip_status = 3'b%b (STAT_OVF)", tb_ip_status);
        $display("  op_calc_led_neg = %b  (expect: 0)", tb_op_calc_led_neg);
        $display("  op_calc_led_ovf = %b  (expect: 1)", tb_op_calc_led_ovf);
        $display("  op_calc_seg     = 7'b%b  (expect: 0000001 = dash)", tb_op_calc_seg);

        assert (tb_op_calc_led_neg === 1'b0)
            else $error("[TC6 FAIL] NEG LED should be 0 in OVF mode");
        assert (tb_op_calc_led_ovf === 1'b1)
            else $error("[TC6 FAIL] OVF LED should be 1 in STAT_OVF");
        assert (tb_op_calc_seg === SEG_DASH)
            else $error("[TC6 FAIL] seg should be dash (7'b0000001) in OVF mode, got 7'b%b", tb_op_calc_seg);

        // -------------------------------------------------------
        $display("\n========================================================");
        $display("  All 6 test cases complete. Check above for any FAIL.");
        $display("========================================================\n");
        $finish;
    end

    // ===================================================================
    // 8. Safety watchdog — kills simulation if it runs too long
    // ===================================================================
    initial begin
        #2000000;
        $display("[WATCHDOG] Simulation exceeded 2ms — force stop.");
        $finish;
    end

endmodule

`default_nettype wire
