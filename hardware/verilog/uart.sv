// Simple UART transmitter and receiver
module uart #(
    parameter integer CLOCK_FREQ = 50000000,
    parameter integer BAUD_RATE = 115200
)(
    input clk,
    input resetn,

    // serial pins
    input  rx,
    output logic tx,

    // transmit interface
    input      [7:0] tx_data,
    input            tx_valid,
    output logic     tx_ready,

    // receive interface
    output logic [7:0] rx_data,
    output logic       rx_valid,
    input              rx_ready
);
    localparam integer DIVIDE = CLOCK_FREQ / BAUD_RATE;

    // transmitter
    logic [31:0] tx_divcnt;
    logic [3:0]  tx_bitcnt;
    logic [9:0]  tx_shift;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            tx_divcnt <= 0;
            tx_bitcnt <= 0;
            tx_shift  <= 10'b1111111111;
            tx        <= 1'b1;
            tx_ready  <= 1'b1;
        end else begin
            if (tx_bitcnt != 0) begin
                if (tx_divcnt == DIVIDE-1) begin
                    tx_divcnt <= 0;
                    tx <= tx_shift[1];
                    tx_shift <= {1'b1, tx_shift[9:1]};
                    tx_bitcnt <= tx_bitcnt - 1'b1;
                    if (tx_bitcnt == 1)
                        tx_ready <= 1'b1;
                end else begin
                    tx_divcnt <= tx_divcnt + 1'b1;
                end
            end else begin
                if (tx_valid) begin
                    tx <= 1'b0;
                    tx_shift <= {1'b1, tx_data, 1'b0};
                    tx_bitcnt <= 10;
                    tx_divcnt <= 0;
                    tx_ready <= 1'b0;
                end else begin
                    tx <= 1'b1;
                    tx_ready <= 1'b1;
                end
            end
        end
    end

    // receiver
    logic [31:0] rx_divcnt;
    logic [3:0]  rx_bitcnt;
    logic [7:0]  rx_shift;
    logic        rx_busy;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            rx_divcnt <= 0;
            rx_bitcnt <= 0;
            rx_shift  <= 0;
            rx_data   <= 0;
            rx_valid  <= 0;
            rx_busy   <= 0;
        end else begin
            if (rx_bitcnt != 0) begin
                if (rx_divcnt == DIVIDE-1) begin
                    rx_divcnt <= 0;
                    rx_shift <= {rx, rx_shift[7:1]};
                    rx_bitcnt <= rx_bitcnt - 1'b1;
                    
                    if (rx_bitcnt == 2) begin
                        // Middle of D7: capture the data byte
                        rx_data <= {rx, rx_shift[7:1]};
                        rx_valid <= 1'b1;
                    end else if (rx_bitcnt == 1) begin
                        // Middle of Stop bit: free the receiver
                        rx_busy <= 0;
                    end
                end else begin
                    rx_divcnt <= rx_divcnt + 1'b1;
                end
            end else if (!rx && !rx_busy) begin
                // start bit detected
                rx_busy <= 1'b1;
                rx_divcnt <= DIVIDE/2;
                rx_bitcnt <= 10; // 1 start + 8 data + 1 stop
                rx_shift <= 0;
            end

            if (rx_valid && rx_ready)
                rx_valid <= 0;
        end
    end
endmodule
