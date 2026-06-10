`timescale 1ns / 1ps
//##############################################################
/*
Project/Module : hex_keypad
File name      : hex_keypad.sv
Version        : 1-2 (Parallelized & Optimized)
Date created   : 12/04/2026
Author         : Lim Chun Sin
Code type      : RTL / Combinational & Sequential
Description    : Block 1 - Hex Keypad Scanner & Debouncer.
                 This module safely captures physical button presses, 
                 filters out mechanical bouncing, and outputs a clean 
                 4-bit hex code. Uses unique-case for parallel synthesis.
*/
//##############################################################

module hex_keypad (
    input  logic       ip_sys_clk,         // System clock
    input  logic       ip_sys_reset,       // Active-high synchronous reset
    input  logic [3:0] ip_calc_keypad_row, // Asynchronous row inputs from physical keypad
    output logic [3:0] op_calc_keypad_col, // Scanning column outputs to physical keypad
    output logic [3:0] op_key_code,        // Decoded 4-bit hexadecimal output (0-F)
    output logic       op_key_valid        // 1-cycle pulse indicating a valid key press
);

    // ===================================================================
    // 1. Synchronizer (Clock Domain Crossing)
    // ===================================================================
    // Purpose: Physical buttons are asynchronous. We use a 2-stage flip-flop
    // synchronizer to prevent metastability issues when signals enter our clocked domain.
    logic [3:0] r_row_sync1;
    logic [3:0] r_row_sync2;
    
    // Delay pipeline for the column to match the row's 2-cycle delay
    logic [3:0] r_col_delay1;
    logic [3:0] r_col_delay2;

    always_ff @(posedge ip_sys_clk) begin
        if (ip_sys_reset) begin
            r_row_sync1  <= 4'b0000;
            r_row_sync2  <= 4'b0000;
            r_col_delay1 <= 4'b0001; // Must match the starting value of r_col
            r_col_delay2 <= 4'b0001;
        end else begin
            // Synchronize the incoming row
            r_row_sync1  <= ip_calc_keypad_row; 
            r_row_sync2  <= r_row_sync1;        
            
            // NEW: Delay the internal column
            r_col_delay1 <= r_col;
            r_col_delay2 <= r_col_delay1;
        end
    end

    // ===================================================================
    // 2. Scan & Debounce Finite State Machine (FSM)
    // ===================================================================
    // Purpose: Cycles through columns to find pressed keys, waits for 
    // mechanical bouncing to settle, and securely registers the valid key.
    typedef enum logic [1:0] {
        S_SCAN         = 2'b00, // Shifting column active bit to detect row response
        S_DEBOUNCE     = 2'b01, // Waiting for mechanical switch to stabilize
        S_EVALUATE     = 2'b10, // Flagging the valid keypress for 1 clock cycle
        S_WAIT_RELEASE = 2'b11  // Waiting for user to let go of the button
    } state_t;

    state_t r_state, w_next_state;

    logic [3:0] r_col;
    logic [3:0] r_captured_row;
    logic [3:0] r_captured_col;

    // Slows down the column shifting so rows have time to respond (useful for sim/hardware)
    logic [1:0] r_scan_delay;

    // Timer limit for debounce (adjust depending on physical switch characteristics)
    parameter DEBOUNCE_MAX = 20'd5; 
    logic [19:0] r_debounce_cnt;
    logic        w_debounce_done;

    assign w_debounce_done = (r_debounce_cnt == DEBOUNCE_MAX);

    // --- FSM Sequential Logic (Datapath & State Memory) ---
    always_ff @(posedge ip_sys_clk) begin
        if (ip_sys_reset) begin
            r_state        <= S_SCAN;
            r_col          <= 4'b0001;     // Start scanning at column 0
            r_scan_delay   <= 2'b00;
            r_debounce_cnt <= 20'd0;
            r_captured_row <= 4'd0;
            r_captured_col <= 4'd0;
            op_key_valid   <= 1'b0;
        end 
        else begin
            r_state      <= w_next_state;
            op_key_valid <= 1'b0; // Default off, only pulses in S_EVALUATE

            // 'unique case' tells the synthesizer that states are mutually exclusive,
            // preventing the generation of unnecessary priority encoder logic.
            unique case (r_state)
                S_SCAN: begin
                    r_debounce_cnt <= 20'd0; // Keep timer reset while scanning

                    if (r_row_sync2 == 4'b0000) begin
                        // No key pressed -> proceed with scanning
                        r_scan_delay <= r_scan_delay + 1'b1;
                        
                        // Shift the active column left circularly every 4 cycles
                        if (r_scan_delay == 2'b11) begin
                            r_col <= {r_col[2:0], r_col[3]}; 
                        end
                    end else begin
                        // Key detected -> lock in the current coordinates
                        r_captured_row <= r_row_sync2;
                        // USE THE DELAYED COLUMN TO MATCH THE DELAYED ROW!
                        r_captured_col <= r_col_delay2;
                    end
                end

                S_DEBOUNCE: begin
                    // Count up until mechanical bouncing is expected to stop
                    r_debounce_cnt <= r_debounce_cnt + 1'b1;
                end

                S_EVALUATE: begin
                    // Signal to downstream modules (like FIFO) that data is ready
                    op_key_valid   <= 1'b1;
                    r_debounce_cnt <= 20'd0;
                end

                S_WAIT_RELEASE: begin
                    // Reset delay for the next scan cycle
                    r_scan_delay <= 2'b00;
                end
                
            endcase
        end
    end

    // --- FSM Combinational Logic (Next State Routing) ---
    always_comb begin
        // Default assignment prevents accidental latch inference [cite: 79]
        w_next_state = r_state;

        // 'unique case' flattens the routing logic into parallel hardware
        unique case (r_state)
            S_SCAN: begin
                // Transition if any row goes high
                if (r_row_sync2 != 4'b0000)
                    w_next_state = S_DEBOUNCE;
            end

            S_DEBOUNCE: begin
                if (w_debounce_done) begin
                    // Double-check if the key is still pressed after debounce period
                    if (r_row_sync2 == r_captured_row)
                        w_next_state = S_EVALUATE; // True press
                    else
                        w_next_state = S_SCAN;     // False alarm (glitch/bounce)
                end
            end

            S_EVALUATE: begin
                // Auto-transition after 1 clock cycle
                w_next_state = S_WAIT_RELEASE;
            end

            S_WAIT_RELEASE: begin
                // Wait until all rows drop to 0 (user lifted finger)
                if (r_row_sync2 == 4'b0000)
                    w_next_state = S_SCAN;
            end
        endcase
    end

    // Route internal register to physical output pin
    assign op_calc_keypad_col = r_col;

    // ===================================================================
    // 3. Combinational Key Encoder (Coordinate to Hex Mapping)
    // ===================================================================
    // Purpose: Translates the physical grid coordinates (Row + Col) 
    // into the actual 4-bit binary value of the key pressed.
    always_comb begin
        // By concatenating row and col, 'unique case' builds a single 
        // 16-to-1 parallel multiplexer, avoiding deep, slow logic trees.
        unique case ({r_captured_row, r_captured_col})
            // --- Row 1 (0001) ---
            8'b0001_0001: op_key_code = 4'h0;
            8'b0001_0010: op_key_code = 4'h1;
            8'b0001_0100: op_key_code = 4'h2;
            8'b0001_1000: op_key_code = 4'h3;

            // --- Row 2 (0010) ---
            8'b0010_0001: op_key_code = 4'h4;
            8'b0010_0010: op_key_code = 4'h5;
            8'b0010_0100: op_key_code = 4'h6;
            8'b0010_1000: op_key_code = 4'h7;

            // --- Row 3 (0100) ---
            8'b0100_0001: op_key_code = 4'h8;
            8'b0100_0010: op_key_code = 4'h9;
            8'b0100_0100: op_key_code = 4'hA;
            8'b0100_1000: op_key_code = 4'hB;

            // --- Row 4 (1000) ---
            8'b1000_0001: op_key_code = 4'hC;
            8'b1000_0010: op_key_code = 4'hD;
            8'b1000_0100: op_key_code = 4'hE;
            8'b1000_1000: op_key_code = 4'hF;

            // Catch-all to prevent latches 
            default: op_key_code = 4'h0; 
        endcase
    end

endmodule