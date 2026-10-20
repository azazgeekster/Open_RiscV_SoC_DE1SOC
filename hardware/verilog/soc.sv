// Top-level System-on-Chip (PicoRV32 RV32I + AHB-Lite Interconnect)

module soc #(
  parameter ENABLE_MUL      = 0,
  parameter ENABLE_FAST_MUL = 0,
  parameter ENABLE_DIV      = 0
)(

  input HCLK, HRESETn,

  input [31:0] iPort,

  output [31:0] oPort,
  output LOCKUP,

  input uart_rx,
  output uart_tx

);

  timeunit 1ns;
  timeprecision 100ps;

  // AHB Master bus signals
  logic [31:0] HADDR, HWDATA, HRDATA;
  logic [1:0]  HTRANS;
  logic [2:0]  HSIZE, HBURST;
  logic [3:0]  HPROT;
  logic        HWRITE, HMASTLOCK, HRESP, HREADY;

  // Slave interfaces
  logic HSEL_ROM, HSEL_RAM, HSEL_IPORT, HSEL_OPORT, HSEL_UART;
  logic [31:0] HRDATA_ROM, HRDATA_RAM, HRDATA_IPORT, HRDATA_OPORT, HRDATA_UART;
  logic HREADYOUT_ROM, HREADYOUT_RAM, HREADYOUT_IPORT, HREADYOUT_OPORT, HREADYOUT_UART;

  assign LOCKUP = 1'b0;
  assign HRESP  = 1'b0; // OKAY response

  // PicoRV32 AHB-Lite Master Core
  picorv32_ahb #(
    .ENABLE_MUL(ENABLE_MUL),
    .ENABLE_FAST_MUL(ENABLE_FAST_MUL),
    .ENABLE_DIV(ENABLE_DIV)
  ) riscv_1 (

    .HCLK, .HRESETn,
    .HADDR, .HBURST, .HMASTLOCK, .HPROT, .HSIZE, .HTRANS, .HWDATA, .HWRITE,
    .HRDATA, .HREADY, .HRESP

  );

  // AHB-Lite Interconnect (address decoder and response mux)
  ahb_interconnect interconnect_1 (

    .HCLK, .HRESETn, .HADDR, .HRDATA, .HREADY,

    .HSEL_SIGNALS({HSEL_UART,HSEL_OPORT,HSEL_IPORT,HSEL_RAM,HSEL_ROM}),
    .HRDATA_SIGNALS({HRDATA_UART,HRDATA_OPORT,HRDATA_IPORT,HRDATA_RAM,HRDATA_ROM}),
    .HREADYOUT_SIGNALS({HREADYOUT_UART,HREADYOUT_OPORT,HREADYOUT_IPORT,HREADYOUT_RAM,HREADYOUT_ROM})

  );

  // AHB Slaves
  ahb_rom rom_1 (

    .HCLK, .HRESETn, .HADDR, .HTRANS, .HWRITE, .HSIZE, .HREADY,
    .HSEL(HSEL_ROM),
    .HRDATA(HRDATA_ROM), .HREADYOUT(HREADYOUT_ROM)

  );

  ahb_ram ram_1 (

    .HCLK, .HRESETn, .HADDR, .HWDATA, .HSIZE, .HTRANS, .HWRITE, .HREADY,
    .HSEL(HSEL_RAM),
    .HRDATA(HRDATA_RAM), .HREADYOUT(HREADYOUT_RAM)

  );

  ahb_input_port in_1 (

    .HCLK, .HRESETn, .HADDR, .HWDATA, .HSIZE, .HTRANS, .HWRITE, .HREADY,
    .HSEL(HSEL_IPORT),
    .HRDATA(HRDATA_IPORT), .HREADYOUT(HREADYOUT_IPORT),

    .iPort(iPort)

  );

  ahb_output_port out_1 (

    .HCLK, .HRESETn, .HADDR, .HWDATA, .HSIZE, .HTRANS, .HWRITE, .HREADY,
    .HSEL(HSEL_OPORT),
    .HRDATA(HRDATA_OPORT), .HREADYOUT(HREADYOUT_OPORT),

    .oPort(oPort)

  );

  ahb_uart uart_1 (

    .HCLK, .HRESETn, .HADDR, .HWDATA, .HSIZE, .HTRANS, .HWRITE, .HREADY,
    .HSEL(HSEL_UART),
    .HRDATA(HRDATA_UART), .HREADYOUT(HREADYOUT_UART),

    .uart_rx(uart_rx),
    .uart_tx(uart_tx)

  );

`ifdef ASSERTIONS

  // SystemVerilog verification properties
  HTRANS_defined:
    assert property(@(posedge HCLK) disable iff (!HRESETn)
      ( ! $isunknown(HTRANS) )
    ) else $error("HTRANS is undefined: %b", HTRANS);

  HWRITE_defined:
    assert property(@(posedge HCLK) disable iff (!HRESETn)
      ( ! $isunknown(HWRITE) )
    ) else $error("HWRITE is undefined");

  HSIZE_defined:
    assert property(@(posedge HCLK) disable iff (!HRESETn)
      ( ! $isunknown(HSIZE) )
    ) else $error("HSIZE is undefined: %b", HSIZE);

  HADDR_defined:
    assert property(@(posedge HCLK) disable iff (!HRESETn)
      ( ! $isunknown(HADDR) )
    ) else $error("HADDR is undefined: %b", HADDR);

  HWDATA_defined:
    assert property(@(posedge HCLK) disable iff (!HRESETn)
      (HWRITE && HREADY) |=> ( ! $isunknown(HWDATA) )
    ) else $error("HWDATA is undefined during write data phase: %b", HWDATA);

`endif


endmodule
