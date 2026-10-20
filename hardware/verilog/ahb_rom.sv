// AHB-Lite Boot ROM with Byte Lane Decoding

`ifdef BOOTROM_FILE
  // already defined
`else
  `define BOOTROM_FILE  "bootrom.hex"
`endif

module ahb_rom #(
  parameter MEMWIDTH = 12
)(
  // AHB-Lite Interface
  input        HSEL,
  input        HCLK,
  input        HRESETn,
  input        HREADY,
  input [31:0] HADDR,
  input [1:0]  HTRANS,
  input        HWRITE,
  input [2:0]  HSIZE,
  output       HREADYOUT,
  output logic [31:0] HRDATA
);

  timeunit 1ns;
  timeprecision 100ps;

  localparam No_Transfer = 2'b00;

  // ROM array: 4 byte lanes per 32-bit word
  logic [3:0][7:0] memory[0:(2**(MEMWIDTH-2)-1)];
  logic [31:0] data_from_memory;

  logic read_enable;
  logic [MEMWIDTH-3:0] read_address, saved_read_address;
  logic [3:0] byte_select;

  initial
    $readmemh(`BOOTROM_FILE, memory, 0, (2**(MEMWIDTH-2)-1));

  // Address phase: register control signals and byte lane mask
  always_ff @(posedge HCLK or negedge HRESETn)
    if (!HRESETn)
      begin
        read_enable <= 1'b0;
        byte_select <= 4'b0;
      end
    else if (HREADY && HSEL && (HTRANS != No_Transfer))
      begin
        read_enable <= !HWRITE;
        byte_select <= generate_byte_select(HSIZE, HADDR[1:0]);
      end
    else
      begin
        read_enable <= 1'b0;
        byte_select <= 4'b0;
      end

  // Read address generation
  always_comb
    if (HREADY && HSEL && (HTRANS != No_Transfer) && !HWRITE)
      read_address = HADDR[MEMWIDTH-1:2];
    else
      read_address = saved_read_address;

  always_ff @(posedge HCLK or negedge HRESETn)
    if (!HRESETn)
      saved_read_address <= {MEMWIDTH-2{1'b0}};
    else
      saved_read_address <= read_address;

  // Data phase: synchronous read
  always_ff @(posedge HCLK)
    data_from_memory = memory[read_address];

  // Read data output
  assign HRDATA[ 7: 0] = (read_enable && byte_select[0]) ? data_from_memory[ 7: 0] : 8'b0;
  assign HRDATA[15: 8] = (read_enable && byte_select[1]) ? data_from_memory[15: 8] : 8'b0;
  assign HRDATA[23:16] = (read_enable && byte_select[2]) ? data_from_memory[23:16] : 8'b0;
  assign HRDATA[31:24] = (read_enable && byte_select[3]) ? data_from_memory[31:24] : 8'b0;

  assign HREADYOUT = 1'b1; // Zero wait-state

  // Byte lane decoder from HSIZE and address low bits
  function logic [3:0] generate_byte_select(input logic [2:0] size, input logic [1:0] byte_addr);
    logic byte3, byte2, byte1, byte0;
    byte0 = size[1] || (byte_addr == 0);
    byte1 = size[1] || (size[0] && (byte_addr == 0)) || (byte_addr == 1);
    byte2 = size[1] || (byte_addr == 2);
    byte3 = size[1] || (size[0] && (byte_addr == 2)) || (byte_addr == 3);
    return {byte3, byte2, byte1, byte0};
  endfunction

endmodule
