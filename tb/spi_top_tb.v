// ============================================================================
// Testbench: spi_top_tb.v
// Verification testbench for SPI master controller RTL
// ============================================================================

`timescale 1ns / 1ps

module spi_top_tb;

    reg        clk;
    reg        rst_n;
    reg        start;
    reg  [7:0] tx_data;
    wire [7:0] rx_data;
    wire       busy;
    wire       done;
    wire       sclk;
    wire       mosi;
    reg        miso;
    wire       cs_n;

    // Instantiate Unit Under Test (UUT)
    spi_top #(
        .CPOL(1'b0),
        .CPHA(1'b0),
        .CLK_DIV(4)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .busy(busy),
        .done(done),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .cs_n(cs_n)
    );

    // Clock generator: 50 MHz (20ns period)
    always #10 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        start = 0;
        tx_data = 8'h00;
        miso = 1'b1;

        #40;
        rst_n = 1;
        #40;

        // Initiate 8-bit transmission of 0xA5 (10100101)
        @(posedge clk);
        start = 1;
        tx_data = 8'hA5;
        @(posedge clk);
        start = 0;

        // Wait for completion
        wait(done == 1'b1);
        #40;

        // Initiate second transaction 0x3C
        @(posedge clk);
        start = 1;
        tx_data = 8'h3C;
        @(posedge clk);
        start = 0;

        wait(done == 1'b1);
        #100;
        $finish;
    end

endmodule
