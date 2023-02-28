/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP PM Hart
    (c) 2021, 2022 by Parretto B.V.

    History
    =======
    v1.0 - Initial release

    License
    =======
    This License will apply to the use of the IP-core (as defined in the License). 
    Please read the License carefully so that you know what your rights and obligations are when using the IP-core.
    The acceptance of this License constitutes a valid and binding agreement between Parretto and you for the use of the IP-core. 
    If you download and/or make any use of the IP-core you agree to be bound by this License. 
    The License is available for download and print at www.parretto.com/license.html
    Parretto grants you, as the Licensee, a free, non-exclusive, non-transferable, limited right to use the IP-core 
    solely for internal business purposes for the term and conditions of the License. 
    You are also allowed to create Modifications for internal business purposes, but explicitly only under the conditions of art. 3.2.
    You are, however, obliged to pay the License Fees to Parretto for the use of the IP-core, or any Modification, in, or embodied in, 
    a physical or non-tangible product or service that has substantial commercial, industrial or non-consumer uses. 
*/

`default_nettype none

// Module
module prt_dp_pm_hart
(
	// Clocks and reset
  	input wire					RST_IN,			// Reset
	input wire					CLK_IN,			// Clock

	// ROM interface
	prt_dp_rom_if.mst				ROM_IF,

	// RAM interface
	prt_dp_ram_if.mst				RAM_IF,

	// Config
	input wire [3:0]  				CFG_THREAD_EN_IN,	// Thread enable

	// Status
	output wire 					STA_ERR_OUT			// Error
);

// Parameters
localparam P_THREADS		= 4;					// Number of threads
localparam P_THEAD_BITS 		= $clog2(P_THREADS);	// Thread bits
localparam P_REGS			= 16;				// Number of registers
localparam P_REG_INDEX_BITS 	= $clog2(P_REGS);		// Register index bits
localparam P_MEM_ADR_BITS	= 16;
localparam P_PC_BITS 		= P_MEM_ADR_BITS;		// Program counter width

// Enum
typedef enum {
	is_err,
	is_lui, is_auipc, is_jal, is_jalr,
	is_beq, is_bne, is_blt, is_bltu, is_bge, is_bgeu,
	is_lb, is_lh, is_lw, is_lbu, is_lhu,
	is_sb, is_sh, is_sw,
	is_addi, is_slti, is_sltiu, is_xori, is_ori, is_andi, is_slli, is_srli, is_srai,
	is_add, is_sub, is_sll, is_slt, is_sltu, is_xor, is_srl, is_sra, is_or, is_and
} is_type;

// ALU input select
typedef enum {
	alu_sel_rs1, alu_sel_pc,																		// A-input
	alu_sel_rs2, alu_sel_u_type, alu_sel_i_type_signed, alu_sel_i_type_unsigned, alu_sel_const_4	// B-input
} alu_sel;

// ALU operation
typedef enum {
	alu_op_add, alu_op_sub, alu_op_xor, alu_op_or, alu_op_and, alu_op_set
} alu_op;

// Barrel shifter input select
typedef enum {
	bs_sel_rs2, bs_sel_i_type		// B-input
} bs_sel;

// Barrel shifter operation
typedef enum {
	bs_op_sll, bs_op_srl, bs_op_sra
} bs_op;

typedef struct {
	logic signed	[P_PC_BITS-1:0]				r[0:P_THREADS-1];	// Register
	logic signed	[P_PC_BITS-1:0]				off;				// Offset
	logic signed	[P_PC_BITS-1:0]				base;			// Base
	logic signed	[P_PC_BITS-1:0]				nxt;				// Next
} pc_struct;

typedef struct {
	logic			[P_REG_INDEX_BITS-1:0]		rd_index;					// Destination register index
	logic			[31:0]					rd_dat;					// Destination register data
	logic									rd_wr[P_THREADS-1:0];		// Destination register write
	logic			[P_REG_INDEX_BITS-1:0]		rs1_index[P_THREADS-1:0];	// Source register 1 index
	logic			[P_REG_INDEX_BITS-1:0]		rs2_index[P_THREADS-1:0];	// Source register 2 index
	logic			[31:0]					rs1[0:P_THREADS-1];			// Source register 1
	logic			[31:0]					rs2[0:P_THREADS-1];			// Source register 2
} reg_struct;

typedef struct {
	logic									br;				// Branch
	logic									err;				// Error
} flag_struct;

typedef struct {
	alu_sel									a_sel;			// Input A select
	alu_sel									b_sel;			// Input B select
	alu_op									op;				// Operation
} alu_dec_struct;

typedef struct {
	alu_sel									a_sel;			// Input A select
	alu_sel									b_sel;			// Input B select
	alu_op									op;				// Operation
	logic signed	[31:0]						a;				// Input A
	logic signed	[31:0]						b;				// Input B
	logic signed	[31:0]						c;				// Output C
} alu_exe_struct;

typedef struct {
	bs_sel									b_sel;			// Input B select
	bs_op									op;				// Operation
} bs_dec_struct;

typedef struct {
	bs_sel									b_sel;			// Input B select
	bs_op									op;				// Operation
	logic									msb;
	logic 			[31:0]					a;				// Input A
	logic 			[4:0]					b;				// Input B
	logic 			[31:0]					c;				// Output A
} bs_exe_struct;

typedef struct {
	logic									run;				// Run
	logic			[P_THEAD_BITS-1:0]			thread;			// Active thread
	logic			[P_PC_BITS-1:0]			pc;				// Program counter
} fetch_struct;

typedef struct {
	logic									run;				// Run
	is_type									is;				// Instruction
	logic			[P_THEAD_BITS-1:0]			thread;			// Active thread
	logic			[P_REG_INDEX_BITS-1:0]		rd_index;			// Destination index
	logic			[P_REG_INDEX_BITS-1:0]		rs1_index;		// Source register 1 index
	logic			[P_REG_INDEX_BITS-1:0]		rs2_index;		// Source register 2 index
	logic signed	[19:0]						imm;				// Immediate data (20 bits)
	alu_dec_struct								alu;				// ALU
	bs_dec_struct								bs;				// Barrel shifter
} dec_struct;

typedef struct {
	logic									run;				// Run
	is_type									is;				// Instruction
	logic			[P_THEAD_BITS-1:0]			thread;			// Active thread
	logic			[P_PC_BITS-1:0]			pc;				// Program counter
	logic			[P_REG_INDEX_BITS-1:0]		rd_index;			// Destination index
	logic			[P_REG_INDEX_BITS-1:0]		rs1_index;		// Source register 1 index
	logic			[P_REG_INDEX_BITS-1:0]		rs2_index;		// Source register 2 index
	logic signed	[31:0]						rs1;				// Source register 1
	logic signed	[31:0]						rs2;				// Source register 2
	logic signed	[19:0]						imm;				// Immediate data (20 bits)
	alu_exe_struct								alu;				// ALU
	bs_exe_struct								bs;				// Barrel shifter
	flag_struct								flag;			// Flags
} exe_struct;

typedef struct {
	logic									run;				// Run
	is_type									is;				// Instruction
	logic			[P_THEAD_BITS-1:0]			thread;			// Active thread
	logic			[P_PC_BITS-1:0]			pc;				// Program counter
	logic			[P_REG_INDEX_BITS-1:0]		rd_index;			// Destination index
	logic			[P_REG_INDEX_BITS-1:0]		rs1_index;		// Source register 1 index
	logic			[P_REG_INDEX_BITS-1:0]		rs2_index;		// Source register 2 index
	logic signed	[31:0]						rs1;				// Source register 1
	logic signed	[31:0]						rs2;				// Source register 2
	logic signed	[19:0]						imm;				// Immediate data (20 bits)
	logic			[1:0]					ram_rd_adr_lsb;	// Ram read address lower bits
} wr_struct;

typedef struct {
	logic signed	[P_MEM_ADR_BITS-1:0]			wr_adr;
	logic signed	[P_MEM_ADR_BITS-1:0]			rd_adr;
	logic 									rd;
	logic 									wr;
	logic 			[31:0]					dout;
	logic			[3:0]					strb;
} ram_struct;

genvar i;

// Signals
pc_struct		clk_pc;		// Program counter
reg_struct	clk_reg;		// Registers
fetch_struct	clk_fetch;	// Fetch
dec_struct	clk_dec;		// Decoder
exe_struct	clk_exe;		// Execute
wr_struct		clk_wr;		// Write
ram_struct	clk_ram;		// RAM memory

// Logic

/*
	Program counter
*/

// Program counter
generate
	for (i=0; i<P_THREADS; i++)
	begin : gen_pc
		always_ff @ (posedge RST_IN, posedge CLK_IN)
		begin
			// Reset
			if (RST_IN)
				clk_pc.r[i] <= i*4;

			else
			begin
				if (CFG_THREAD_EN_IN[i])
				begin
					if (clk_wr.run && (clk_wr.thread == i))
						clk_pc.r[i] <= clk_pc.nxt;
				end

				else
					clk_pc.r[i] <= i*4;
			end
		end
	end
endgenerate

// Program counter offset
// Must be combinatorial
	always_comb
	begin
		// Jump and link
		if (clk_wr.is == is_jal)
			clk_pc.off = clk_wr.imm[0+:P_PC_BITS];

		// Jump and link register
		else if (clk_wr.is == is_jalr)
			clk_pc.off = clk_wr.imm[0+:P_PC_BITS];

		// Branch
		else if (clk_exe.flag.br)
			clk_pc.off = clk_wr.imm[0+:P_PC_BITS];

		else
			clk_pc.off = 'd4;
	end

// Program counter base
// must be combinatorial
	always_comb
	begin
		if (clk_wr.is == is_jalr)
			clk_pc.base = clk_wr.rs1;
		else
			clk_pc.base = clk_wr.pc;
	end

// Program counter next
// must be combinatorial
	assign clk_pc.nxt = clk_pc.base + clk_pc.off;


/*
	Registers
*/
generate
	for (i=0; i<P_THREADS; i++)
	begin : gen_reg
		prt_dp_pm_hart_reg
		#(
			.P_REGS				(P_REGS),			// Number of registers
			.P_INDEX			(P_REG_INDEX_BITS)	// Register index width
		)
		REG_INST
		(
			// Clock
			.CLK_IN				(CLK_IN),			// Clock

			// Destination register
			.RD_INDEX_IN		(clk_reg.rd_index),
			.RD_DAT_IN			(clk_reg.rd_dat),
			.RD_WR_IN			(clk_reg.rd_wr[i]),

			// Source register 1
			.RS1_INDEX_IN		(clk_reg.rs1_index[i]),
			.RS1_DAT_OUT		(clk_reg.rs1[i]),

			// Source register 2
			.RS2_INDEX_IN		(clk_reg.rs2_index[i]),
			.RS2_DAT_OUT		(clk_reg.rs2[i])
		);

		// Source register 1 index


	end
endgenerate

// Destination register index
	assign clk_reg.rd_index = clk_wr.rd_index;

// Source register index
// To increase the fmax performance the source register indexes are registered. 
	always_ff @ (posedge CLK_IN)
	begin
		for (int i = 0; i < P_THREADS; i++)
		begin
			// The write instructions and jump register are refering to the source registers.
			// Due to the clock latency the source register indexes of the execution phase are used.
			if ((clk_exe.thread == i) && ((clk_exe.is == is_sw) || (clk_exe.is == is_sh) || (clk_exe.is == is_sb) || (clk_exe.is == is_jalr)))
			begin
				clk_reg.rs1_index[i] <= clk_exe.rs1_index;
				clk_reg.rs2_index[i] <= clk_exe.rs2_index;
			end

			// Other instructions
			// The source register content is needed during the execute phase. 
			// Due to the clock latency the decoder phase are used.
			else
			begin
				clk_reg.rs1_index[i] <= clk_dec.rs1_index;
				clk_reg.rs2_index[i] <= clk_dec.rs2_index;
			end
		end
	end

// Destination Register data
// Must be combinatorial
	always_comb
	begin
		// Load word
		if (clk_wr.is == is_lw)
			clk_reg.rd_dat = RAM_IF.din;

		// Load half word
		else if ((clk_wr.is == is_lh) || (clk_wr.is == is_lhu))
		begin
			// Upper word
			if (clk_wr.ram_rd_adr_lsb[1])
			begin
				// Unsigned
				if (clk_wr.is == is_lhu)
					clk_reg.rd_dat = {16'h0, RAM_IF.din[16+:16]};

				// Signed
				else
					clk_reg.rd_dat = $signed(RAM_IF.din[16+:16]);
			end

			// Lower word
			else
			begin
				// Unsigned
				if (clk_wr.is == is_lhu)
					clk_reg.rd_dat = {16'h0, RAM_IF.din[0+:16]};

				// Signed
				else
					clk_reg.rd_dat = $signed(RAM_IF.din[0+:16]);
			end
		end

		// Load byte
		else if ((clk_wr.is == is_lb) || (clk_wr.is == is_lbu))
		begin
			case (clk_wr.ram_rd_adr_lsb)
				'b01 :
				begin
					// Unsigned
					if (clk_wr.is == is_lbu)
						clk_reg.rd_dat = {24'h0, RAM_IF.din[(1*8)+:8]};

					// Signed
					else
						clk_reg.rd_dat = $signed(RAM_IF.din[(1*8)+:8]);
				end

				'b10 :
				begin
					// Unsigned
					if (clk_wr.is == is_lbu)
						clk_reg.rd_dat = {24'h0, RAM_IF.din[(2*8)+:8]};

					// Signed
					else
						clk_reg.rd_dat = $signed(RAM_IF.din[(2*8)+:8]);
				end

				'b11 :
				begin
					// Unsigned
					if (clk_wr.is == is_lbu)
						clk_reg.rd_dat = {24'h0, RAM_IF.din[(3*8)+:8]};

					// Signed
					else
						clk_reg.rd_dat = $signed(RAM_IF.din[(3*8)+:8]);
				end

				default :
				begin
					// Unsigned
					if (clk_wr.is == is_lbu)
						clk_reg.rd_dat = {24'h0, RAM_IF.din[0+:8]};

					// Signed
					else
						clk_reg.rd_dat = $signed(RAM_IF.din[0+:8]);
				end
			endcase
		end

		// Shift
		else if ((clk_wr.is == is_sll) || (clk_wr.is == is_srl) || (clk_wr.is == is_sra) || (clk_wr.is == is_slli) || (clk_wr.is == is_srli) || (clk_wr.is == is_srai))
			clk_reg.rd_dat = clk_exe.bs.c;

		// Default (ALU out)
		else
			clk_reg.rd_dat = clk_exe.alu.c;
	end

// Destination data write
	always_comb
	begin
		for (int i=0; i<P_THREADS; i++)
		begin
			if (clk_wr.thread == i)
				clk_reg.rd_wr[i] = 1;
			else
				clk_reg.rd_wr[i] = 0;
		end
	end


/*
	Fetch
*/

// Run
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_fetch.run <= 0;

		else
			clk_fetch.run <= 1;
	end

// Thread
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_fetch.thread <= 0;

		else
		begin
			// Run
			if (clk_fetch.run)
			begin
				// Overflow
				if (clk_fetch.thread == P_THREADS-1)
					clk_fetch.thread <= 0;

				// Increment
				else
					clk_fetch.thread <= clk_fetch.thread + 'd1;
			end
		end
	end

// Program counter
	assign clk_fetch.pc = clk_pc.r[clk_fetch.thread];


/*
	Decode
*/

// Run
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_dec.run <= 0;

		else
			clk_dec.run <= clk_fetch.run;
	end

// Thread
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_dec.thread <= 0;

		else
			clk_dec.thread <= clk_fetch.thread;
	end

// Decoder
	always_comb
	begin
		// Defaults
		clk_dec.is 			= is_err;
		clk_dec.imm			= 0;
		clk_dec.rd_index 		= 0;
		clk_dec.rs1_index 		= 0;
		clk_dec.rs2_index 		= 0;
		clk_dec.alu.a_sel 		= alu_sel_rs1;
		clk_dec.alu.b_sel 		= alu_sel_rs2;
		clk_dec.alu.op 		= alu_op_add;
		clk_dec.bs.b_sel		= bs_sel_rs2;
		clk_dec.bs.op 			= bs_op_sll;

		if (clk_dec.run)
		begin
			case (ROM_IF.dat[6:2])

				// Load
				'b00000 :
				begin
					clk_dec.rd_index = ROM_IF.dat[7+:P_REG_INDEX_BITS];
					clk_dec.rs1_index = ROM_IF.dat[15+:P_REG_INDEX_BITS];
					clk_dec.imm = $signed(ROM_IF.dat[31:20]);

					case (ROM_IF.dat[14:12])

						// Load byte
						'b000 :
						begin
							clk_dec.is	= is_lb;
						end

						// Load half word
						'b001 :
						begin
							clk_dec.is	= is_lh;
						end

						// Load word
						'b010 :
						begin
							clk_dec.is	= is_lw;
						end

						// Load byte unsigned
						'b100 :
						begin
							clk_dec.is	= is_lbu;
						end

						// Load half word unsigned
						'b101 :
						begin
							clk_dec.is	= is_lhu;
						end

						default : ;
					endcase
				end

				// OP-IMM
				'b00100 :
				begin
					clk_dec.rd_index 	= ROM_IF.dat[7+:P_REG_INDEX_BITS];
					clk_dec.rs1_index 	= ROM_IF.dat[15+:P_REG_INDEX_BITS];
					clk_dec.imm[11:0] 	= ROM_IF.dat[31:20];
					clk_dec.alu.a_sel 	= alu_sel_rs1;
					clk_dec.alu.b_sel 	= alu_sel_i_type_signed;
					clk_dec.bs.b_sel 	= bs_sel_i_type;

					case (ROM_IF.dat[14:12])

						// ADDI
						'b000 :
						begin
							clk_dec.is 			= is_addi;
							clk_dec.alu.op  	= alu_op_add;
						end

						// SLTI
						'b010 :
						begin
							clk_dec.is 			= is_slti;
							clk_dec.alu.op  	= alu_op_set;
						end

						// SLTIU
						'b011 :
						begin
							clk_dec.is 			= is_sltiu;
							clk_dec.alu.b_sel 	= alu_sel_i_type_unsigned;
							clk_dec.alu.op  	= alu_op_set;
						end

						// XORI
						'b100 :
						begin
							clk_dec.is 			= is_xori;
							clk_dec.alu.op  	= alu_op_xor;
						end

						// ORI
						'b110 :
						begin
							clk_dec.is			= is_ori;
							clk_dec.alu.op  	= alu_op_or;
						end

						// ANDI
						'b111 :
						begin
							clk_dec.is 			= is_andi;
							clk_dec.alu.op  	= alu_op_and;
						end

						// SLLI
						'b001 :
						begin
							clk_dec.is 			= is_slli;
							clk_dec.imm[4:0]	= ROM_IF.dat[20+:5];
							clk_dec.bs.op  		= bs_op_sll;
						end

						// SRLI
						'b101 :
						begin
							clk_dec.is 			= is_srli;
							clk_dec.imm[4:0] 	= ROM_IF.dat[20+:5];
							clk_dec.bs.op  		= bs_op_srl;
						end

						default : ;
					endcase
				end

				// OP
				'b01100 :
				begin
					clk_dec.rd_index 	= ROM_IF.dat[7+:P_REG_INDEX_BITS];
					clk_dec.rs1_index 	= ROM_IF.dat[15+:P_REG_INDEX_BITS];
					clk_dec.rs2_index 	= ROM_IF.dat[20+:P_REG_INDEX_BITS];
					clk_dec.alu.a_sel 	= alu_sel_rs1;
					clk_dec.alu.b_sel 	= alu_sel_rs2;
					clk_dec.bs.b_sel 	= bs_sel_rs2;

					case (ROM_IF.dat[14:12])

						// Add / sub
						'b000 :
						begin
							// Sub
							if (ROM_IF.dat[30])
							begin
								clk_dec.is 		= is_sub;
								clk_dec.alu.op 	= alu_op_sub;
							end

							// Add
							else
							begin
								clk_dec.is 		= is_add;
								clk_dec.alu.op 	= alu_op_add;
							end
						end

						// SLL
						'b001 :
						begin
							clk_dec.is 			= is_sll;
							clk_dec.bs.op  		= bs_op_sll;
						end

						// SLT
						'b010 :
						begin
							clk_dec.is 			= is_slt;
							clk_dec.alu.op 		= alu_op_set;
						end

						// SLTU
						'b011 :
						begin
							clk_dec.is			= is_slt;
							clk_dec.alu.op  	= alu_op_set;
						end

						// XOR
						'b100 :
						begin
							clk_dec.is 			= is_xori;
							clk_dec.alu.op 		= alu_op_xor;
						end

						// SRL/A
						'b101 :
						begin
							// Arithmetic
							if (ROM_IF.dat[30])
							begin
								clk_dec.is 		= is_sra;
								clk_dec.bs.op 	= bs_op_sra;
							end

							// Logical
							else
							begin
								clk_dec.is 		= is_srl;
								clk_dec.bs.op 	= bs_op_srl;
							end
						end

						// OR
						'b110 :
						begin
							clk_dec.is 			= is_ori;
							clk_dec.alu.op  	= alu_op_or;
						end

						// ANDI
						'b111 :
						begin
							clk_dec.is 			= is_andi;
							clk_dec.alu.op  	= alu_op_and;
						end

						default : ;
					endcase
				end

				// Store
				'b01000 :
				begin
					clk_dec.rs1_index = ROM_IF.dat[15+:P_REG_INDEX_BITS];
					clk_dec.rs2_index = ROM_IF.dat[20+:P_REG_INDEX_BITS];
					clk_dec.imm = $signed({ROM_IF.dat[31:25], ROM_IF.dat[11:7]});

					case (ROM_IF.dat[14:12])

						// Store byte
						'b000 :
						begin
							clk_dec.is 	= is_sb;
						end

						// Store half word
						'b001 :
						begin
							clk_dec.is	= is_sh;
						end

						// Store word
						'b010 :
						begin
							clk_dec.is	= is_sw;
						end

						default : ;
					endcase
				end

				// Branch
				'b11000 :
				begin
					clk_dec.rs1_index = ROM_IF.dat[15+:P_REG_INDEX_BITS];
					clk_dec.rs2_index = ROM_IF.dat[20+:P_REG_INDEX_BITS];
					clk_dec.imm = $signed({ROM_IF.dat[31], ROM_IF.dat[7], ROM_IF.dat[30:25], ROM_IF.dat[11:8], 1'b0});

					case (ROM_IF.dat[14:12])

						// BEQ
						'b000 :
						begin
							clk_dec.is = is_beq;
						end

						// BNE
						'b001 :
						begin
							clk_dec.is = is_bne;
						end

						// BLT
						'b100 :
						begin
							clk_dec.is = is_blt;
						end

						// BGE
						'b101 :
						begin
							clk_dec.is = is_bge;
						end

						// BLTU
						'b110 :
						begin
							clk_dec.is = is_bltu;
						end

						// BGEU
						'b111 :
						begin
							clk_dec.is = is_bgeu;
						end

						default : ;
					endcase
				end

				// JAL
				'b11011 :
				begin
					clk_dec.is 			= is_jal;
					clk_dec.rd_index 	= ROM_IF.dat[7+:P_REG_INDEX_BITS];
					clk_dec.imm			= $signed({ROM_IF.dat[31], ROM_IF.dat[19:12], ROM_IF.dat[20], ROM_IF.dat[30:21], 1'b0});
					clk_dec.alu.a_sel	= alu_sel_pc;
					clk_dec.alu.b_sel	= alu_sel_const_4;
					clk_dec.alu.op 		= alu_op_add;
				end

				// JALR
				'b11001 :
				begin
					clk_dec.is			= is_jalr;
					clk_dec.rd_index 	= ROM_IF.dat[7+:P_REG_INDEX_BITS];
					clk_dec.rs1_index 	= ROM_IF.dat[15+:P_REG_INDEX_BITS];
					clk_dec.imm			= $signed(ROM_IF.dat[31:20]);
					clk_dec.alu.a_sel	= alu_sel_pc;
					clk_dec.alu.b_sel	= alu_sel_const_4;
					clk_dec.alu.op 		= alu_op_add;
				end

				// LUI
				'b01101 :
				begin
					clk_dec.is 			= is_lui;
					clk_dec.rd_index 	= ROM_IF.dat[7+:P_REG_INDEX_BITS];
					clk_dec.imm			= ROM_IF.dat[31:12];
					clk_dec.alu.a_sel	= alu_sel_rs1;			// RS1 = zero
					clk_dec.alu.b_sel	= alu_sel_u_type;
					clk_dec.alu.op 		= alu_op_add;
				end

				// AUIPC
				'b00101 :
				begin
					clk_dec.is			= is_auipc;
					clk_dec.rd_index 	= ROM_IF.dat[7+:P_REG_INDEX_BITS];
					clk_dec.imm			= ROM_IF.dat[31:12];
					clk_dec.alu.a_sel	= alu_sel_pc;
					clk_dec.alu.b_sel	= alu_sel_u_type;
					clk_dec.alu.op 		= alu_op_add;
				end

				default : ;
			endcase
		end
	end

/*
	Execute
*/

// Run
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_exe.run <= 0;

		else
			clk_exe.run <= clk_dec.run;
	end

// Thread
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_exe.thread <= 0;

		else
			clk_exe.thread <= clk_dec.thread;
	end

// Copy from decode stage
	always_ff @ (posedge CLK_IN)
	begin
		clk_exe.is 		<= clk_dec.is;
		clk_exe.imm 		<= clk_dec.imm;
		clk_exe.rd_index 	<= clk_dec.rd_index;
		clk_exe.rs1_index 	<= clk_dec.rs1_index;
		clk_exe.rs2_index 	<= clk_dec.rs2_index;
		clk_exe.alu.a_sel 	<= clk_dec.alu.a_sel;
		clk_exe.alu.b_sel 	<= clk_dec.alu.b_sel;
		clk_exe.alu.op 	<= clk_dec.alu.op;
		clk_exe.bs.b_sel 	<= clk_dec.bs.b_sel;
		clk_exe.bs.op 		<= clk_dec.bs.op;
	end

// Source registers
	assign clk_exe.rs1 = clk_reg.rs1[clk_exe.thread];
	assign clk_exe.rs2 = clk_reg.rs2[clk_exe.thread];

// Program counter
	assign clk_exe.pc = clk_pc.r[clk_exe.thread];

// ALU
// A-input
// Must be combinatioral
	always_comb
	begin
		// Program counter
		if (clk_exe.alu.a_sel == alu_sel_pc)
			clk_exe.alu.a = clk_exe.pc;

		// Source register 1
		else
			clk_exe.alu.a = clk_exe.rs1;
	end

// B-input
// Must be combinatioral
	always_comb
	begin
		// U-type
		if (clk_exe.alu.b_sel == alu_sel_u_type)
			clk_exe.alu.b = {clk_exe.imm, 12'h0};

		// I-type Signed
		else if (clk_exe.alu.b_sel == alu_sel_i_type_signed)
			clk_exe.alu.b = $signed(clk_exe.imm[11:0]);

		// I-type Unsigned
		else if (clk_exe.alu.b_sel == alu_sel_i_type_unsigned)
			clk_exe.alu.b = {20'h0, clk_exe.imm[11:0]};

		// Constant 4
		else if (clk_exe.alu.b_sel == alu_sel_const_4)
			clk_exe.alu.b = 'd4;

		// Source register 2
		else
			clk_exe.alu.b = clk_exe.rs2;
	end

// ALU
	always_ff @ (posedge CLK_IN)
	begin
		// Opp code
		case (clk_exe.alu.op)

			// Set
			alu_op_set :
			begin
				// Pseudoinstruction SEQZ rd, rs
				if ((clk_exe.is == is_sltiu) && (clk_exe.imm == 'd1))
				begin
					if (clk_exe.alu.a == 0)
						clk_exe.alu.c <= 'd1;
					else
						clk_exe.alu.c <= 0;
				end

				else
				begin
					if (clk_exe.alu.a < clk_exe.alu.b)
						clk_exe.alu.c <= 'd1;
					else
						clk_exe.alu.c <= 0;
				end
			end

			// XOR
			alu_op_xor :
				clk_exe.alu.c <= clk_exe.alu.a ^ clk_exe.alu.b;

			// OR
			alu_op_or :
				clk_exe.alu.c <= clk_exe.alu.a | clk_exe.alu.b;

			// AND
			alu_op_and :
				clk_exe.alu.c <= clk_exe.alu.a & clk_exe.alu.b;

			// SUB
			alu_op_sub :
				clk_exe.alu.c <= clk_exe.alu.a - clk_exe.alu.b;

			// Add
			default :
				clk_exe.alu.c <= clk_exe.alu.a + clk_exe.alu.b;
		endcase
	end


//	Barrel shifter

// A-input
	assign clk_exe.bs.a = clk_exe.rs1;

// B-input
	always_comb
	begin
		// Immediate
		if (clk_exe.bs.b_sel == bs_sel_i_type)
			clk_exe.bs.b = clk_exe.imm[0+:$size(clk_exe.bs.b)];

		// Source register 2
		else
			clk_exe.bs.b = clk_exe.rs2[0+:$size(clk_exe.bs.b)];
	end

// MSB
	always_comb
	begin
		if (clk_exe.bs.op == bs_op_sra)
			clk_exe.bs.msb = clk_exe.bs.a[31];
		else
			clk_exe.bs.msb = 0;
	end

// Barrel shifter
	always_ff @ (posedge CLK_IN)
	begin
		// Shift left logical
		if (clk_exe.bs.op == bs_op_sll)
		begin
			case (clk_exe.bs.b)
				'd1  : clk_exe.bs.c <= {clk_exe.bs.a[0+:31], 1'h0};
				'd2  : clk_exe.bs.c <= {clk_exe.bs.a[0+:30], 2'h0};
				'd3  : clk_exe.bs.c <= {clk_exe.bs.a[0+:29], 3'h0};
				'd4  : clk_exe.bs.c <= {clk_exe.bs.a[0+:28], 4'h0};
				'd5  : clk_exe.bs.c <= {clk_exe.bs.a[0+:27], 5'h0};
				'd6  : clk_exe.bs.c <= {clk_exe.bs.a[0+:26], 6'h0};
				'd7  : clk_exe.bs.c <= {clk_exe.bs.a[0+:25], 7'h0};
				'd8  : clk_exe.bs.c <= {clk_exe.bs.a[0+:24], 8'h0};
				'd9  : clk_exe.bs.c <= {clk_exe.bs.a[0+:23], 9'h0};
				'd10 : clk_exe.bs.c <= {clk_exe.bs.a[0+:22], 10'h0};
				'd11 : clk_exe.bs.c <= {clk_exe.bs.a[0+:21], 11'h0};
				'd12 : clk_exe.bs.c <= {clk_exe.bs.a[0+:20], 12'h0};
				'd13 : clk_exe.bs.c <= {clk_exe.bs.a[0+:19], 13'h0};
				'd14 : clk_exe.bs.c <= {clk_exe.bs.a[0+:18], 14'h0};
				'd15 : clk_exe.bs.c <= {clk_exe.bs.a[0+:17], 15'h0};
				'd16 : clk_exe.bs.c <= {clk_exe.bs.a[0+:16], 16'h0};
				'd17 : clk_exe.bs.c <= {clk_exe.bs.a[0+:15], 17'h0};
				'd18 : clk_exe.bs.c <= {clk_exe.bs.a[0+:14], 18'h0};
				'd19 : clk_exe.bs.c <= {clk_exe.bs.a[0+:13], 19'h0};
				'd20 : clk_exe.bs.c <= {clk_exe.bs.a[0+:12], 20'h0};
				'd21 : clk_exe.bs.c <= {clk_exe.bs.a[0+:11], 21'h0};
				'd22 : clk_exe.bs.c <= {clk_exe.bs.a[0+:10], 22'h0};
				'd23 : clk_exe.bs.c <= {clk_exe.bs.a[0+:9], 23'h0};
				'd24 : clk_exe.bs.c <= {clk_exe.bs.a[0+:8], 24'h0};
				'd25 : clk_exe.bs.c <= {clk_exe.bs.a[0+:7], 25'h0};
				'd26 : clk_exe.bs.c <= {clk_exe.bs.a[0+:6], 26'h0};
				'd27 : clk_exe.bs.c <= {clk_exe.bs.a[0+:5], 27'h0};
				'd28 : clk_exe.bs.c <= {clk_exe.bs.a[0+:4], 28'h0};
				'd29 : clk_exe.bs.c <= {clk_exe.bs.a[0+:3], 29'h0};
				'd30 : clk_exe.bs.c <= {clk_exe.bs.a[0+:2], 30'h0};
				'd31 : clk_exe.bs.c <= {clk_exe.bs.a[0+:1], 31'h0};
				default : clk_exe.bs.c <= clk_exe.bs.a;
			endcase
		end

		// Shift right arithmetic / logical
		else
		begin
			case (clk_exe.bs.b)
				'd1  : clk_exe.bs.c <= {{1{clk_exe.bs.msb}}, clk_exe.bs.a[31-:31]};
				'd2  : clk_exe.bs.c <= {{2{clk_exe.bs.msb}}, clk_exe.bs.a[31-:30]};
				'd3  : clk_exe.bs.c <= {{3{clk_exe.bs.msb}}, clk_exe.bs.a[31-:29]};
				'd4  : clk_exe.bs.c <= {{4{clk_exe.bs.msb}}, clk_exe.bs.a[31-:28]};
				'd5  : clk_exe.bs.c <= {{5{clk_exe.bs.msb}}, clk_exe.bs.a[31-:27]};
				'd6  : clk_exe.bs.c <= {{6{clk_exe.bs.msb}}, clk_exe.bs.a[31-:26]};
				'd7  : clk_exe.bs.c <= {{7{clk_exe.bs.msb}}, clk_exe.bs.a[31-:25]};
				'd8  : clk_exe.bs.c <= {{8{clk_exe.bs.msb}}, clk_exe.bs.a[31-:24]};
				'd9  : clk_exe.bs.c <= {{9{clk_exe.bs.msb}}, clk_exe.bs.a[31-:23]};
				'd10 : clk_exe.bs.c <= {{10{clk_exe.bs.msb}}, clk_exe.bs.a[31-:22]};
				'd11 : clk_exe.bs.c <= {{11{clk_exe.bs.msb}}, clk_exe.bs.a[31-:21]};
				'd12 : clk_exe.bs.c <= {{12{clk_exe.bs.msb}}, clk_exe.bs.a[31-:20]};
				'd13 : clk_exe.bs.c <= {{13{clk_exe.bs.msb}}, clk_exe.bs.a[31-:19]};
				'd14 : clk_exe.bs.c <= {{14{clk_exe.bs.msb}}, clk_exe.bs.a[31-:18]};
				'd15 : clk_exe.bs.c <= {{15{clk_exe.bs.msb}}, clk_exe.bs.a[31-:17]};
				'd16 : clk_exe.bs.c <= {{16{clk_exe.bs.msb}}, clk_exe.bs.a[31-:16]};
				'd17 : clk_exe.bs.c <= {{17{clk_exe.bs.msb}}, clk_exe.bs.a[31-:15]};
				'd18 : clk_exe.bs.c <= {{18{clk_exe.bs.msb}}, clk_exe.bs.a[31-:14]};
				'd19 : clk_exe.bs.c <= {{19{clk_exe.bs.msb}}, clk_exe.bs.a[31-:13]};
				'd20 : clk_exe.bs.c <= {{20{clk_exe.bs.msb}}, clk_exe.bs.a[31-:12]};
				'd21 : clk_exe.bs.c <= {{21{clk_exe.bs.msb}}, clk_exe.bs.a[31-:11]};
				'd22 : clk_exe.bs.c <= {{22{clk_exe.bs.msb}}, clk_exe.bs.a[31-:10]};
				'd23 : clk_exe.bs.c <= {{23{clk_exe.bs.msb}}, clk_exe.bs.a[31-:9]};
				'd24 : clk_exe.bs.c <= {{24{clk_exe.bs.msb}}, clk_exe.bs.a[31-:8]};
				'd25 : clk_exe.bs.c <= {{25{clk_exe.bs.msb}}, clk_exe.bs.a[31-:7]};
				'd26 : clk_exe.bs.c <= {{26{clk_exe.bs.msb}}, clk_exe.bs.a[31-:6]};
				'd27 : clk_exe.bs.c <= {{27{clk_exe.bs.msb}}, clk_exe.bs.a[31-:5]};
				'd28 : clk_exe.bs.c <= {{28{clk_exe.bs.msb}}, clk_exe.bs.a[31-:4]};
				'd29 : clk_exe.bs.c <= {{29{clk_exe.bs.msb}}, clk_exe.bs.a[31-:3]};
				'd30 : clk_exe.bs.c <= {{30{clk_exe.bs.msb}}, clk_exe.bs.a[31-:2]};
				'd31 : clk_exe.bs.c <= {{31{clk_exe.bs.msb}}, clk_exe.bs.a[31-:1]};
				default : clk_exe.bs.c <= clk_exe.bs.a;
			endcase
		end
	end


/*
	Flags
*/

// Branch
	always_ff @ (posedge CLK_IN)
	begin
		// Default
		clk_exe.flag.br <= 0;

		// Equal
		if (clk_exe.is == is_beq)
		begin
			if (clk_exe.rs1 == clk_exe.rs2)
				clk_exe.flag.br <= 1;
		end

		// Not equal
		else if (clk_exe.is == is_bne)
		begin
			if (clk_exe.rs1 != clk_exe.rs2)
				clk_exe.flag.br <= 1;
		end

		// Less than
		else if (clk_exe.is == is_blt)
		begin
			if (clk_exe.rs1 < clk_exe.rs2)
				clk_exe.flag.br <= 1;
		end

		// Less than unsigned
		else if (clk_exe.is == is_bltu)
		begin
			if ($unsigned(clk_exe.rs1) < $unsigned(clk_exe.rs2))
				clk_exe.flag.br <= 1;
		end

		// Greater than
		else if (clk_exe.is == is_bge)
		begin
			if (clk_exe.rs1 >= clk_exe.rs2)
				clk_exe.flag.br <= 1;
		end

		// Greater than unsigned
		else if (clk_exe.is == is_bgeu)
		begin
			if ($unsigned(clk_exe.rs1) >= $unsigned(clk_exe.rs2))
				clk_exe.flag.br <= 1;
		end

	end

// Error
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_exe.flag.err <= 0;

		else
		begin
			if (clk_exe.run)
			begin
				if (clk_exe.is == is_err)
					clk_exe.flag.err <= 1;
			end
		end
	end

/*
	Write
*/

// Run
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_wr.run <= 0;

		else
			clk_wr.run <= clk_exe.run;
	end

// Thread
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_wr.thread <= 0;

		else
			clk_wr.thread <= clk_exe.thread;
	end

// Copy from execute stage
	always_ff @ (posedge CLK_IN)
	begin
		clk_wr.is 		<= clk_exe.is;
		clk_wr.imm 		<= clk_exe.imm;
		clk_wr.rd_index 	<= clk_exe.rd_index;
		clk_wr.rs1_index	<= clk_exe.rs1_index;
		clk_wr.rs2_index 	<= clk_exe.rs2_index;
	end

// Program counter
	assign clk_wr.pc = clk_pc.r[clk_wr.thread];

// Source registers
	assign clk_wr.rs1 = clk_reg.rs1[clk_wr.thread];
	assign clk_wr.rs2 = clk_reg.rs2[clk_wr.thread];

// RAM read address lower bits
// These bits are used to determine the data strobes
// when writing the ram data into the registers
	always_ff @ (posedge CLK_IN)
	begin
		clk_wr.ram_rd_adr_lsb <= clk_ram.rd_adr[1:0];
	end


/*
	RAM
*/

// Read Address
	assign clk_ram.rd_adr = clk_exe.rs1[0+:P_MEM_ADR_BITS] + clk_exe.imm[0+:P_MEM_ADR_BITS];

// Write Address
	assign clk_ram.wr_adr = clk_wr.rs1[0+:P_MEM_ADR_BITS] + clk_wr.imm[0+:P_MEM_ADR_BITS];

// Write
	always_comb
	begin
		// Store instruction
		if ((clk_wr.is == is_sw) || (clk_wr.is == is_sh) || (clk_wr.is == is_sb))
			clk_ram.wr = 1;

		// Idle
		else
			clk_ram.wr = 0;
	end

// Read
	always_comb
	begin
		// Load instruction
		if ((clk_exe.is == is_lw) || (clk_exe.is == is_lh) || (clk_exe.is == is_lhu) || (clk_exe.is == is_lb) || (clk_exe.is == is_lbu))
			clk_ram.rd = 1;

		// Idle
		else
			clk_ram.rd = 0;
	end

// Data out
	always_comb
	begin
		// Byte
		if (clk_wr.is == is_sb)
			clk_ram.dout = {4{clk_wr.rs2[7:0]}};

		// Half word
		else if (clk_wr.is == is_sh)
			clk_ram.dout = {2{clk_wr.rs2[15:0]}};

		// Word
		else
			clk_ram.dout = clk_wr.rs2;
	end

// Strobe
	always_comb
	begin
		// Byte
		if (clk_wr.is == is_sb)
		begin
			case (clk_ram.wr_adr[1:0])
				'b01 	: clk_ram.strb = 'b0010;
				'b10 	: clk_ram.strb = 'b0100;
				'b11 	: clk_ram.strb = 'b1000;
				default : clk_ram.strb = 'b0001;
			endcase
		end

		// Half word
		else if (clk_wr.is == is_sh)
		begin
			// Upper half
			if (clk_ram.wr_adr[1])
				clk_ram.strb = 'b1100;

			// Lower half
			else
				clk_ram.strb = 'b0011;
		end

		// Word
		else
			clk_ram.strb = '1;
	end

// Outputs

	// ROM
	assign ROM_IF.adr 		= clk_fetch.pc;

	// RAM
	assign RAM_IF.wr_adr 	= clk_ram.wr_adr;
	assign RAM_IF.rd_adr 	= clk_ram.rd_adr;
	assign RAM_IF.wr 		= clk_ram.wr;
	assign RAM_IF.rd 		= clk_ram.rd;
	assign RAM_IF.dout 		= clk_ram.dout;
	assign RAM_IF.strb 		= clk_ram.strb;

	// Status
	assign STA_ERR_OUT  = clk_exe.flag.err;

/*
	Assertions
*/
// synthesis translate_off

// RAM write data and address
initial
begin
	string          inst;

	// Get instance name
	inst = $sformatf ("%m");
	inst = inst.substr(7, 8);

	forever
	begin
		@(posedge CLK_IN);
		if (clk_ram.wr)
		begin
		    if ($isunknown (clk_ram.wr_adr))
				$display ("[@%0t] | Hart %s : RAM write addres is unknown!\n", $time, inst);

		    if ($isunknown (clk_ram.dout))
				$display ("[@%0t] | Hart %s : RAM @ address (%x) write data is unknown!\n", $time, inst, clk_ram.wr_adr);
		end
	end
end

// RAM read address
initial
begin
	string          inst;

	// Get instance name
	inst = $sformatf ("%m");
	inst = inst.substr(7, 8);

	forever
	begin
		@(posedge CLK_IN);
		if (clk_ram.rd)
		begin
			if ($isunknown (clk_ram.rd_adr))
				$display ("[@%0t] | Hart %s : RAM read addres is unknown!\n", $time, inst);
		end
	end
end

// Error flag
initial 
begin
	string          inst;

	// Get instance name
	inst = $sformatf ("%m");
	inst = inst.substr(7, 8);

	forever
	begin
		@(posedge CLK_IN);
		if (clk_exe.flag.err)
		begin
			$display ("[@%0t] | Hart %s : Illegal instruction!\n", $time, inst);
			$stop;
		end
	end
end

// synthesis translate_on

endmodule

// Registers
module prt_dp_pm_hart_reg
#(
	parameter P_REGS = 16,				// Number of registers
	parameter P_INDEX = 4
)
(
	// Clock
	input wire 					CLK_IN,			// Clock

	// Destination register
	input wire [P_INDEX-1:0]			RD_INDEX_IN,	// Index
	input wire [31:0]				RD_DAT_IN,	// Data
	input wire 					RD_WR_IN,		// Write

	// Source register 1
	input wire [P_INDEX-1:0]			RS1_INDEX_IN,
	output wire [31:0]				RS1_DAT_OUT,

	// Source register 2
	input wire [P_INDEX-1:0]			RS2_INDEX_IN,
	output wire [31:0]				RS2_DAT_OUT
);

// Signals
//(* ramstyle = "no_rw_check" *) logic [31:0]	clk_reg[0:P_REGS-1];
// The ram style is needed for Lattice.
// If not set Lattice Radiant 2022.1 will map the registers into block rams (EBR)
// and this results in unknown read outputs.
(* syn_ramstyle = "distributed" *) logic [31:0]	clk_reg[0:P_REGS-1];
logic [31:0]	clk_rs1_dat;
logic [31:0]	clk_rs2_dat;

// Write
// The destination register is always updated.
// In case of idle the first register is written.
// This register is hardwired to zero when read.
	always_ff @ (posedge CLK_IN)
	begin
		// Write
		if (RD_WR_IN)
			clk_reg[RD_INDEX_IN] <= RD_DAT_IN;
	end

// RS1
	always_comb
	begin
		// First register is hardwired to zero
		if (RS1_INDEX_IN == 0)
			clk_rs1_dat = 0;
		else
			clk_rs1_dat = clk_reg[RS1_INDEX_IN];
	end

// RS2
	always_comb
	begin
		// First register is hardwired to zero
		if (RS2_INDEX_IN == 0)
			clk_rs2_dat = 0;
		else
			clk_rs2_dat = clk_reg[RS2_INDEX_IN];
	end

// Outputs
	assign RS1_DAT_OUT = clk_rs1_dat;
	assign RS2_DAT_OUT = clk_rs2_dat;

endmodule

`default_nettype wire
