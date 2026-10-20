// AHB-Lite 32-bit Read-Only Input Port

module ahb_input_port(

  // AHB interface
  input        HCLK,
  input        HRESETn,
  input [31:0] HADDR,
  input [31:0] HWDATA,
  input [2:0]  HSIZE,
  input [1:0]  HTRANS,
  input        HWRITE,
  input        HREADY,
  input        HSEL,
  output logic [31:0] HRDATA,
  output       HREADYOUT,

  // External input
  input [31:0] iPort

);

  timeunit 1ns;
  timeprecision 100ps;

  localparam No_Transfer = 2'b00;

  logic read_enable;

  // Address phase: sample read control
  always_ff @(posedge HCLK or negedge HRESETn)
    if ( ! HRESETn )
      read_enable <= 1'b0;
    else if ( HREADY && HSEL && (HTRANS != No_Transfer) )
      read_enable <= ! HWRITE;
    else
      read_enable <= 1'b0;

  // Data phase: drive read data
  always_comb
    if ( ! read_enable )
      HRDATA = 32'b0;
    else
      HRDATA = iPort;

  assign HREADYOUT = 1'b1; // Zero wait-state

endmodule
