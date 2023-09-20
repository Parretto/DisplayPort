/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: RISC-V CPU
    (c) 2022 - 2023 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
	v1.1 - Added vendor parameter
	v1.2 - Fixed issue with SRAI instruction / Added SNEZ instruction

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

/*
	This is an implementation of the RISC-V RV32I 
	The processor has four pipeline stages. 
	FETCH - (PREDECODE) - DECODE - EXECUTE - WRITE
	The output of each pipeline stage is registered. 
	The pre-decoder is the combinatorial stage of the decoder stage. 
*/

`default_nettype none

// Module
module prt_riscv_cpu
# (
    parameter                   P_VENDOR    = "none"   // Vendor "xilinx", "lattice" or "intel"
)
(
	// Clocks and reset
  	input wire					RST_IN,			// Reset
	input wire					CLK_IN,			// Clock

	// ROM interface
	prt_riscv_rom_if.mst		ROM_IF,

	// RAM interface
	prt_riscv_ram_if.mst		RAM_IF,

	// Interrupt
	input wire 					IRQ_IN,			

	// Status
	output wire 				STA_ERR_OUT		// Error
);

// Parameters
localparam P_REGS			= 32;				// Number of registers
localparam P_REG_IDX_BITS 	= $clog2(P_REGS);	// Register idx bits
localparam P_MEM_ADR_BITS	= 32;				// RAM address width
localparam P_PC_BITS 		= 16;				// Program counter width

// CSR registers
localparam P_CSR_MTVEC 		= 'h305;
localparam P_CSR_MSTATUS 	= 'h300;
localparam P_CSR_MIE 		= 'h304;

// Enum
typedef enum {
	is_err,
	is_lui, is_auipc, is_jal, is_jalr,
	is_beq, is_bne, is_blt, is_bltu, is_bge, is_bgeu,
	is_lb, is_lh, is_lw, is_lbu, is_lhu,
	is_sb, is_sh, is_sw,
	is_addi, is_slti, is_sltiu, is_xori, is_ori, is_andi, is_slli, is_srli, is_srai,
	is_add, is_sub, is_sll, is_slt, is_sltu, is_xor, is_srl, is_sra, is_or, is_and,
	is_csrw, is_mret
} is_type;

typedef enum {
	irq_sm_idle, irq_sm_1, irq_sm_2, irq_sm_3, irq_sm_4, irq_sm_5, irq_sm_6, irq_sm_7, irq_sm_8, irq_sm_9
} irq_sm_type;

// ALU input select
typedef enum {
	alu_sel_rs1, alu_sel_pc,															// A-input
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
	logic signed	[P_PC_BITS-1:0]			r;		// Register
	logic signed	[P_PC_BITS-1:0]			nxt;		// Next
} pc_struct;

typedef struct {
	logic			[P_REG_IDX_BITS-1:0]	rd_idx;		// Destination register index
	logic			[31:0]					rd_dat;		// Destination register data
	logic									rd_wr;		// Destination register write
	logic			[P_REG_IDX_BITS-1:0]	rs1_idx;		// Source register 1 index
	logic			[P_REG_IDX_BITS-1:0]	rs2_idx;		// Source register 2 index
	logic signed	[31:0]					rs1;			// Source register 1
	logic signed	[31:0]					rs2;			// Source register 2
} reg_struct;

typedef struct {
	alu_sel									a_sel;			// Input A select
	alu_sel									b_sel;			// Input B select
	alu_op									op;				// Operation
} alu_dec_struct;

typedef struct {
	logic signed	[31:0]					a;				// Input A
	logic signed	[31:0]					b;				// Input B
	logic signed	[31:0]					c;				// Output C
} alu_exe_struct;

typedef struct {
	bs_sel									b_sel;			// Input B select
	bs_op									op;				// Operation
} bs_dec_struct;

typedef struct {
	logic									msb;
	logic 			[31:0]					a;				// Input A
	logic 			[4:0]					b;				// Input B
	logic 			[31:0]					c;				// Output A
} bs_exe_struct;

typedef struct {
	logic									run;			// Run
	logic			[P_PC_BITS-1:0]			pc;				// Program counter
	logic									rd;
	logic			[31:0]					dat;
	logic									vld;
} fetch_struct;

typedef struct {
	logic			[31:0]					dat;
	logic									vld;
	is_type									is;				// Instruction
	logic			[P_REG_IDX_BITS-1:0]	rd_idx;			// Destination index
	logic			[P_REG_IDX_BITS-1:0]	rs1_idx;		// Source register 1 index
	logic			[P_REG_IDX_BITS-1:0]	rs2_idx;		// Source register 2 index
	logic signed	[19:0]					imm;			// Immediate data (20 bits)
	alu_dec_struct							alu;			// ALU
	bs_dec_struct							bs;				// Barrel shifter
} pre_struct;

typedef struct {
	logic									vld;			// Valid
	logic									stall;			// Stall
	logic									dh_stall;		// Stall data hazard
	logic									ram_stall;		// Stall ram
	logic									ram_stall_comb;	// Stall ram combinatorial
	logic									ram_stall_reg;	// Stall ram register
	logic									flush_comb;		// Flush combinatioral
	logic			[2:0]					flush_reg;		// Flush register
	logic									flush;			// Flush
	is_type									is;				// Instruction
	logic			[P_PC_BITS-1:0]			pc_pipe[0:3];	// Program counter pipe
	logic			[P_PC_BITS-1:0]			pc;				// Program counter
	logic			[P_REG_IDX_BITS-1:0]	rd_idx;			// Destination index
	logic			[P_REG_IDX_BITS-1:0]	rs1_idx;		// Source register 1 index
	logic			[P_REG_IDX_BITS-1:0]	rs2_idx;		// Source register 2 index
	logic signed	[19:0]					imm;			// Immediate data (20 bits)
	alu_dec_struct							alu;			// ALU
	bs_dec_struct							bs;				// Bit shifter
	logic									jmp;			// Jump
	logic									err;			// Error
	logic signed	[P_MEM_ADR_BITS-1:0]	ram_adr;
} dec_struct;

typedef struct {
	logic									vld;
	is_type									is;				// Instruction
	logic			[P_PC_BITS-1:0]			pc;				// Program counter
	logic			[P_REG_IDX_BITS-1:0]	rd_idx;			// Destination index
	logic signed	[19:0]					imm;			// Immediate data (20 bits)
	alu_exe_struct							alu;			// ALU
	bs_exe_struct							bs;				// Bit shifter
	logic			[1:0]					ram_adr;		// RAM address LSB
} exe_struct;

typedef struct {
	logic signed	[P_MEM_ADR_BITS-1:0]	adr;
	logic 									rd;
	logic 									wr;
	logic 			[31:0]					dout;
	logic			[3:0]					strb;
	logic 			[31:0]					din;
	logic									vld;
} ram_struct;

typedef struct {
	irq_sm_type								sm_cur, sm_nxt;
	logic									irq_in;
	logic 			[P_PC_BITS-1:0]			mtvec;
	logic									mstatus_mie;
	logic									mie_meie;
	logic									mepc_ld;
	logic 			[P_PC_BITS-1:0]			mepc;
	logic									msk_clr;
	logic									msk_set;
	logic									msk;
	logic									req;
	logic									req_re;
	logic									pc_ld_mtvec;
	logic									pc_ld_mepc;
	logic									flush_clr;
	logic									flush_set;
	logic									flush;
	logic									flush_comb;
	logic									flush_reg;
} irq_struct;

// Signals
pc_struct		clk_pc;		// Program counter
fetch_struct	clk_fetch;	// Fetch
pre_struct		clk_pre;	// Pre-Decoder
dec_struct		clk_dec;	// Decoder
exe_struct		clk_exe;	// Execute
reg_struct		clk_reg;	// Registers
ram_struct		clk_ram;	// RAM memory
irq_struct		clk_irq;	// Interrupt

// Logic

/*
	Program counter
*/

// Program counter
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_pc.r <= 0;

		else
		begin
			if (clk_fetch.run)
			begin
				// Jump 
				if (clk_dec.jmp)
					clk_pc.r <= clk_pc.nxt;
				
				// Interrupt vector
				else if (clk_irq.pc_ld_mtvec)
					clk_pc.r <= clk_irq.mtvec;

				// Saved program counter
				else if (clk_irq.pc_ld_mepc)
					clk_pc.r <= clk_irq.mepc;

				// Increment
				else if (!clk_dec.stall)
					clk_pc.r <= clk_pc.r + 'd4;
			end
		end
	end

// Program counter next
	always_comb
	begin
		if (clk_dec.is == is_jalr)
			clk_pc.nxt = clk_reg.rs1 + clk_dec.imm[0+:P_PC_BITS];
		else
			clk_pc.nxt = clk_dec.pc + clk_dec.imm[0+:P_PC_BITS];
	end


/*
	Fetch stage
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

// Program counter
	assign clk_fetch.pc = clk_pc.r;

// Read
	always_comb
	begin
		if (clk_fetch.run)
			clk_fetch.rd = 1;
		else
			clk_fetch.rd = 0;
	end

// Data
	always_ff @ (posedge CLK_IN)
	begin
		if (!clk_dec.stall)
		begin
			if (ROM_IF.vld)
				clk_fetch.dat <= ROM_IF.dat;
		end
	end

// Valid
	always_ff @ (posedge CLK_IN)
	begin
		clk_fetch.vld <= 0;

		if (ROM_IF.vld)
			clk_fetch.vld <= 1;
	end


/*
	Pre-Decode stage
*/

// Input data
// Must be combinatorial	
	always_comb
	begin
		if (clk_dec.flush || clk_irq.flush)
			clk_pre.dat = 'h00000013;	// Insert NOP
		else
			clk_pre.dat = clk_fetch.dat;
	end

// Valid
	always_comb
	begin
		if (clk_fetch.vld)
			clk_pre.vld = 1;
		else
			clk_pre.vld = 0;
	end

// Decoder
	always_comb
	begin
		// Defaults
		clk_pre.is 			= is_err;
		clk_pre.imm			= 0;
		clk_pre.rd_idx 		= 0;
		clk_pre.rs1_idx 	= 0;
		clk_pre.rs2_idx 	= 0;
		clk_pre.alu.a_sel 	= alu_sel_rs1;
		clk_pre.alu.b_sel 	= alu_sel_rs2;
		clk_pre.alu.op 		= alu_op_add;
		clk_pre.bs.b_sel	= bs_sel_rs2;
		clk_pre.bs.op 		= bs_op_sll;

		if (clk_pre.vld)
		begin		
			case (clk_pre.dat[6:2])

				// Load
				'b00000 :
				begin
					clk_pre.rd_idx 	= clk_pre.dat[7+:P_REG_IDX_BITS];
					clk_pre.rs1_idx = clk_pre.dat[15+:P_REG_IDX_BITS];
					clk_pre.imm 	= $signed(clk_pre.dat[31:20]);

					case (clk_pre.dat[14:12])

						// Load byte
						'b000 :
						begin
							clk_pre.is	= is_lb;
						end

						// Load half word
						'b001 :
						begin
							clk_pre.is	= is_lh;
						end

						// Load word
						'b010 :
						begin
							clk_pre.is	= is_lw;
						end

						// Load byte unsigned
						'b100 :
						begin
							clk_pre.is	= is_lbu;
						end

						// Load half word unsigned
						'b101 :
						begin
							clk_pre.is	= is_lhu;
						end

						default : ;
					endcase
				end

				// OP-IMM
				'b00100 :
				begin
					clk_pre.rd_idx 		= clk_pre.dat[7+:P_REG_IDX_BITS];
					clk_pre.rs1_idx 	= clk_pre.dat[15+:P_REG_IDX_BITS];
					clk_pre.imm[11:0] 	= clk_pre.dat[31:20];
					clk_pre.alu.a_sel 	= alu_sel_rs1;
					clk_pre.alu.b_sel 	= alu_sel_i_type_signed;
					clk_pre.bs.b_sel 	= bs_sel_i_type;

					case (clk_pre.dat[14:12])

						// ADDI
						'b000 :
						begin
							clk_pre.is 			= is_addi;
							clk_pre.alu.op  	= alu_op_add;
						end

						// SLTI
						'b010 :
						begin
							clk_pre.is 			= is_slti;
							clk_pre.alu.op  	= alu_op_set;
						end

						// SLTIU
						'b011 :
						begin
							clk_pre.is 			= is_sltiu;
							clk_pre.alu.b_sel 	= alu_sel_i_type_unsigned;
							clk_pre.alu.op  	= alu_op_set;
						end

						// XORI
						'b100 :
						begin
							clk_pre.is 			= is_xori;
							clk_pre.alu.op  	= alu_op_xor;
						end

						// ORI
						'b110 :
						begin
							clk_pre.is			= is_ori;
							clk_pre.alu.op  	= alu_op_or;
						end

						// ANDI
						'b111 :
						begin
							clk_pre.is 			= is_andi;
							clk_pre.alu.op  	= alu_op_and;
						end

						// SLLI
						'b001 :
						begin
							clk_pre.is 			= is_slli;
							clk_pre.imm[4:0]	= clk_pre.dat[20+:5];
							clk_pre.bs.op  		= bs_op_sll;
						end

						// SRLI / SRAI
						'b101 :
						begin
							// Arithmetic
							if (clk_pre.dat[30])
							begin
								clk_pre.is 			= is_srai;
								clk_pre.imm[4:0] 	= clk_pre.dat[20+:5];
								clk_pre.bs.op  		= bs_op_sra;
							end

							// Logical
							else
							begin
								clk_pre.is 			= is_srli;
								clk_pre.imm[4:0] 	= clk_pre.dat[20+:5];
								clk_pre.bs.op  		= bs_op_srl;
							end
						end

						default : ;
					endcase
				end

				// OP
				'b01100 :
				begin
					clk_pre.rd_idx 		= clk_pre.dat[7+:P_REG_IDX_BITS];
					clk_pre.rs1_idx 	= clk_pre.dat[15+:P_REG_IDX_BITS];
					clk_pre.rs2_idx 	= clk_pre.dat[20+:P_REG_IDX_BITS];
					clk_pre.alu.a_sel 	= alu_sel_rs1;
					clk_pre.alu.b_sel 	= alu_sel_rs2;
					clk_pre.bs.b_sel 	= bs_sel_rs2;

					case (clk_pre.dat[14:12])

						// Add / sub
						'b000 :
						begin
							// Sub
							if (clk_pre.dat[30])
							begin
								clk_pre.is 		= is_sub;
								clk_pre.alu.op 	= alu_op_sub;
							end

							// Add
							else
							begin
								clk_pre.is 		= is_add;
								clk_pre.alu.op 	= alu_op_add;
							end
						end

						// SLL
						'b001 :
						begin
							clk_pre.is 			= is_sll;
							clk_pre.bs.op  		= bs_op_sll;
						end

						// SLT
						'b010 :
						begin
							clk_pre.is 			= is_slt;
							clk_pre.alu.op 		= alu_op_set;
						end

						// SLTU
						'b011 :
						begin
							clk_pre.is			= is_sltu;
							clk_pre.alu.op  	= alu_op_set;
						end

						// XOR
						'b100 :
						begin
							clk_pre.is 			= is_xori;
							clk_pre.alu.op 		= alu_op_xor;
						end

						// SRL/A
						'b101 :
						begin
							// Arithmetic
							if (clk_pre.dat[30])
							begin
								clk_pre.is 		= is_sra;
								clk_pre.bs.op 	= bs_op_sra;
							end

							// Logical
							else
							begin
								clk_pre.is 		= is_srl;
								clk_pre.bs.op 	= bs_op_srl;
							end
						end

						// OR
						'b110 :
						begin
							clk_pre.is 			= is_ori;
							clk_pre.alu.op  	= alu_op_or;
						end

						// ANDI
						'b111 :
						begin
							clk_pre.is 			= is_andi;
							clk_pre.alu.op  	= alu_op_and;
						end

						default : ;
					endcase
				end

				// Store
				'b01000 :
				begin
					clk_pre.rs1_idx 	= clk_pre.dat[15+:P_REG_IDX_BITS];
					clk_pre.rs2_idx 	= clk_pre.dat[20+:P_REG_IDX_BITS];
					clk_pre.imm 		= $signed({clk_pre.dat[31:25], clk_pre.dat[11:7]});

					case (clk_pre.dat[14:12])

						// Store byte
						'b000 :
						begin
							clk_pre.is 	= is_sb;
						end

						// Store half word
						'b001 :
						begin
							clk_pre.is	= is_sh;
						end

						// Store word
						'b010 :
						begin
							clk_pre.is	= is_sw;
						end

						default : ;
					endcase
				end

				// Branch
				'b11000 :
				begin
					clk_pre.rs1_idx 	= clk_pre.dat[15+:P_REG_IDX_BITS];
					clk_pre.rs2_idx 	= clk_pre.dat[20+:P_REG_IDX_BITS];				
					clk_pre.imm 		= $signed({clk_pre.dat[31], clk_pre.dat[7], clk_pre.dat[30:25], clk_pre.dat[11:8], 1'b0});

					case (clk_pre.dat[14:12])

						// BEQ
						'b000 :
						begin
							clk_pre.is = is_beq;
						end

						// BNE
						'b001 :
						begin
							clk_pre.is = is_bne;
						end

						// BLT
						'b100 :
						begin
							clk_pre.is = is_blt;
						end

						// BGE
						'b101 :
						begin
							clk_pre.is = is_bge;
						end

						// BLTU
						'b110 :
						begin
							clk_pre.is = is_bltu;
						end

						// BGEU
						'b111 :
						begin
							clk_pre.is = is_bgeu;
						end

						default : ;
					endcase
				end

				// JAL
				'b11011 :
				begin
					clk_pre.rd_idx 		= clk_pre.dat[7+:P_REG_IDX_BITS];
					clk_pre.is 			= is_jal;
					clk_pre.imm			= $signed({clk_pre.dat[31], clk_pre.dat[19:12], clk_pre.dat[20], clk_pre.dat[30:21], 1'b0});
					clk_pre.alu.a_sel	= alu_sel_pc;
					clk_pre.alu.b_sel	= alu_sel_const_4;
					clk_pre.alu.op 		= alu_op_add;
				end

				// JALR
				'b11001 :
				begin
					clk_pre.rd_idx 		= clk_pre.dat[7+:P_REG_IDX_BITS];
					clk_pre.rs1_idx 	= clk_pre.dat[15+:P_REG_IDX_BITS];
					clk_pre.is			= is_jalr;
					clk_pre.imm			= $signed(clk_pre.dat[31:20]);
					clk_pre.alu.a_sel	= alu_sel_pc;
					clk_pre.alu.b_sel	= alu_sel_const_4;
					clk_pre.alu.op 		= alu_op_add;
				end

				// LUI
				'b01101 :
				begin
					clk_pre.rd_idx 		= clk_pre.dat[7+:P_REG_IDX_BITS];
					clk_pre.is 			= is_lui;
					clk_pre.imm			= clk_pre.dat[31:12];
					clk_pre.alu.a_sel	= alu_sel_rs1;			// RS1 = zero
					clk_pre.alu.b_sel	= alu_sel_u_type;
					clk_pre.alu.op 		= alu_op_add;
				end

				// AUIPC
				'b00101 :
				begin
					clk_pre.rd_idx 		= clk_pre.dat[7+:P_REG_IDX_BITS];
					clk_pre.is			= is_auipc;
					clk_pre.imm			= clk_pre.dat[31:12];
					clk_pre.alu.a_sel	= alu_sel_pc;
					clk_pre.alu.b_sel	= alu_sel_u_type;
					clk_pre.alu.op 		= alu_op_add;
				end

				// System
				'b11100 :
				begin
					case (clk_pre.dat[14:12])
						
						// Priveledged instruction
						'b000 : 
						begin
							if (clk_pre.dat[31:20] == 'b001100000010)
								clk_pre.is = is_mret;
						end

						// CSRW
						'b001 : 
						begin
							clk_pre.rd_idx 	= clk_pre.dat[7+:P_REG_IDX_BITS];
							clk_pre.imm		= clk_pre.dat[31:20];
							clk_pre.is		= is_csrw;
							clk_pre.rs1_idx = clk_pre.dat[15+:P_REG_IDX_BITS];
						end

						default :  ;
					endcase
				end

				default : ;
			endcase
		end
	end

/*
	Decoder stage
*/

// Valid
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_dec.vld <= 0;

		else
		begin
			if (!clk_dec.stall)
				clk_dec.vld <= clk_fetch.vld;
			else
				clk_dec.vld <= 0;
		end
	end

// Copy from previous stage
	always_ff @ (posedge CLK_IN)
	begin
		if (clk_fetch.vld)
		begin
			clk_dec.is 		<= clk_pre.is;
			clk_dec.imm 	<= clk_pre.imm;
			clk_dec.rd_idx 	<= clk_pre.rd_idx;
			clk_dec.rs1_idx <= clk_pre.rs1_idx;
			clk_dec.rs2_idx <= clk_pre.rs2_idx;
			clk_dec.alu		<= clk_pre.alu;
			clk_dec.bs		<= clk_pre.bs;
		end
	end

// Program counter
// The program counter is delayed for a number of cycles.
	always_ff @ (posedge CLK_IN)
	begin
		for (int i = 0; i < $size(clk_dec.pc_pipe); i++)
		begin	
			if (clk_fetch.run)
			begin
				if (clk_dec.vld)
				begin
					if (i == 0)
						clk_dec.pc_pipe[i] <= clk_pc.r;
					else	
						clk_dec.pc_pipe[i] <= clk_dec.pc_pipe[i-1];
				end
			end

			else	
				clk_dec.pc_pipe[i] <= 0;
		end
	end

	assign clk_dec.pc = clk_dec.pc_pipe[$high(clk_dec.pc_pipe)];

// Data hazard stall
// When one of the source registers of the current instruction is pointing to 
// the destination register of the previous instruction, 
// then the pipeling needs to be stalled untill the destination register has been written. 
	always_comb
	begin
		clk_dec.dh_stall = 0;

		if (clk_dec.vld)
		begin	
			if (clk_dec.rd_idx != 0)
			begin
				if ((clk_pre.rs1_idx == clk_dec.rd_idx) || (clk_pre.rs2_idx == clk_dec.rd_idx))
					clk_dec.dh_stall = 1;
			end
		end
	end

// RAM stall combinatorial
// On a load instruction the pipeline needs to wait for the read data to be read from the RAM
	always_comb
	begin
		clk_dec.ram_stall_comb = 0;

		if (clk_dec.vld)
		begin
			if ((clk_dec.is == is_lb) || (clk_dec.is == is_lh) || (clk_dec.is == is_lw) || (clk_dec.is == is_lbu) || (clk_dec.is == is_lhu))
				clk_dec.ram_stall_comb = 1;
		end
	end

// RAM stall register
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_dec.ram_stall_reg <= 0;

		else
		begin
			// Clear
			if (RAM_IF.rd_vld)
				clk_dec.ram_stall_reg <= 0;

			// Set
			else if (clk_dec.ram_stall_comb)
				clk_dec.ram_stall_reg <= 1;
		end
	end

// RAM stall combined
	assign clk_dec.ram_stall = clk_dec.ram_stall_comb || clk_dec.ram_stall_reg;

// Main stall signal
	assign clk_dec.stall = clk_dec.dh_stall || clk_dec.ram_stall; 

// Jump
// This flag is asserted when the jump is taken.
// Must be combinatorial
	always_comb
	begin
		// Default
		clk_dec.jmp = 0;

		// Valid
		if (clk_dec.vld)
		begin
			// JAL
			if (clk_dec.is == is_jal)
				clk_dec.jmp = 1;

			// JALR
			else if (clk_dec.is == is_jalr)
				clk_dec.jmp = 1;
			
			// Equal
			else if (clk_dec.is == is_beq)
			begin
				if (clk_reg.rs1 == clk_reg.rs2)
					clk_dec.jmp = 1;
			end

			// Not equal
			else if (clk_dec.is == is_bne)
			begin
				if (clk_reg.rs1 != clk_reg.rs2)
					clk_dec.jmp = 1;
			end

			// Less than
			else if (clk_dec.is == is_blt)
			begin
				if (clk_reg.rs1 < clk_reg.rs2)
					clk_dec.jmp = 1;
			end

			// Less than unsigned
			else if (clk_dec.is == is_bltu)
			begin
				if ($unsigned(clk_reg.rs1) < $unsigned(clk_reg.rs2))
					clk_dec.jmp = 1;
			end

			// Greater than
			else if (clk_dec.is == is_bge)
			begin
				if (clk_reg.rs1 >= clk_reg.rs2)
					clk_dec.jmp = 1;
			end

			// Greater than unsigned
			else if (clk_dec.is == is_bgeu)
			begin
				if ($unsigned(clk_reg.rs1) >= $unsigned(clk_reg.rs2))
					clk_dec.jmp = 1;
			end
		end
	end

// Flush
	always_comb
	begin
		if (clk_fetch.vld && clk_dec.jmp)
			clk_dec.flush_comb = 1;
		else
			clk_dec.flush_comb = 0;
	end

	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		if (RST_IN)
			clk_dec.flush_reg <= 0;

		else
		begin
			clk_dec.flush_reg <= {clk_dec.flush_reg[0+:$left(clk_dec.flush_reg)], clk_dec.flush_comb};
		end
	end

	assign clk_dec.flush = clk_dec.flush_comb || clk_dec.flush_reg;

// Error
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_dec.err <= 0;

		else
		begin
			if (clk_dec.vld)
			begin
				if (clk_dec.is == is_err)
					clk_dec.err <= 1;
			end
		end
	end

// RAM addres
// Must be combinatorial
	assign clk_dec.ram_adr = clk_reg.rs1 + clk_dec.imm;

/*
	Execute stage
*/

// Valid
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_exe.vld <= 0;

		else
			clk_exe.vld <= clk_dec.vld;
	end

// Copy from decode stage
	always_ff @ (posedge CLK_IN)
	begin
		if (clk_dec.vld)
		begin
			clk_exe.is 		<= clk_dec.is;
			clk_exe.rd_idx 	<= clk_dec.rd_idx;
			clk_exe.ram_adr <= clk_dec.ram_adr[1:0];	// The two LSB are needed for the load instruction
		end
	end

// Program counter
	assign clk_exe.pc = clk_pc.r - 'h10;

// ALU
// A-input
// Must be combinatioral
	always_comb
	begin
		// Program counter
		if (clk_dec.alu.a_sel == alu_sel_pc)
			clk_exe.alu.a = clk_dec.pc;

		// Source register 1
		else
			clk_exe.alu.a = clk_reg.rs1;
	end

// B-input
// Must be combinatioral
	always_comb
	begin
		// U-type
		if (clk_dec.alu.b_sel == alu_sel_u_type)
			clk_exe.alu.b = {clk_dec.imm, 12'h0};

		// I-type Signed
		else if (clk_dec.alu.b_sel == alu_sel_i_type_signed)
			clk_exe.alu.b = $signed(clk_dec.imm[11:0]);

		// I-type Unsigned
		else if (clk_dec.alu.b_sel == alu_sel_i_type_unsigned)
			clk_exe.alu.b = {20'h0, clk_dec.imm[11:0]};

		// Constant 4
		else if (clk_dec.alu.b_sel == alu_sel_const_4)
			clk_exe.alu.b = 'd4;

		// Source register 2
		else
			clk_exe.alu.b = clk_reg.rs2;
	end

// ALU
	always_ff @ (posedge CLK_IN)
	begin
		// Valid
		if (clk_dec.vld)
		begin
			// Opp code
			case (clk_dec.alu.op)

				// Set
				alu_op_set :
				begin
					// Pseudoinstruction SEQZ rd, rs
					if ((clk_dec.is == is_sltiu) && (clk_dec.imm == 'd1))
					begin
						if (clk_exe.alu.a == 0)
							clk_exe.alu.c <= 'd1;
						else
							clk_exe.alu.c <= 0;
					end

					// Pseudoinstruction SNEZ rd, rs
					else if ((clk_dec.is == is_sltu) && (clk_dec.rs1_idx == 'd0))
					begin
						if (clk_exe.alu.b != 0)
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
	end


// Bit shifter

// A-input
	assign clk_exe.bs.a = clk_reg.rs1;

// B-input
	always_comb
	begin
		// Immediate
		if (clk_dec.bs.b_sel == bs_sel_i_type)
			clk_exe.bs.b = clk_dec.imm[0+:$size(clk_exe.bs.b)];

		// Source register 2
		else
			clk_exe.bs.b = clk_reg.rs2[0+:$size(clk_exe.bs.b)];
	end

// MSB
	always_comb
	begin
		if (clk_dec.bs.op == bs_op_sra)
			clk_exe.bs.msb = clk_exe.bs.a[31];
		else
			clk_exe.bs.msb = 0;
	end

// Shifter 
	always_ff @ (posedge CLK_IN)
	begin
		// Valid
		if (clk_dec.vld)
		begin
			// Shift left logical
			if (clk_dec.bs.op == bs_op_sll)
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
	end

/*
	Write stage
*/

/*
	Registers
*/
	prt_riscv_cpu_reg
	#(
		.P_VENDOR 			(P_VENDOR),			// Vendor
		.P_REGS				(P_REGS),			// Number of registers
		.P_IDX				(P_REG_IDX_BITS)	// Register idx width
	)
	REG_INST
	(
		// Clock
		.CLK_IN				(CLK_IN),			// Clock

		// Destination register
		.RD_IDX_IN			(clk_reg.rd_idx),
		.RD_DAT_IN			(clk_reg.rd_dat),
		.RD_WR_IN			(clk_reg.rd_wr),

		// Source register 1
		.RS1_IDX_IN			(clk_reg.rs1_idx),
		.RS1_DAT_OUT		(clk_reg.rs1),

		// Source register 2
		.RS2_IDX_IN			(clk_reg.rs2_idx),
		.RS2_DAT_OUT		(clk_reg.rs2)
	);

// Destination register index
	assign clk_reg.rd_idx = clk_exe.rd_idx;

// Source register index
	assign clk_reg.rs1_idx = clk_dec.rs1_idx;
	assign clk_reg.rs2_idx = clk_dec.rs2_idx;

// Destination Register data
// Must be combinatorial
	always_comb
	begin
		// Load word
		if (clk_exe.is == is_lw)
			clk_reg.rd_dat = clk_ram.din;

		// Load half word
		else if ((clk_exe.is == is_lh) || (clk_exe.is == is_lhu))
		begin
			// Upper word
			if (clk_exe.ram_adr[1])
			begin
				// Unsigned
				if (clk_exe.is == is_lhu)
					clk_reg.rd_dat = {16'h0, clk_ram.din[16+:16]};

				// Signed
				else
					clk_reg.rd_dat = $signed(clk_ram.din[16+:16]);
			end

			// Lower word
			else
			begin
				// Unsigned
				if (clk_exe.is == is_lhu)
					clk_reg.rd_dat = {16'h0, clk_ram.din[0+:16]};

				// Signed
				else
					clk_reg.rd_dat = $signed(clk_ram.din[0+:16]);
			end
		end

		// Load byte
		else if ((clk_exe.is == is_lb) || (clk_exe.is == is_lbu))
		begin
			case (clk_exe.ram_adr[1:0])
				'b01 :
				begin
					// Unsigned
					if (clk_exe.is == is_lbu)
						clk_reg.rd_dat = {24'h0, clk_ram.din[(1*8)+:8]};

					// Signed
					else
						clk_reg.rd_dat = $signed(clk_ram.din[(1*8)+:8]);
				end

				'b10 :
				begin
					// Unsigned
					if (clk_exe.is == is_lbu)
						clk_reg.rd_dat = {24'h0, clk_ram.din[(2*8)+:8]};

					// Signed
					else
						clk_reg.rd_dat = $signed(clk_ram.din[(2*8)+:8]);
				end

				'b11 :
				begin
					// Unsigned
					if (clk_exe.is == is_lbu)
						clk_reg.rd_dat = {24'h0, clk_ram.din[(3*8)+:8]};

					// Signed
					else
						clk_reg.rd_dat = $signed(clk_ram.din[(3*8)+:8]);
				end

				default :
				begin
					// Unsigned
					if (clk_exe.is == is_lbu)
						clk_reg.rd_dat = {24'h0, clk_ram.din[0+:8]};

					// Signed
					else
						clk_reg.rd_dat = $signed(clk_ram.din[0+:8]);
				end
			endcase
		end

		// Shift
		else if ((clk_exe.is == is_sll) || (clk_exe.is == is_srl) || (clk_exe.is == is_sra) || (clk_exe.is == is_slli) || (clk_exe.is == is_srli) || (clk_exe.is == is_srai))
			clk_reg.rd_dat = clk_exe.bs.c;

		// Default (ALU out)
		else
			clk_reg.rd_dat = clk_exe.alu.c;
	end

// Destination data write
	always_comb
	begin
		if (clk_exe.vld || clk_ram.vld)
			clk_reg.rd_wr = 1;
		else
			clk_reg.rd_wr = 0;
	end


/*
	RAM
*/

// Address
	always_ff @ (posedge CLK_IN)
	begin
		clk_ram.adr <= clk_dec.ram_adr; 
	end

// Write
	always_ff @ (posedge CLK_IN)
	begin
		// Store instruction
		if (clk_dec.vld && ((clk_dec.is == is_sw) || (clk_dec.is == is_sh) || (clk_dec.is == is_sb)))
			clk_ram.wr <= 1;

		// Idle
		else
			clk_ram.wr <= 0;
	end

// Read
	always_ff @ (posedge CLK_IN)
	begin
		// Load instruction
		if (clk_dec.vld && ((clk_dec.is == is_lw) || (clk_dec.is == is_lh) || (clk_dec.is == is_lhu) || (clk_dec.is == is_lb) || (clk_dec.is == is_lbu)))
			clk_ram.rd <= 1;

		// Idle
		else
			clk_ram.rd <= 0;
	end

// Data out
	always_ff @ (posedge CLK_IN)
	begin
		// Byte
		if (clk_dec.is == is_sb)
			clk_ram.dout <= {4{clk_reg.rs2[7:0]}};

		// Half word
		else if (clk_dec.is == is_sh)
			clk_ram.dout <= {2{clk_reg.rs2[15:0]}};

		// Word
		else
			clk_ram.dout <= clk_reg.rs2;
	end

// Strobe
	always_ff @ (posedge CLK_IN)
	begin
		// Byte
		if (clk_dec.is == is_sb)
		begin
			case (clk_dec.ram_adr[1:0])
				'b01    : clk_ram.strb <= 'b0010;
				'b10    : clk_ram.strb <= 'b0100;
				'b11    : clk_ram.strb <= 'b1000;
				default : clk_ram.strb <= 'b0001;
			endcase
		end

		// Half word
		else if (clk_dec.is == is_sh)
		begin
			// Upper half
			if (clk_dec.ram_adr[1])
				clk_ram.strb <= 'b1100;

			// Lower half
			else
				clk_ram.strb <= 'b0011;
		end

		// Word
		else
			clk_ram.strb <= '1;
	end

// Data in
	always_ff @ (posedge CLK_IN)
	begin
		if (RAM_IF.rd_vld)
			clk_ram.din <= RAM_IF.rd_dat;
	end

// Read valid
	always_ff @ (posedge CLK_IN)
	begin
		clk_ram.vld <= RAM_IF.rd_vld;
	end

/*
	Interrupt
*/

// Input
	always_ff @ (posedge CLK_IN)
	begin
		clk_irq.irq_in <= IRQ_IN;
	end

//  Interrupt vector MTVEC
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_irq.mtvec <= 0;

		else
		begin
			if (clk_dec.vld)
			begin
				if ((clk_dec.is == is_csrw) && (clk_dec.imm == P_CSR_MTVEC))
					clk_irq.mtvec <= clk_reg.rs1;
			end
		end
	end

// MSTATUS
// Only bit MIE is implemented
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_irq.mstatus_mie <= 0;

		else
		begin
			if (clk_dec.vld)
			begin
				if ((clk_dec.is == is_csrw) && (clk_dec.imm == P_CSR_MSTATUS))
					clk_irq.mstatus_mie <= clk_reg.rs1[3];
			end
		end
	end

// Machine Interrupt Enable 
// Only bit MEIE is implemented
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_irq.mie_meie <= 0;

		else
		begin
			if (clk_dec.vld)
			begin
				if ((clk_dec.is == is_csrw) && (clk_dec.imm == P_CSR_MIE))
					clk_irq.mie_meie <= clk_reg.rs1[11];
			end
		end
	end

// Interrupt mask
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		if (RST_IN)
			clk_irq.msk <= 0;

		else 
		begin
			// Clear
			if (clk_irq.msk_clr)
				clk_irq.msk <= 0;

			// Set
			else if (clk_irq.msk_set)
				clk_irq.msk <= 1;
		end
	end	

// Interrupt request
	always_ff @ (posedge CLK_IN)
	begin
		if (clk_irq.irq_in && clk_irq.mstatus_mie && clk_irq.mie_meie && !clk_irq.msk)
			clk_irq.req <= 1;
		else
			clk_irq.req <= 0;
	end	

// Interrupt request edge
	prt_riscv_lib_edge
	IRQ_REQ_EDGE_INST
	(
		.CLK_IN	(CLK_IN),			// Clock
		.CKE_IN	(1'b1),				// Clock enable
		.A_IN	(clk_irq.req),		// Input
		.RE_OUT	(clk_irq.req_re),	// Rising edge
		.FE_OUT	()					// Falling edge
	);

// Saved program counter
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_irq.mepc <= 0;

		else
		begin
			if (clk_irq.mepc_ld)
				clk_irq.mepc <= clk_pc.r - 'd12;
		end
	end

// Flush combinatorial
	always_comb
	begin
		if (clk_dec.vld && (clk_dec.is == is_mret))
			clk_irq.flush_comb = 1;
		else
			clk_irq.flush_comb = 0;
	end

// Flush register
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_irq.flush_reg <= 0;

		else
		begin
			// Clear by state machine
			if (clk_irq.flush_clr)
				clk_irq.flush_reg <= 0;

			// Set by state machine
			else if (clk_irq.flush_set)
				clk_irq.flush_reg <= 1;

			// Set at interrupt return
			else if (clk_irq.flush_comb)
				clk_irq.flush_reg <= 1;
		end
	end

// Flush combined
	assign clk_irq.flush = clk_irq.flush_comb || clk_irq.flush_reg;

// State machine
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_irq.sm_cur <= irq_sm_idle;

		else
			clk_irq.sm_cur <= clk_irq.sm_nxt;
	end

// State machine decoder
	always_comb
	begin
		// Default
		clk_irq.msk_clr = 0;
		clk_irq.msk_set = 0;
		clk_irq.flush_clr = 0;
		clk_irq.flush_set = 0;
		clk_irq.mepc_ld = 0;
		clk_irq.pc_ld_mtvec = 0;
		clk_irq.pc_ld_mepc = 0;

		case (clk_irq.sm_cur)

			irq_sm_idle : 
			begin
				if (clk_irq.req)
				begin	
					clk_irq.flush_set = 1;
					clk_irq.sm_nxt = irq_sm_1;
				end

				else
					clk_irq.sm_nxt = irq_sm_idle;
			end

			// Wait for decoder flush
			irq_sm_1 :
			begin
				// Wait for the pipeline be ready
				if (clk_dec.flush || clk_dec.stall)
					clk_irq.sm_nxt = irq_sm_1;
				else
				begin
					clk_irq.msk_set = 1;
					clk_irq.mepc_ld = 1;		// Save program counter
					clk_irq.pc_ld_mtvec = 1;	// Load program counter with interrupt vector
					clk_irq.sm_nxt = irq_sm_2;
				end
			end

			// Three clock cycles are needed to flush out the pipeline
			irq_sm_2 :
			begin
				clk_irq.sm_nxt = irq_sm_3;
			end

			irq_sm_3 :
			begin
				clk_irq.sm_nxt = irq_sm_4;
			end

			irq_sm_4 :
			begin
				clk_irq.flush_clr = 1;
				clk_irq.sm_nxt = irq_sm_5;
			end

			// Running interrupt handler
			irq_sm_5 :
			begin
				if (clk_dec.vld && (clk_dec.is == is_mret))
				begin
					clk_irq.msk_clr = 1;
					clk_irq.sm_nxt = irq_sm_6;
				end

				else
					clk_irq.sm_nxt = irq_sm_5;
			end

			irq_sm_6 :
			begin
				// Is there a pending interrupt?
				// Restart the interrupt handler
				if (clk_irq.req)
					clk_irq.sm_nxt = irq_sm_1;

				// Exit
				else
				begin
					clk_irq.pc_ld_mepc = 1;		// Load program counter with saved program counter
					clk_irq.sm_nxt = irq_sm_7;
				end
			end

			// Three clock cycles are needs to flush out the pipeline
			irq_sm_7 :
			begin
				clk_irq.sm_nxt = irq_sm_8;
			end

			irq_sm_8 :
			begin
				clk_irq.sm_nxt = irq_sm_9;
			end

			irq_sm_9 :
			begin
				clk_irq.flush_clr = 1;
				clk_irq.sm_nxt = irq_sm_idle;
			end

			default : 
			begin
				clk_irq.sm_nxt = irq_sm_idle;
			end
		endcase
	end

// Outputs

	// ROM
	assign ROM_IF.en		= ~clk_dec.stall;
	assign ROM_IF.adr 		= clk_fetch.pc;
	assign ROM_IF.rd		= clk_fetch.rd;

	// RAM
	assign RAM_IF.adr 		= clk_ram.adr;
	assign RAM_IF.wr 		= clk_ram.wr;
	assign RAM_IF.rd 		= clk_ram.rd;
	assign RAM_IF.wr_dat 	= clk_ram.dout;
	assign RAM_IF.wr_strb 	= clk_ram.strb;

	// Status
	assign STA_ERR_OUT  	= clk_dec.err;

/*
	Assertions
*/
// synthesis translate_off

// RAM write data and address
initial
begin
	string          inst;

	forever
	begin
		@(posedge CLK_IN);
		if (clk_ram.wr)
		begin
		    if ($isunknown (clk_ram.adr))
				$display ("[@%0t] | Risc-V : RAM write addres is unknown!\n", $time);

		    if ($isunknown (clk_ram.dout))
				$display ("[@%0t] | Risc-V : RAM @ address (%x) write data is unknown!\n", $time, clk_ram.adr);
		end
	end
end

// RAM read address
initial
begin
	string          inst;

	forever
	begin
		@(posedge CLK_IN);
		if (clk_ram.rd)
		begin
			if ($isunknown (clk_ram.adr))
				$display ("[@%0t] | Risc-V : RAM read addres is unknown!\n", $time);
		end
	end
end

// Error flag
initial 
begin
	string          inst;

	forever
	begin
		@(posedge CLK_IN);
		if (clk_dec.err)
		begin
			$display ("[@%0t] | Risc-V : Illegal instruction!\n", $time);
			$stop;
		end
	end
end

// synthesis translate_on

endmodule

`default_nettype wire
