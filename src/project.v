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
    // 2. Optimized 32-Byte Memory Array (Replaces 256-bit flattened array)
    // ----------------------------------------------------------------
    reg [3:0]   msb_buf;       // Buffer to hold upper nibble across Clock 1
    reg         nibble_phase;  // 0 = Waiting for MSB, 1 = Waiting for LSB
    
    // Standard 32-entry byte-addressable register file (cleanly synthesizes in Sky130)
    reg [7:0]   mem [31:0];    
    integer     i;

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
            for (i = 0; i < 32; i = i + 1) begin
                mem[i] <= 8'h00;
            end
        end else if (!cs) begin
            nibble_phase <= 1'b0;
            data_out     <= 8'h00;
        end else begin
            // --- Write Path: 2 Consecutive Clocks ---
            if (!wen) begin
                nibble_phase <= 1'b0;
            end else begin
                if (!nibble_phase) begin
                    // Clock 1: Latch 4-bit MSB into msb_buf
                    msb_buf      <= data_in;
                    nibble_phase <= 1'b1;

                    $display("\n[WRITE CYCLE 1: MSB]");
                    $display("  Incoming data_in[3:0] : 4'b%04b", data_in);
                    $display("  Target dec_wr_addr    : %0d", dec_wr_addr);
                end else begin
                    // Clock 2: Assemble MSB + LSB into full 8-bit byte and encrypt
                    full_assembled_byte = {msb_buf, data_in};
                    full_encrypted_byte = full_assembled_byte ^ CIPHER_KEY;
                    nibble_phase        = 1'b0;

                    $display("\n[WRITE CYCLE 2: LSB & write_commit]");
                    $display("  Incoming data_in[3:0] : 4'b%04b", data_in);
                    $display("  Buffered MSB          : 4'b%04b", msb_buf);
                    $display("  Assembled 8-Bit Data  : 8'b%08b (0x%02X)", full_assembled_byte, full_assembled_byte);
                    $display("  XOR Encrypted Byte    : 8'b%08b (0x%02X)", full_encrypted_byte, full_encrypted_byte);

                    // Write directly into the targeted byte address
                    mem[dec_wr_addr] <= full_encrypted_byte;
                    $display("  [SUCCESS] Written into memory address %0d", dec_wr_addr);
                end
            end

            // --- Read Path: 1-Clock Parallel Decrypted Readout ---
            if (!ren) begin
                data_out <= 8'h00;
            end else begin
                // Read and decrypt directly from the addressed memory location
                data_out <= mem[dec_rd_addr] ^ CIPHER_KEY;

                $display("\n[DECODER-DRIVEN READOUT]");
                $display("  Read Target dec_rd_addr: %0d", dec_rd_addr);
                $display("  Read Memory Encrypted  : 8'b%08b (0x%02X)", mem[dec_rd_addr], mem[dec_rd_addr]);
                $display("  Decrypted data_out Bus : 8'b%08b (0x%02X)", mem[dec_rd_addr] ^ CIPHER_KEY, mem[dec_rd_addr] ^ CIPHER_KEY);
            end
        end
    end

endmodule
