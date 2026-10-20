module ahb_interconnect #(
  parameter num_slaves = 5
)(
  input HCLK,
  input HRESETn,

  // AHB Master Interface
  input [31:0] HADDR,

  // Slave Select & Response Interfaces
  output logic [num_slaves-1:0]      HSEL_SIGNALS,
  input  logic [num_slaves-1:0]      HREADYOUT_SIGNALS,
  input  logic [num_slaves-1:0][31:0] HRDATA_SIGNALS,

  // Master Response
  output logic        HREADY,
  output logic [31:0] HRDATA
);

  logic [num_slaves-1:0] mux_sel;
  integer i;

  // Address decoder (Address Phase)
  //   0x0000_0000 - 0x0000_0FFF : ahb_rom    (Boot ROM)
  //   0x0000_1000 - 0x0000_3FFF : unmapped   (Decode miss -> DEADBEEF)
  //   0x0000_4000 - 0x3FFF_FFFF : ahb_ram    (System RAM)
  //   0x4000_0000 - 0x4FFF_FFFF : ahb_input_port  (Switches)
  //   0x5000_0000 - 0x5FFF_FFFF : ahb_output_port (LEDs)
  //   0x6000_0000+              : ahb_uart
  always_comb
    if ( HADDR < 32'h0000_1000 )
      HSEL_SIGNALS = 5'b00001; // ahb_rom
    else if ( HADDR < 32'h0000_4000 )
      HSEL_SIGNALS = 5'b00000; // unmapped gap
    else if ( HADDR < 32'h4000_0000 )
      HSEL_SIGNALS = 5'b00010; // ahb_ram
    else if ( HADDR < 32'h5000_0000 )
      HSEL_SIGNALS = 5'b00100; // ahb_input_port
    else if ( HADDR < 32'h6000_0000 )
      HSEL_SIGNALS = 5'b01000; // ahb_output_port
    else
      HSEL_SIGNALS = 5'b10000; // ahb_uart

  // Slave select pipeline register (Data Phase)
  always_ff @(posedge HCLK or negedge HRESETn)
    if( ! HRESETn )
      mux_sel <= {num_slaves{1'b0}};
    else if( HREADY )
      mux_sel <= HSEL_SIGNALS;

  // Read data and ready multiplexer
  always_comb
    begin
      HREADY = 1'b1;
      HRDATA = 32'hDEADBEEF; // Unmapped address default

      for ( i = 0; i < num_slaves; i++ )
        if ( mux_sel == (1 << i) )
          begin
            HREADY = HREADYOUT_SIGNALS[i];
            HRDATA = HRDATA_SIGNALS[i];
          end
    end

endmodule
