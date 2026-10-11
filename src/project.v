/*
 * Copyright (c) 2026 Sahil Sexsena
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,    // [3:0]=data_in, [7:4]=dec_wr_addr[3:0]
    output wire [7:0] uo_out,   // [7:0]=data_out[7:0]
    input  wire [7:0] uio_in,   // [0]=dec_wr_addr[4], [1]=wen, [2]=ren, [7:3]=dec_rd_addr[4:0]
    output wire [7:0] uio_out,  // Tied to 0
    output wire [7:0] uio_oe,   // Direction control: 0 = all inputs
    input  wire       ena,      // Chip Select (cs) - active-high
    input  wire       clk,      // System clock
    input  wire       rst_n     // Reset pin from TT pad (active-low pad inverted to active-high rst)
);

    // Fixed 8-Bit Secret Key for Parallel XOR Encryption & Decryption
    localparam [7:0] CIPHER_KEY = 8'b1010_1010; // 0xAA

    // ----------------------------------------------------------------
    // 1. Explicit Wire Mappings & Named Variables
    // ----------------------------------------------------------------
    wire       rst         = ~rst_n;
    wire       cs          = ena;

    wire [3:0] data_in     = ui_in[3:0];
    wire [4:0] dec_wr_addr = {uio_in[0], ui_in[7:4]}; // {A4, A3, A2, A1, A0}
    wire       wen         = uio_in[1];
    wire       ren         = uio_in[2];
    wire [4:0] dec_rd_addr = uio_in[7:3];

    reg  [7:0] data_out;
    assign uo_out = data_out;

    assign uio_out = 8'h00;
    assign uio_oe  = 8'h00;

    // ----------------------------------------------------------------
    // 2. Flattened 32-Byte Registers (Explicitly synthesizable to standard DFFs)
    // ----------------------------------------------------------------
    reg [3:0]   msb_buf;       
    reg         nibble_phase;  
    
    reg [7:0] r0,  r1,  r2,  r3,  r4,  r5,  r6,  r7;
    reg [7:0] r8,  r9,  r10, r11, r12, r13, r14, r15;
    reg [7:0] r16, r17, r18, r19, r20, r21, r22, r23;
    reg [7:0] r24, r25, r26, r27, r28, r29, r30, r31;

    // ----------------------------------------------------------------
    // 3. Synchronous Execution Core
    // ----------------------------------------------------------------
    reg [7:0] full_assembled_byte;
    reg [7:0] full_encrypted_byte;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            msb_buf      <= 4'b0000;
            nibble_phase <= 1'b0;
            data_out     <= 8'h00;
            {r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15,
             r16, r17, r18, r19, r20, r21, r22, r23, r24, r25, r26, r27, r28, r29, r30, r31} <= 256'b0;
        end else if (!cs) begin
            nibble_phase <= 1'b0;
            data_out     <= 8'h00;
        end else begin
            // --- Write Path: 2 Consecutive Clocks ---
            if (!wen) begin
                nibble_phase <= 1'b0;
            end else begin
                if (!nibble_phase) begin
                    msb_buf      <= data_in;
                    nibble_phase <= 1'b1;
                end else begin
                    full_assembled_byte = {msb_buf, data_in};
                    full_encrypted_byte = full_assembled_byte ^ CIPHER_KEY;
                    nibble_phase        = 1'b0;

                    // Explicit register writing based on dec_wr_addr
                    case (dec_wr_addr)
                        5'd0:  r0  <= full_encrypted_byte;
                        5'd1:  r1  <= full_encrypted_byte;
                        5'd2:  r2  <= full_encrypted_byte;
                        5'd3:  r3  <= full_encrypted_byte;
                        5'd4:  r4  <= full_encrypted_byte;
                        5'd5:  r5  <= full_encrypted_byte;
                        5'd6:  r6  <= full_encrypted_byte;
                        5'd7:  r7  <= full_encrypted_byte;
                        5'd8:  r8  <= full_encrypted_byte;
                        5'd9:  r9  <= full_encrypted_byte;
                        5'd10: r10 <= full_encrypted_byte;
                        5'd11: r11 <= full_encrypted_byte;
                        5'd12: r12 <= full_encrypted_byte;
                        5'd13: r13 <= full_encrypted_byte;
                        5'd14: r14 <= full_encrypted_byte;
                        5'd15: r15 <= full_encrypted_byte;
                        5'd16: r16 <= full_encrypted_byte;
                        5'd17: r17 <= full_encrypted_byte;
                        5'd18: r18 <= full_encrypted_byte;
                        5'd19: r19 <= full_encrypted_byte;
                        5'd20: r20 <= full_encrypted_byte;
                        5'd21: r21 <= full_encrypted_byte;
                        5'd22: r22 <= full_encrypted_byte;
                        5'd23: r23 <= full_encrypted_byte;
                        5'd24: r24 <= full_encrypted_byte;
                        5'd25: r25 <= full_encrypted_byte;
                        5'd26: r26 <= full_encrypted_byte;
                        5'd27: r27 <= full_encrypted_byte;
                        5'd28: r28 <= full_encrypted_byte;
                        5'd29: r29 <= full_encrypted_byte;
                        5'd30: r30 <= full_encrypted_byte;
                        5'd31: r31 <= full_encrypted_byte;
                        default: ;
                    endcase
                end
            end

            // --- Read Path: 1-Clock Parallel Decrypted Readout ---
            if (!ren) begin
                data_out <= 8'h00;
            end else begin
                // Explicit register reading multiplexer based on dec_rd_addr
                case (dec_rd_addr)
                    5'd0:  data_out <= r0  ^ CIPHER_KEY;
                    5'd1:  data_out <= r1  ^ CIPHER_KEY;
                    5'd2:  data_out <= r2  ^ CIPHER_KEY;
                    5'd3:  data_out <= r3  ^ CIPHER_KEY;
                    5'd4:  data_out <= r4  ^ CIPHER_KEY;
                    5'd5:  data_out <= r5  ^ CIPHER_KEY;
                    5'd6:  data_out <= r6  ^ CIPHER_KEY;
                    5'd7:  data_out <= r7  ^ CIPHER_KEY;
                    5'd8:  data_out <= r8  ^ CIPHER_KEY;
                    5'd9:  data_out <= r9  ^ CIPHER_KEY;
                    5'd10: data_out <= r10 ^ CIPHER_KEY;
                    5'd11: data_out <= r11 ^ CIPHER_KEY;
                    5'd12: data_out <= r12 ^ CIPHER_KEY;
                    5'd13: data_out <= r13 ^ CIPHER_KEY;
                    5'd14: data_out <= r14 ^ CIPHER_KEY;
                    5'd15: data_out <= r15 ^ CIPHER_KEY;
                    5'd16: data_out <= r16 ^ CIPHER_KEY;
                    5'd17: data_out <= r17 ^ CIPHER_KEY;
                    5'd18: data_out <= r18 ^ CIPHER_KEY;
                    5'd19: data_out <= r19 ^ CIPHER_KEY;
                    5'd20: data_out <= r20 ^ CIPHER_KEY;
                    5'd21: data_out <= r21 ^ CIPHER_KEY;
                    5'd22: data_out <= r22 ^ CIPHER_KEY;
                    5'd23: data_out <= r23 ^ CIPHER_KEY;
                    5'd24: data_out <= r24 ^ CIPHER_KEY;
                    5'd25: data_out <= r25 ^ CIPHER_KEY;
                    5'd26: data_out <= r26 ^ CIPHER_KEY;
                    5'd27: data_out <= r27 ^ CIPHER_KEY;
                    5'd28: data_out <= r28 ^ CIPHER_KEY;
                    5'd29: data_out <= r29 ^ CIPHER_KEY;
                    5'd30: data_out <= r30 ^ CIPHER_KEY;
                    5'd31: data_out <= r31 ^ CIPHER_KEY;
                    default: data_out <= 8'h00;
                endcase
            end
        end
    end

endmodule
