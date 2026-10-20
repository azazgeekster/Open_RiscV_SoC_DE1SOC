// Board-level top module for Terasic DE1-SoC (Cyclone V 5CSEMA5F31C6)

module de1_soc_wrapper(

  input CLOCK_50,

  input [9:0] SW,
  input [2:0] KEY, // DE1-SoC keys are active low

  output [9:0] LEDR,
  output [6:0] HEX0,
  output [6:0] HEX1,
  output [6:0] HEX2,
  output [6:0] HEX3,
  output [6:0] HEX4,
  output [6:0] HEX5,

  input UART_RX,
  output UART_TX

);

  timeunit 1ns;
  timeprecision 100ps;

  localparam heartbeat_count_msb = 25;

  localparam seven_seg_L = ~7'b0111000;
  localparam seven_seg_E = ~7'b1111001;
  localparam seven_seg_o = ~7'b1011100;
  localparam seven_seg_off = ~7'b0000000;


  logic HCLK, HRESETn, LOCKUP, DataValid;
  logic [31:0] iPort, oPort;

  assign iPort = { 22'd0, SW }; // DE1-SoC has just 10 switches
  assign LEDR = oPort[9:0]; // DE1-SoC has just 10 LEDs
  assign DataValid = (oPort != -1);

  soc soc_inst(
    .HCLK(HCLK),
    .HRESETn(HRESETn),
    .oPort(oPort),
    .iPort(iPort),
    .LOCKUP(LOCKUP),
    .uart_rx(UART_RX),
    .uart_tx(UART_TX)
  );

  // Drive HRESETn directly from active low CPU KEY[2] button
  assign HRESETn = KEY[2];

  // Drive HCLK from 50MHz de0 board clock
  assign HCLK = CLOCK_50;



  // This code gives us a heartbeat signal
  //
  logic running, heartbeat;
  logic [heartbeat_count_msb:0] tick_count;
  always_ff @(posedge CLOCK_50 or negedge HRESETn )
    if ( ! HRESETn )
      begin
        running <= 0;
        heartbeat <= 0;
        tick_count <= 0;
      end
    else
      begin
        running <= 1;
        heartbeat = tick_count[heartbeat_count_msb] && tick_count[heartbeat_count_msb-2];
        tick_count <= tick_count + 1;
      end


  // these digits on the seven-segment display are not used here
  assign HEX0 = 7'b1111111;
  assign HEX1 = 7'b1111111;
  assign HEX2 = 7'b1111111;
  assign HEX3 = 7'b1111111;
  assign HEX4 = 7'b1111111;

  // HEX5 is status/heartbeat
  assign HEX5 = (LOCKUP) ? seven_seg_L : (!DataValid) ? seven_seg_E : (heartbeat) ? seven_seg_o : seven_seg_off;


endmodule
