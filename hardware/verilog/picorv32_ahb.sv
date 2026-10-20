/***************************************************************
 * picorv32_ahb
 ***************************************************************/

module picorv32_ahb #(
	parameter [ 0:0] ENABLE_COUNTERS = 1,
	parameter [ 0:0] ENABLE_COUNTERS64 = 1,
	parameter [ 0:0] ENABLE_REGS_16_31 = 1,
	parameter [ 0:0] ENABLE_REGS_DUALPORT = 1,
	parameter [ 0:0] TWO_STAGE_SHIFT = 1,
	parameter [ 0:0] BARREL_SHIFTER = 0,
	parameter [ 0:0] TWO_CYCLE_COMPARE = 0,
	parameter [ 0:0] TWO_CYCLE_ALU = 0,
	parameter [ 0:0] COMPRESSED_ISA = 0,
	parameter [ 0:0] CATCH_MISALIGN = 1,
	parameter [ 0:0] CATCH_ILLINSN = 1,
	parameter [ 0:0] ENABLE_PCPI = 0,
	parameter [ 0:0] ENABLE_MUL = 0,
	parameter [ 0:0] ENABLE_FAST_MUL = 0,
	parameter [ 0:0] ENABLE_DIV = 0,
	parameter [ 0:0] ENABLE_IRQ = 0,
	parameter [ 0:0] ENABLE_IRQ_QREGS = 1,
	parameter [ 0:0] ENABLE_IRQ_TIMER = 1,
	parameter [ 0:0] ENABLE_TRACE = 0,
	parameter [ 0:0] REGS_INIT_ZERO = 0,
	parameter [31:0] MASKED_IRQ = 32'h 0000_0000,
	parameter [31:0] LATCHED_IRQ = 32'h ffff_ffff,
	parameter [31:0] PROGADDR_RESET = 32'h 0000_0000,
	parameter [31:0] PROGADDR_IRQ = 32'h 0000_0010,
	parameter [31:0] STACKADDR = 32'h ffff_ffff
) (
	output logic trap,

	// AHB-Lite interfaces
	input logic HRESETn,
	input logic HCLK,

	output logic [31:0] HADDR,
	output logic        HWRITE,
	output logic [ 1:0] HTRANS,
	output logic [ 2:0] HSIZE,
	output logic [ 2:0] HBURST,
	output logic [ 3:0] HPROT,
	output logic        HMASTLOCK,

	output logic [31:0] HWDATA,
	input  logic [31:0] HRDATA,
	input  logic        HREADY,
	input  logic        HRESP,

	// Pico Co-Processor Interface (PCPI)
	output logic        pcpi_valid,
	output logic [31:0] pcpi_insn,
	output logic [31:0] pcpi_rs1,
	output logic [31:0] pcpi_rs2,
	input  logic        pcpi_wr,
	input  logic [31:0] pcpi_rd,
	input  logic        pcpi_wait,
	input  logic        pcpi_ready,

	// IRQ interface
	input  logic [31:0] irq,
	output logic [31:0] eoi,

`ifdef RISCV_FORMAL
	output logic        rvfi_valid,
	output logic [63:0] rvfi_order,
	output logic [31:0] rvfi_insn,
	output logic        rvfi_trap,
	output logic        rvfi_halt,
	output logic        rvfi_intr,
	output logic [ 1:0] rvfi_mode,
	output logic [ 1:0] rvfi_ixl,
	output logic [ 4:0] rvfi_rs1_addr,
	output logic [ 4:0] rvfi_rs2_addr,
	output logic [31:0] rvfi_rs1_rdata,
	output logic [31:0] rvfi_rs2_rdata,
	output logic [ 4:0] rvfi_rd_addr,
	output logic [31:0] rvfi_rd_wdata,
	output logic [31:0] rvfi_pc_rdata,
	output logic [31:0] rvfi_pc_wdata,
	output logic [31:0] rvfi_mem_addr,
	output logic [ 3:0] rvfi_mem_rmask,
	output logic [ 3:0] rvfi_mem_wmask,
	output logic [31:0] rvfi_mem_rdata,
	output logic [31:0] rvfi_mem_wdata,
`endif

	// Trace Interface
	output logic        trace_valid,
	output logic [35:0] trace_data

);

	timeunit 1ns;
	timeprecision 1ps;

	logic        mem_la_read;
	logic        mem_la_write;
	logic [31:0] mem_la_addr;
	logic [ 3:0] mem_la_wstrb;
	logic        mem_valid;

	logic        resetn;


	// picorv32 expects a synchronous reset but
	// the rest of the system uses asynchronous reset
	// to get around this, create a synchronous resetn
	// signal for picorv32
	always_ff @(posedge HCLK or negedge HRESETn)
	  if ( !HRESETn )
	    resetn <= 0;
	  else
	    resetn <= 1;


	picorv32 #(
		.ENABLE_COUNTERS     (ENABLE_COUNTERS     ),
		.ENABLE_COUNTERS64   (ENABLE_COUNTERS64   ),
		.ENABLE_REGS_16_31   (ENABLE_REGS_16_31   ),
		.ENABLE_REGS_DUALPORT(ENABLE_REGS_DUALPORT),
		.TWO_STAGE_SHIFT     (TWO_STAGE_SHIFT     ),
		.BARREL_SHIFTER      (BARREL_SHIFTER      ),
		.TWO_CYCLE_COMPARE   (TWO_CYCLE_COMPARE   ),
		.TWO_CYCLE_ALU       (TWO_CYCLE_ALU       ),
		.COMPRESSED_ISA      (COMPRESSED_ISA      ),
		.CATCH_MISALIGN      (CATCH_MISALIGN      ),
		.CATCH_ILLINSN       (CATCH_ILLINSN       ),
		.ENABLE_PCPI         (ENABLE_PCPI         ),
		.ENABLE_MUL          (ENABLE_MUL          ),
		.ENABLE_FAST_MUL     (ENABLE_FAST_MUL     ),
		.ENABLE_DIV          (ENABLE_DIV          ),
		.ENABLE_IRQ          (ENABLE_IRQ          ),
		.ENABLE_IRQ_QREGS    (ENABLE_IRQ_QREGS    ),
		.ENABLE_IRQ_TIMER    (ENABLE_IRQ_TIMER    ),
		.ENABLE_TRACE        (ENABLE_TRACE        ),
		.REGS_INIT_ZERO      (REGS_INIT_ZERO      ),
		.MASKED_IRQ          (MASKED_IRQ          ),
		.LATCHED_IRQ         (LATCHED_IRQ         ),
		.PROGADDR_RESET      (PROGADDR_RESET      ),
		.PROGADDR_IRQ        (PROGADDR_IRQ        ),
		.STACKADDR           (STACKADDR           )
	) picorv32_core (
		.clk      (HCLK   ),
		.resetn   (resetn),
		.trap     (trap   ),

		.mem_valid(mem_valid),
		.mem_la_read (mem_la_read ),
		.mem_la_write (mem_la_write ),
		.mem_la_addr (mem_la_addr ),
		.mem_la_wstrb(mem_la_wstrb),

		.mem_wdata(HWDATA),
		.mem_rdata(HRDATA),
		.mem_ready(HREADY),

		.pcpi_valid(pcpi_valid),
		.pcpi_insn (pcpi_insn ),
		.pcpi_rs1  (pcpi_rs1  ),
		.pcpi_rs2  (pcpi_rs2  ),
		.pcpi_wr   (pcpi_wr   ),
		.pcpi_rd   (pcpi_rd   ),
		.pcpi_wait (pcpi_wait ),
		.pcpi_ready(pcpi_ready),

		.irq(irq),
		.eoi(eoi),

`ifdef RISCV_FORMAL
		.rvfi_valid    (rvfi_valid    ),
		.rvfi_order    (rvfi_order    ),
		.rvfi_insn     (rvfi_insn     ),
		.rvfi_trap     (rvfi_trap     ),
		.rvfi_halt     (rvfi_halt     ),
		.rvfi_intr     (rvfi_intr     ),
		.rvfi_rs1_addr (rvfi_rs1_addr ),
		.rvfi_rs2_addr (rvfi_rs2_addr ),
		.rvfi_rs1_rdata(rvfi_rs1_rdata),
		.rvfi_rs2_rdata(rvfi_rs2_rdata),
		.rvfi_rd_addr  (rvfi_rd_addr  ),
		.rvfi_rd_wdata (rvfi_rd_wdata ),
		.rvfi_pc_rdata (rvfi_pc_rdata ),
		.rvfi_pc_wdata (rvfi_pc_wdata ),
		.rvfi_mem_addr (rvfi_mem_addr ),
		.rvfi_mem_rmask(rvfi_mem_rmask),
		.rvfi_mem_wmask(rvfi_mem_wmask),
		.rvfi_mem_rdata(rvfi_mem_rdata),
		.rvfi_mem_wdata(rvfi_mem_wdata),
`endif

		.trace_valid(trace_valid),
		.trace_data (trace_data)
	);

	// convert native memory signals to AHB-Lite equivalents:

	logic [ 1:0] HADDR_byte;

	// confusingly mem_la_wstrb is for read and write whereas mem_wstrb is only for write
	always_comb
	  case ( mem_la_wstrb )
	    4'b0001 : begin HSIZE = 3'b000; HADDR_byte = 0; end // byte access
	    4'b0010 : begin HSIZE = 3'b000; HADDR_byte = 1; end // byte access
	    4'b0100 : begin HSIZE = 3'b000; HADDR_byte = 2; end // byte access
	    4'b1000 : begin HSIZE = 3'b000; HADDR_byte = 3; end // byte access

	    4'b0011 : begin HSIZE = 3'b001; HADDR_byte = 0; end // half word access
	    4'b1100 : begin HSIZE = 3'b001; HADDR_byte = 2; end // half word access

	    default : begin HSIZE = 3'b010; HADDR_byte = 0; end // word access
	  endcase

	assign HWRITE  = mem_la_write;
	assign HADDR   = { mem_la_addr[31:2] , HADDR_byte[1:0] };
	assign HTRANS = ( mem_la_read || mem_la_write ) ? 2 : 0; // Non-Sequential or Idle only
	assign HPROT = 4'b0001; // this will default to data fetch (user access, non-bufferable, non-cacheable)
	assign HMASTLOCK = 1'b0; // no locked transactions
	assign HBURST = 3'b000; // no burst transactions


endmodule
