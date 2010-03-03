module pspemu.core.cpu.cpu_ops_alu;

private import pspemu.core.cpu.cpu_utils;
private import pspemu.core.cpu.registers;
private import pspemu.core.cpu.instruction;
private import pspemu.core.memory;

private import std.stdio;

// http://pspemu.googlecode.com/svn/branches/old/src/core/cpu.d
// http://pspemu.googlecode.com/svn/branches/old/util/gen/impl/SPECIAL
// http://pspemu.googlecode.com/svn/branches/old/util/gen/impl/MISC
template TemplateCpu_ALU() {
	mixin TemplateCpu_ALU_Utils;

	// ADD(U) -- Add (Unsigned)
	// Adds two registers and stores the result in a register
	// $d = $s + $t; advance_pc (4);
	auto OP_ADD () { mixin(CE("$rd = #rs + #rt;")); }
	auto OP_ADDU() { mixin(CE("$rd = $rs + $rt;")); }
	auto OP_SUB () { mixin(CE("$rd = #rs - #rt;")); }
	auto OP_SUBU() { mixin(CE("$rd = $rs - $rt;")); }

	// ADDI(U) -- Add immediate (Unsigned)
	// Adds a register and a signed immediate value and stores the result in a register
	// $t = $s + imm; advance_pc (4);
	auto OP_ADDI () { mixin(CE("$rt = #rs + #im;")); }
	auto OP_ADDIU() { mixin(CE("$rt = $rs + $im;")); }

	// AND -- Bitwise and
	// Bitwise ands two registers and stores the result in a register
	// $d = $s & $t; advance_pc (4);
	auto OP_AND() { mixin(CE("$rd = $rs & $rt;")); }
	auto OP_OR () { mixin(CE("$rd = $rs | $rt;")); }
	auto OP_XOR() { mixin(CE("$rd = $rs ^ $rt;")); }
	auto OP_NOR() { mixin(CE("$rd = ~($rs | $rt);")); }

	// MOVZ -- MOV If Zero?
	// MOVN -- MOV If Non Zero?
	auto OP_MOVZ() { mixin(CE("if ($rt == 0) $rd = $rs;")); }
	auto OP_MOVN() { mixin(CE("if ($rt != 0) $rd = $rs;")); }

	// ANDI -- Bitwise and immediate
	// ORI -- Bitwise and immediate
	// Bitwise ands a register and an immediate value and stores the result in a register
	// $t = $s & imm; advance_pc (4);
	auto OP_ANDI() { mixin(CE("$rt = $rs & $im;")); }
	auto OP_ORI () { mixin(CE("$rt = $rs | $im;")); }
	auto OP_XORI() { mixin(CE("$rt = $rs ^ $im;")); }

	// SLT(I)(U)  -- Set Less Than (Immediate) (Unsigned)
	auto OP_SLT  () { mixin(CE("$rd = #rs < #rt;")); }
	auto OP_SLTU () { mixin(CE("$rd = $rs < $rt;")); }
	auto OP_SLTI () { mixin(CE("$rt = #rs < #im;")); }
	auto OP_SLTIU() { mixin(CE("$rt = $rs < $im;")); }

	// LUI -- Load upper immediate
	// The immediate value is shifted left 16 bits and stored in the register. The lower 16 bits are zeroes.
	// $t = (imm << 16); advance_pc (4);
	auto OP_LUI() { mixin(CE("$rt = (#im << 16);")); }

	// SEB - Sign Extension Byte
	// SEH - Sign Extension Half
	auto OP_SEB() { mixin(CE("$rd = SEB(cast(ubyte )$rt);")); }
	auto OP_SEH() { mixin(CE("$rd = SEH(cast(ushort)$rt);")); }

	// ROTR -- Rotate Word Right
	// ROTV -- Rotate Word Right Variable
	auto OP_ROTR() { mixin(CE("$rd = ROTR($rt, $ps);")); }
	auto OP_ROTV() { mixin(CE("$rd = ROTR($rt, $rs);")); }

	// SLL(V) - Shift Word Left Logical (Variable)
	// SRA(V) - Shift Word Right Arithmetic (Variable)
	// SRL(V) - Shift Word Right Logic (Variable)
	auto OP_SLL () { mixin(CE("$rd = SLL($rt, $ps);")); }
	auto OP_SLLV() { mixin(CE("$rd = SLL($rt, $rs);")); }
	auto OP_SRA () { mixin(CE("$rd = SRA($rt, $ps);")); }
	auto OP_SRAV() { mixin(CE("$rd = SRA($rt, $rs);")); }
	auto OP_SRL () { mixin(CE("$rd = SRL($rt, $ps);")); }
	auto OP_SRLV() { mixin(CE("$rd = SRL($rt, $rs);")); }

	// EXT -- EXTract
	// INS -- INSert
	auto OP_EXT() { mixin(CE("$rt = ($rs >> $ps) & MASK($sz + 1);")); }
	auto OP_INS() { mixin(CE("uint mask = MASK(instruction.SIZE - instruction.POS + 1); $rt = ($rt & ~(mask << $ps)) | (($rs & mask) << $ps);")); }

	// BITREV - Bit Reverse
	auto OP_BITREV() { mixin(CE("$rd = REV4($rt);")); }

	// MAX/MIN
	auto OP_MAX() { mixin(CE("$rd = MAX(#rs, #rt);")); }
	auto OP_MIN() { mixin(CE("$rd = MIN(#rs, #rt);")); }

	// DIV -- Divide
	// DIVU -- Divide Unsigned
	// Divides $s by $t and stores the quotient in $LO and the remainder in $HI
	// $LO = $s / $t; $HI = $s % $t; advance_pc (4);
	auto OP_DIV() {
		void DIVS(int a, int b) { registers.LO = a / b; registers.HI = a % b; }
		mixin(CE("DIVS($rs, $rt);"));
	}
	auto OP_DIVU() {
		void DIVU(uint a, uint b) { registers.LO = a / b; registers.HI = a % b; }
		mixin(CE("DIVU($rs, $rt);"));
	}

	// MULT -- Multiply
	// MULTU -- Multiply unsigned
	auto OP_MULT() {
		void MULTS(int  a, int  b) { int l, h; asm { mov EAX, a; mov EBX, b; imul EBX; mov l, EAX; mov h, EDX; } registers.LO = l; registers.HI = h; }
		mixin(CE("MULTS($rs, $rt);"));
	}
	auto OP_MULTU() {
		void MULTU(uint a, uint b) { int l, h; asm { mov EAX, a; mov EBX, b; mul EBX; mov l, EAX; mov h, EDX; } registers.LO = l; registers.HI = h; }
		mixin(CE("MULTU($rs, $rt);"));
	}

	// MADD
	auto OP_MADD() {
		int rs = registers[instruction.RS], rt = registers[instruction.RT], lo = registers.LO, hi = registers.HI;
		asm { mov EAX, rs; imul rt; add lo, EAX; adc hi, EDX; }
		registers.LO = lo;
		registers.HI = hi;
		registers.pcAdvance(4);
	}
	auto OP_MADDU() {
		int rs = registers[instruction.RS], rt = registers[instruction.RT], lo = registers.LO, hi = registers.HI;
		asm { mov EAX, rs; mul rt; add lo, EAX; adc hi, EDX; }
		registers.LO = lo;
		registers.HI = hi;
		registers.pcAdvance(4);
	}

	// MSUB
	auto OP_MSUB() { // FIXME: CHECK.
		int rs = registers[instruction.RS], rt = registers[instruction.RT], lo = registers.LO, hi = registers.HI;
		asm { mov EAX, rs; imul rt; sub lo, EAX; sub hi, EDX; }
		registers.LO = lo;
		registers.HI = hi;
		registers.pcAdvance(4);
	}
	auto OP_MSUBU() { // FIXME: CHECK.
		int rs = registers[instruction.RS], rt = registers[instruction.RT], lo = registers.LO, hi = registers.HI;
		asm { mov EAX, rs; mul rt; sub lo, EAX; sub hi, EDX; }
		registers.LO = lo;
		registers.HI = hi;
		registers.pcAdvance(4);
	}

	// MFHI/MFLO -- Move from HI/LO
	// MTHI/MTLO -- Move to HI/LO
	auto OP_MFHI() { mixin(CE("$rd = $hi;")); }
	auto OP_MFLO() { mixin(CE("$rd = $lo;")); }
	auto OP_MTHI() { mixin(CE("$hi = $rs;")); }
	auto OP_MTLO() { mixin(CE("$lo = $rs;")); }

	// WSBH -- Word Swap Bytes Within Halfwords
	// WSBW -- Word Swap Bytes Within Words?? // FIXME! Not sure about this!
	auto OP_WSBH() { mixin(CE("$rd = WSBH($rt);")); }
	auto OP_WSBW() { mixin(CE("$rd = WSBW($rt);")); }
}

