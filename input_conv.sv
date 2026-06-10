//##############################################################
/*
Project/Module : input_conv
File name      : input_conv.sv
Author         : Lim Chun Sin
Description    : Block 2 - Input Conversion & Sequencing.
                 Receives keypresses, builds numbers in a RAM array, 
                 controls the operation sequence (A -> OP -> B -> Execute), 
                 and formats signed data for the ALU.
*/
//##############################################################

module input_conv (
    input  logic        ip_sys_clk,
    input  logic        ip_sys_reset,
    
    // Independent Physical Buttons (Direct from user)
    input  logic        ip_calc_sign,  // Toggle positive/negative
    input  logic        ip_calc_enter, // Confirm entry
    input  logic        ip_calc_clear, // Reset sequence
    
    // Inputs from Block 1 (Keypad Generator)
    input  logic [3:0]  ip_key_code,
    input  logic        ip_key_valid,
    
    // Outputs to Block 3 (ALU / Shifter Engine)
    output logic signed [14:0] op_operand_a,
    output logic signed [14:0] op_operand_b,
    output logic [3:0]  op_operator_sel,
    output logic [3:0]  op_sub_operator,
    output logic [13:0] op_pass_through,   
    output logic        op_pass_sign,
    output logic [2:0]  op_status,
    output logic        op_execute
);

    // ===================================================================
    // 1. System Parameters & FSM States
    // ===================================================================
    localparam STAT_NORMAL  = 3'b000;  // Display normal output
    localparam STAT_PASS    = 3'b001;  // Display current typed input
    localparam STAT_SHOW_OP = 3'b010;  // Display chosen operator
    localparam STAT_ERR_SEQ = 3'b100;  // Display sequence error

    typedef enum logic [2:0] {
        S_GET_A        = 3'b000, // Collecting 1st operand
        S_GET_OP       = 3'b001, // Waiting for main operator
        S_WAIT_SUB_OP  = 3'b010, // Waiting for sub-operator (e.g., shift type)
        S_GET_B        = 3'b011, // Collecting 2nd operand
        S_EXECUTE      = 3'b100, // Trigger ALU
        S_ERROR        = 3'b101  // Error lock state
    } state_t;

    state_t r_state;

    // Internal Memory Registers 
    logic [3:0]  r_ram [0:3];     // Array of 4 memory locations (holds up to 4 BCD digits)
    logic [2:0]  r_digit_cnt;     // Write Pointer for RAM array
    logic        r_sign_temp;     // Tracks sign of the number currently being typed

    logic [13:0] r_operand_a_mag; // Magnitude of Operand A
    logic        r_sign_a;        // Sign of Operand A
    logic [13:0] r_operand_b_mag; // Magnitude of Operand B
    logic        r_sign_b;        // Sign of Operand B

    // ===================================================================
    // 2. Button Synchronizers & Edge Detectors
    // ===================================================================
    // Purpose: Safely brings asynchronous physical button presses into the 
    // clock domain and converts them into single-cycle pulses.
    logic r_enter_sync1, r_enter_sync2, r_enter_delay;
    logic r_sign_sync1,  r_sign_sync2,  r_sign_delay;
    logic r_clear_sync1, r_clear_sync2, r_clear_delay;

    always_ff @(posedge ip_sys_clk) begin
        if (ip_sys_reset) begin
            r_enter_sync1 <= 1'b0; r_enter_sync2 <= 1'b0; r_enter_delay <= 1'b0;
            r_sign_sync1  <= 1'b0; r_sign_sync2  <= 1'b0; r_sign_delay  <= 1'b0;
            r_clear_sync1 <= 1'b0; r_clear_sync2 <= 1'b0; r_clear_delay <= 1'b0;
        end else begin
            // 2-Stage Sync to prevent metastability
            r_enter_sync1 <= ip_calc_enter; r_enter_sync2 <= r_enter_sync1;
            r_sign_sync1  <= ip_calc_sign;  r_sign_sync2  <= r_sign_sync1;
            r_clear_sync1 <= ip_calc_clear; r_clear_sync2 <= r_clear_sync1;

            // Delay register for rising edge detection
            r_enter_delay <= r_enter_sync2;
            r_sign_delay  <= r_sign_sync2;
            r_clear_delay <= r_clear_sync2;
        end
    end

    // Rising Edge Pulses
    logic w_enter_pulse, w_sign_pulse, w_clear_pulse;
    assign w_enter_pulse = r_enter_sync2 & ~r_enter_delay;
    assign w_sign_pulse  = r_sign_sync2  & ~r_sign_delay;
    assign w_clear_pulse = r_clear_sync2 & ~r_clear_delay;

    // ===================================================================
    // 3. BCD to Binary Submodule
    // ===================================================================
    // Converts the user's BCD input sequence from the RAM array into pure binary
    logic [13:0] w_fifo_bin;

    bcd2bin u_bcd_to_binary (
        .ip_digit_3   (r_ram[3]),
        .ip_digit_2   (r_ram[2]),
        .ip_digit_1   (r_ram[1]),
        .ip_digit_0   (r_ram[0]),
        .ip_digit_cnt (r_digit_cnt),
        .op_bin_val   (w_fifo_bin)
    );

    // ===================================================================
    // 4. Main Sequencing FSM
    // ===================================================================
    // Purpose: Controls the calculator's step-by-step logic flow.
    always_ff @(posedge ip_sys_clk) begin
        if (ip_sys_reset) begin
            r_state         <= S_GET_A;
            r_ram[0]        <= 4'h0; r_ram[1] <= 4'h0;
            r_ram[2]        <= 4'h0; r_ram[3] <= 4'h0;
            r_digit_cnt     <= 3'd0;
            r_sign_temp     <= 1'b0;
            r_operand_a_mag <= 14'd0;
            r_sign_a        <= 1'b0;
            r_operand_b_mag <= 14'd0;
            r_sign_b        <= 1'b0;
            op_operator_sel <= 4'h0;
            op_sub_operator <= 4'h0;
            op_execute      <= 1'b0;
            op_status       <= STAT_PASS;
        end 
        else if (w_clear_pulse) begin
            // Hardware clear resets all buffers and returns to start
            r_state         <= S_GET_A;
            r_ram[0]        <= 4'h0; r_ram[1] <= 4'h0;
            r_ram[2]        <= 4'h0; r_ram[3] <= 4'h0;
            r_digit_cnt     <= 3'd0;
            r_sign_temp     <= 1'b0;
            r_operand_a_mag <= 14'd0;
            r_sign_a        <= 1'b0;
            r_operand_b_mag <= 14'd0;
            r_sign_b        <= 1'b0;
            op_operator_sel <= 4'h0;
            op_sub_operator <= 4'h0;
            op_execute      <= 1'b0;
            op_status       <= STAT_PASS;
        end 
        else begin
            op_execute <= 1'b0; // Default off, pulses only in EXECUTE state

            case (r_state)
                // --- STATE: Build Operand A ---
                S_GET_A: begin
                    op_status <= STAT_PASS; // Show what is being typed

                    if (w_sign_pulse) begin
                        r_sign_temp <= ~r_sign_temp; // Toggle sign
                    end
                    else if (ip_key_valid) begin
                        if (ip_key_code <= 4'h9) begin // Accept only numbers (0-9)
                            if (r_digit_cnt < 3'd4) begin
                                r_ram[r_digit_cnt] <= ip_key_code;
                                r_digit_cnt <= r_digit_cnt + 1'b1;
                            end
                        end
                    end
                    else if (w_enter_pulse) begin
                        // Save Operand A and clear RAM for next entry
                        r_operand_a_mag <= w_fifo_bin;
                        r_sign_a        <= r_sign_temp;

                        r_ram[0]        <= 4'h0; r_ram[1] <= 4'h0;
                        r_ram[2]        <= 4'h0; r_ram[3] <= 4'h0;
                        r_digit_cnt     <= 3'd0;
                        r_sign_temp     <= 1'b0;
                        r_state         <= S_GET_OP;
                    end
                end

                // --- STATE: Wait for Main Operator ---
                S_GET_OP: begin
                    if (ip_key_valid) begin
                        if (ip_key_code >= 4'hA && ip_key_code <= 4'hD) begin
                            // Standard operator chosen (A, B, C, D)
                            op_operator_sel <= ip_key_code;
                            op_status       <= STAT_SHOW_OP;
                            r_state         <= S_GET_B;
                        end
                        else if (ip_key_code == 4'hE || ip_key_code == 4'hF) begin
                            // Complex operator chosen, requires a sub-operator
                            op_operator_sel <= ip_key_code;
                            op_status       <= STAT_SHOW_OP;
                            r_state         <= S_WAIT_SUB_OP;
                        end
                        else begin
                            // Number pressed when expecting an operator
                            op_status <= STAT_ERR_SEQ;
                            r_state   <= S_ERROR;
                        end
                    end
                end

                // --- STATE: Wait for Sub-Operator ---
                // Guideline: E0/E1/E2 and F0/F1/F2 only
                S_WAIT_SUB_OP: begin
                    if (ip_key_valid) begin
                        if ((op_operator_sel == 4'hE || op_operator_sel == 4'hF) && (ip_key_code <= 4'h2)) begin
                            op_sub_operator <= ip_key_code;
                            r_state         <= S_GET_B;
                        end else begin
                            // Invalid sub-operator mapping
                            op_status <= STAT_ERR_SEQ;
                            r_state   <= S_ERROR;
                        end
                    end
                end

                // --- STATE: Build Operand B ---
                S_GET_B: begin
                    if (ip_key_valid && ip_key_code <= 4'h9) begin
                        op_status <= STAT_PASS;
                        if (r_digit_cnt < 3'd4) begin
                            r_ram[r_digit_cnt] <= ip_key_code;
                            r_digit_cnt <= r_digit_cnt + 1'b1;
                        end
                    end
                    else if (w_sign_pulse) begin
                        r_sign_temp <= ~r_sign_temp;
                    end
                    else if (w_enter_pulse) begin
                        // Save Operand B and immediately trigger execution
                        r_operand_b_mag <= w_fifo_bin;
                        r_sign_b        <= r_sign_temp;
                        op_execute      <= 1'b1; 
                        op_status       <= STAT_NORMAL;
                        r_state         <= S_EXECUTE;
                    end
                end

                // --- STATE: Execute ---
                S_EXECUTE: begin
                    // Maintain execution signal so ALU can latch results
                    op_execute <= 1'b1;
                end

                // --- STATE: Sequence Error ---
                S_ERROR: begin
                    // Locked. Must wait for hardware clear button to reset FSM.
                end

                default: begin
                    r_state <= S_GET_A;
                end
            endcase
        end
    end

    // ===================================================================
    // 5. Two's Complement Conversion & Pass-Through Routing
    // ===================================================================
    always_comb begin
        // Convert Sign + Magnitude into formal 15-bit Two's Complement for ALU
        op_operand_a = r_sign_a ? (~{1'b0, r_operand_a_mag} + 1'b1) : {1'b0, r_operand_a_mag};
        op_operand_b = r_sign_b ? (~{1'b0, r_operand_b_mag} + 1'b1) : {1'b0, r_operand_b_mag};

        // Determine what is sent to the 7-segment display module based on state
        if (r_state == S_GET_OP || r_state == S_WAIT_SUB_OP) begin
            op_pass_through = {10'd0, op_operator_sel}; // Show operator code
            op_pass_sign    = 1'b0;
        end else begin
            op_pass_through = w_fifo_bin;               // Show typed magnitude
            op_pass_sign    = r_sign_temp;              // Show current sign
        end
    end

endmodule