// ============================================================================
// Module: spi_top.v
// Project: Physical Design Implementation of Serial Peripheral Interface Using Qflow
// Designer: K Azaan Ahamed | VLSI Physical Design
// Target: OSU018 (180nm) / Scalable CMOS Cell Library via Qflow Toolchain
// Description: Full-duplex SPI Master Controller supporting 8-bit transactions,
//              configurable clock polarity (CPOL) and clock phase (CPHA),
//              and status flags (busy, transfer complete).
// ============================================================================

`timescale 1ns / 1ps

module spi_top (
    input  wire       clk,        // System Clock (e.g. 50 MHz)
    input  wire       rst_n,      // Active-low asynchronous reset
    
    // Core Interface
    input  wire       start,      // Pulse to initiate 8-bit SPI transmission
    input  wire [7:0] tx_data,    // 8-bit data byte to transmit
    output reg  [7:0] rx_data,    // 8-bit received data byte
    output reg        busy,       // High while SPI transmission is in progress
    output reg        done,       // Single-cycle pulse upon transmission complete
    
    // SPI Physical Bus Interface
    output reg        sclk,       // Serial SPI Clock output
    output reg        mosi,       // Master Out Slave In
    input  wire       miso,       // Master In Slave Out
    output reg        cs_n        // Active-low Chip Select
);

    // SPI Configuration Parameters
    parameter CPOL = 1'b0;        // Clock Polarity: 0 = idle low, 1 = idle high
    parameter CPHA = 1'b0;        // Clock Phase: 0 = sample on leading edge, 1 = sample on trailing
    parameter CLK_DIV = 4;        // System clock cycles per SCLK half-period

    // Internal State Encoding
    localparam STATE_IDLE      = 3'b000;
    localparam STATE_LOAD      = 3'b001;
    localparam STATE_EDGE_LEAD = 3'b010;
    localparam STATE_EDGE_TRAIL= 3'b011;
    localparam STATE_FINISH    = 3'b100;

    reg [2:0] state;
    reg [2:0] bit_cnt;            // Tracks 8 bits (7 down to 0)
    reg [7:0] shift_tx;
    reg [7:0] shift_rx;
    reg [7:0] clk_div_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= STATE_IDLE;
            sclk        <= CPOL;
            mosi        <= 1'b0;
            cs_n        <= 1'b1;
            busy        <= 1'b0;
            done        <= 1'b0;
            rx_data     <= 8'b0;
            shift_tx    <= 8'b0;
            shift_rx    <= 8'b0;
            bit_cnt     <= 3'd0;
            clk_div_cnt <= 8'd0;
        end else begin
            done <= 1'b0; // Default pulse low

            case (state)
                STATE_IDLE: begin
                    sclk        <= CPOL;
                    cs_n        <= 1'b1;
                    busy        <= 1'b0;
                    mosi        <= 1'b0;
                    clk_div_cnt <= 8'd0;

                    if (start) begin
                        shift_tx <= tx_data;
                        bit_cnt  <= 3'd7;
                        busy     <= 1'b1;
                        cs_n     <= 1'b0; // Assert Chip Select
                        state    <= STATE_LOAD;
                    end
                end

                STATE_LOAD: begin
                    // Set initial MOSI bit
                    mosi <= shift_tx[bit_cnt];
                    clk_div_cnt <= 8'd0;
                    state <= STATE_EDGE_LEAD;
                end

                STATE_EDGE_LEAD: begin
                    if (clk_div_cnt == CLK_DIV - 1) begin
                        clk_div_cnt <= 8'd0;
                        sclk <= ~sclk; // Transition to Leading Edge
                        
                        // Sample MISO on leading edge if CPHA == 0
                        if (CPHA == 1'b0) begin
                            shift_rx[bit_cnt] <= miso;
                        end else begin
                            // In CPHA=1, drive next MOSI on leading edge
                            mosi <= shift_tx[bit_cnt];
                        end
                        state <= STATE_EDGE_TRAIL;
                    end else begin
                        clk_div_cnt <= clk_div_cnt + 1;
                    end
                end

                STATE_EDGE_TRAIL: begin
                    if (clk_div_cnt == CLK_DIV - 1) begin
                        clk_div_cnt <= 8'd0;
                        sclk <= ~sclk; // Transition back to Trailing Edge

                        // Sample MISO on trailing edge if CPHA == 1
                        if (CPHA == 1'b1) begin
                            shift_rx[bit_cnt] <= miso;
                        end

                        if (bit_cnt == 3'd0) begin
                            state <= STATE_FINISH;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                            // Update MOSI for next bit if CPHA == 0
                            if (CPHA == 1'b0) begin
                                mosi <= shift_tx[bit_cnt - 1];
                            end
                            state <= STATE_EDGE_LEAD;
                        end
                    end else begin
                        clk_div_cnt <= clk_div_cnt + 1;
                    end
                end

                STATE_FINISH: begin
                    rx_data <= shift_rx;
                    done    <= 1'b1;
                    busy    <= 1'b0;
                    cs_n    <= 1'b1; // De-assert Chip Select
                    sclk    <= CPOL;
                    state   <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