template TemplateCpu_ALU_Utils() {
	static final {
		int MASK(uint bits) { return ((1 << cast(ubyte)bits) - 1); }
		uint SEB(ubyte  r0) { uint r1; asm { xor EAX, EAX; mov AL, r0; movsx EBX, AL; mov r1, EBX; } return r1; }
		uint SEH(ushort r0) { uint r1; asm { xor EAX, EAX; mov AX, r0; movsx EBX, AX; mov r1, EBX; } return r1; }
		uint ROTR(uint a, uint b) { b = (b & 0x1F); asm { mov EAX, a; mov ECX, b; ror EAX, CL; mov a, EAX; } return a; }
		uint SLA(int a, int b) { asm { mov EAX, a; mov ECX, b; sal EAX, CL; mov a, EAX; } return a; }
		uint SLL(int a, int b) { asm { mov EAX, a; mov ECX, b; shl EAX, CL; mov a, EAX; } return a; }
		uint SRA(int a, int b) { asm { mov EAX, a; mov ECX, b; sar EAX, CL; mov a, EAX; } return a; }
		uint SRL(int a, int b) { asm { mov EAX, a; mov ECX, b; shr EAX, CL; mov a, EAX; } return a; }
		// http://www-graphics.stanford.edu/~seander/bithacks.html#BitReverseObvious
		uint REV4(uint v) {
			v = ((v >> 1) & 0x55555555) | ((v & 0x55555555) << 1 ); // swap odd and even bits
			v = ((v >> 2) & 0x33333333) | ((v & 0x33333333) << 2 ); // swap consecutive pairs
			v = ((v >> 4) & 0x0F0F0F0F) | ((v & 0x0F0F0F0F) << 4 ); // swap nibbles ... 
			v = ((v >> 8) & 0x00FF00FF) | ((v & 0x00FF00FF) << 8 ); // swap bytes
			v = ( v >> 16             ) | ( v               << 16); // swap 2-byte long pairs
			return v;
		}
		T MAX(T)(T a, T b) { return (a > b) ? a : b; }
		T MIN(T)(T a, T b) { return (a < b) ? a : b; }
		uint WSBH(uint v) { return ((v & 0x_FF00_FF00) >> 8) | ((v & 0x_00FF_00FF) << 8); } // swap bytes
		uint WSBW(uint v) {
			static struct UINT { union { uint i; ubyte[4] b; } }
			UINT vs = void, vd = void; vs.i = v;
			vd.b[0] = vs.b[3];
			vd.b[1] = vs.b[2];
			vd.b[2] = vs.b[1];
			vd.b[3] = vs.b[0];
			return vd.i;
		}
	}
}

