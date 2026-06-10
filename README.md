# 4-Digit BCD Integer Calculator

## Overview
A fully synchronous, user-operated 4-digit BCD integer calculator designed in SystemVerilog. This project handles real-world hardware interactions, including debouncing physical keypad inputs, converting BCD entries to 15-bit Two's Complement binary, performing complex arithmetic/logic operations, and time-multiplexing the output to a 7-segment display.

## Key Features
* **Custom ALU:** Supports Addition, Subtraction, Multiplication, Division, and Bitwise operations (AND, OR, XOR).
* **MUX-Based Barrel Shifter:** Executes Logical Left (SLL), Logical Right (SRL), and Arithmetic Right (SRA) shifts.
* **Hardware Input Handling:** Includes a 4x4 Hex Keypad scanner with a strict 3-block Moore FSM for clock domain crossing (CDC) synchronization and mechanical debounce.
* **Double Dabble Algorithm:** Converts the 14-bit binary magnitude back into 16-bit BCD for the output display.
* **Error Trapping:** Hardware-level detection for Overflow (OVF) and Divide-by-Zero errors, complete with dedicated LED indicators and "Err" 7-segment states.

## System Architecture
The top-level structural wrapper (`calc_top.sv`) integrates four main micro-architecture blocks:
1. **Hex Keypad Code Generator (`b_hex_keypad`):** Scans the keypad matrix and safely captures asynchronous physical button presses into a clean 4-bit hex code.
2. **Input Converter (`b_input_conv`):** Buffers BCD inputs, formats signed binary operands, and manages FSM sequencing for the calculator's state.
3. **ALU Calculator (`b_alu`):** The computation engine containing the 15-bit ripple-carry adder/subtractor and the MUX-based barrel shifter.
4. **Output Converter (`b_output_conv`):** Manages zero-blanking, drives the time-multiplexed 4-digit 7-segment display, and routes status LEDs.

## Hardware Interface
* **Inputs:** 4x4 Hex Keypad, Reset, Enter, Clear, and Sign-toggle buttons.
* **Outputs:** 4-digit 7-segment display (Cathodes/Anodes), Negative Indicator LED, Overflow Indicator LED.

## Verification
The design achieves 100% functional coverage across 25 automated test cases, successfully trapping edge cases such as zero-blanking, negative sign toggling, and complex operation sequences.

<img width="843" height="245" alt="image" src="https://github.com/user-attachments/assets/03c7faaf-749b-4a38-88e5-1c13fbfab4f5" />
<img width="834" height="465" alt="image" src="https://github.com/user-attachments/assets/fce83f34-9afe-4792-b7de-48833cfa9664" />
<img width="761" height="184" alt="image" src="https://github.com/user-attachments/assets/e3f3a27b-4f13-46a0-b330-02c925330c00" />

