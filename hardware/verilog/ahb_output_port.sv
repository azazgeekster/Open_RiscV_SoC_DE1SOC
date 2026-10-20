// AHB-Lite 32-bit Read/Write Output Port

module ahb_output_port(

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

  // External output
  output logic [31:0] oPort

);

  timeunit 1ns;
  timeprecision 100ps;

  localparam No_Transfer = 2'b00;

  logic write_enable, read_enable;

  // Address phase: sample control signals
  always_ff @(posedge HCLK or negedge HRESETn)
    if ( ! HRESETn )
      begin
        write_enable <= 1'b0;
        read_enable  <= 1'b0;
      end
    else if ( HREADY && HSEL && (HTRANS != No_Transfer) )
      begin
        write_enable <= HWRITE;
        read_enable  <= ! HWRITE;
      end
    else
      begin
        write_enable <= 1'b0;
        read_enable  <= 1'b0;
      end

  // Data phase: write register
  always_ff @(posedge HCLK or negedge HRESETn)
    if ( ! HRESETn )
      oPort <= 32'b0;
    else if ( write_enable )
      oPort <= HWDATA;

  // Data phase: read register
  always_comb
    if ( ! read_enable )
      HRDATA = 32'b0;
    else
      HRDATA = oPort;

  assign HREADYOUT = 1'b1; // Zero wait-state

endmodule