unittest {
	writefln("Unittesting: " ~ __FILE__ ~ "...");
	scope memory    = new Memory;
	scope registers = new Registers;
	Instruction instruction = void;

	mixin TemplateCpu_ALU;

	writefln("  Check ADD");
	{
		registers.PC = 0x1000;
		registers.nPC = 0x1004;
		registers[2] = 7;
		registers[3] = 11;
		instruction.RD = 1;
		instruction.RS = 2;
		instruction.RT = 3;
		OP_ADD();
		assert(registers[1] == 7 + 11);
		assert(registers.PC == 0x1004);
		assert(registers.nPC == 0x1008);
	}

	writefln("  Check AND");
	{
		registers[2] = 0x_FEFFFFFE;
		registers[3] = 0x_A7B39273;
		instruction.RD = 1;
		instruction.RS = 2;
		instruction.RT = 3;
		OP_AND();
		assert(registers[1] == (0x_FEFFFFFE & 0x_A7B39273));
		assert(registers.nPC == registers.PC + 4);
	}

	writefln("  Check ANDI");
	{
		registers[2] = 0x_FFFFFFFF;
		instruction.RT = 1;
		instruction.RS = 2;
		instruction.IMMU = 0x_FF77;
		OP_ANDI();
		assert(registers[1] == (0x_FFFFFFFF & 0x_FF77));
		assert(registers.nPC == registers.PC + 4);
	}

	writefln("  Check BITREV");
	{
		// php -r"for ($r = '', $n = 0; $n < 32; $n++) $r .= mt_rand(0, 1); printf('0b_%s : 0b_%s,' . chr(10), $r, strrev($r));"
		// def bin(r, dig=32):return ''.join([str((r >> x) & 1) for x in xrange(dig, -1, -1)])
		// import random; x = ''.join([str(random.randint(0, 1)) for x in xrange(0, 32)]); print '0b_%s : 0b_%s' % (x, x[::-1])
		scope expectedList = [
			// Hand crafted.
			0b_00000000000000000000000000000000 : 0b_00000000000000000000000000000000,
			0b_11111111111111111111111111111111 : 0b_11111111111111111111111111111111,
			0b_10000000000000000000000000000000 : 0b_00000000000000000000000000000001,

			// Random.
			0b_10110010011111100010101010000011 : 0b_11000001010101000111111001001101,
			0b_01110101010111100111010110010001 : 0b_10001001101011100111101010101110,
			0b_10001010010110110111011100101011 : 0b_11010100111011101101101001010001,
			0b_01101110000110111011101110001010 : 0b_01010001110111011101100001110110,
			0b_10000110001100101110100111011111 : 0b_11111011100101110100110001100001,
			0b_11001001000110110011001010111110 : 0b_01111101010011001101100010010011,
		];

		foreach (a, b; expectedList) {
			foreach (entry; [[a, b], [b, a]]) {
				registers[2] = entry[0];
				instruction.RD = 1;
				instruction.RT = 2;
				OP_BITREV();
				//registers.dump(); writefln("%08X:%08X", entry[0], entry[1]);
				assert(registers[1] == entry[1]);
				assert(registers.nPC == registers.PC + 4);
			}
		}
	}
}