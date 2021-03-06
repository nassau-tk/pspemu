module pspemu.core.Memory;

// --------------------------
//  Related implementations:
// --------------------------
// OLD:       http://pspemu.googlecode.com/svn/branches/old/src/core/memory.d
// PSPPlayer: http://pspplayer.googlecode.com/svn/trunk/Noxa.Emulation.Psp.Cpu.R4000Ultra/R4000Memory.cpp
// Jpcsp:     http://jpcsp.googlecode.com/svn/trunk/src/jpcsp/memory/StandardMemory.java
// mfzpsp:    http://mfzpsp.googlecode.com/svn/c/mfzpsp/src/core/memory.c
// pcsp:      http://pcsp.googlecode.com/svn/trunk/pcsp-dbg/src/memory.h

import std.stdio;
import std.string;
import std.ascii;
import std.metastrings;
import std.conv;
import core.memory;

public import std.stream;

import std.c.windows.windows;

version = VERSION_CHECK_MEMORY;    /// Check more memory positions.
version = VERSION_CHECK_ALIGNMENT; /// Check that read and writes are aligned.
//version = VERSION_VIRTUAL_ALLOC;

struct PspPointer(T) {
	T* value;
	T* opCast(T)() {
		return value;
	}
}

/**--------------------------------+
| Adress                           |
| 31.............................0 |
| ku0hp--------------------------- |
| k - Kernel (only in kern mode)   |
| u - Uncached Bit                 |
| h - Hardware DMA                 |
| p - Physical main mem            |
+--------------------------------**/

/**
 * Exception class for memory exceptions.
 */
class MemoryException : public Exception { this(string s) { super(s); } }

/**
 * Exception class for an invalid memory address.
 */
class InvalidAddressException : public MemoryException {
	this(uint address) {
		super(std.string.format("Invalid address 0x%08X", address));
	}
}

/**
 * Exception class for an invalid alignment memory address.
 */
class InvalidAlignmentException : public MemoryException {
	this(uint address, uint alignment = 4) {
		super(std.string.format("Address 0x%08X not aligned to %d bytes.", address, alignment));
	}
}

/**
 * Class to handle the memory of the psp.
 * It can be used as a stream too.
 */
class Memory {
	/// Several physical memory segments.

	/// Psp Pointer.
	alias uint Pointer;
	
	bool ignoreErrors = false;
	//bool ignoreErrors = true;
	__gshared uint[0x1000] dummyBuffer;

	static struct Segment {
		uint address, mask, size;
		uint low, high;
		static Segment opCall(uint address, uint size) {
			Segment ret;
			{
				ret.address = address;
				ret.mask    = size - 1;
				ret.size    = size;
				ret.low     = address;
				ret.high    = address + size;
			}
			return ret;
		}
	}

	static struct Segments {
		const scratchPad  = Segment(0x00_010000, 0x00004000);
		const frameBuffer = Segment(0x04_000000, 0x00200000);
		//const frameBuffer = Segment(0x04_000000, 0x00800000); // http://hitmen.c02.at/files/yapspd/psp_doc/chap10.html#sec10
		// 0x04_00_00_00 = VRAM 
		// 0x04_20_00_00 = SWIZZLED ZBUFFER
		// 0x04_40_00_00 = VRAM MIRRORED
		// 0x04_80_00_00 = UNSWIZZLED ZBUFFER
		const mainMemory  = Segment(0x08_000000, 0x04000000);
		const hwVectors   = Segment(0x1f_c00000, 0x00100000);
	}

	ubyte* baseMemory;

	/// Scartch Pad is a small memory segment of 16KB that has a very fast access.
	ubyte[] scratchPad ;

	/// Frame Buffer is a integrated memory segment of 2MB for the GPU.
	/// GPU can also access main memory, but slowly.
	ubyte[] frameBuffer;

	/// Main Memory is a big physical memory of 16MB for fat and 32MB for slim.
	/// Currently it only supports fat 16MB.
	ubyte[] mainMemory ;
	
	ubyte[] hwVectors ;
	
	/**
	 * Constructor.
	 * It allocates all the physical memory segments and set the stream properties of the memory.
	 */
	public this() {
		version (VERSION_VIRTUAL_ALLOC) {
			baseMemory = cast(ubyte*)0x10000000;

			string alloc(string name) {
				// *nix: http://linux.die.net/man/2/mmap
				return (
					"VirtualAlloc(baseMemory + Segments." ~ name ~ ".address, Segments." ~ name ~ ".size, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE);"
					"this." ~ name ~ " = (baseMemory + Segments." ~ name ~ ".address)[0..Segments." ~ name ~ ".size];"
				);
			}
		} else {
			string alloc(string name) {
				return "this." ~ name ~ " = new ubyte[Segments." ~ name ~ ".size];";
				//return "this." ~ name ~ " = new ubyte[Segments." ~ name ~ ".size]; core.memory.GC.removeRoot(this." ~ name ~ ".ptr);";
			}
		}
		
		mixin(alloc("scratchPad"));
		mixin(alloc("frameBuffer")); // http://hitmen.c02.at/files/yapspd/psp_doc/chap10.html#sec10 // Mirrors?
		mixin(alloc("mainMemory"));
		mixin(alloc("hwVectors"));

		// reset(); // D already sets all the new ubyte arrays to 0.
	}
	
	~this() {
		version (VERSION_VIRTUAL_ALLOC) {
			void free(ubyte[] v) {
				VirtualFree(v.ptr, v.length, MEM_DECOMMIT);
				VirtualFree(v.ptr, 0, MEM_RELEASE);
			}

			free(scratchPad);
			free(frameBuffer);
			free(mainMemory);
		}
	}

	/**
	 * Sets to zero all the physical memory.
	 */
	public void reset() {
		scratchPad [] = 0;
		frameBuffer[] = 0;
		mainMemory [] = 0;
	}

	/**
	 * HexDumps a slice of the memory.
	 *
	 * @param  address  Psp memory address.
	 * @param  nrows    Number of rows to show starting from address.
	 */
	public void dump(uint address, uint nrows = 0x10) {
		for (int row = 0; row < nrows; row++, address += 0x10) {
			.writef("%08X: ", address);
			foreach (value; this[address + 0x00..address + 0x10]) .writef("%02X ", value);
			.writef("| ");
			foreach (value; this[address + 0x00..address + 0x10]) .writef("%s", isPrintable(cast(dchar)value) ? cast(dchar)value : cast(dchar)'.');
			.writefln("");
		}
	}
	
	public T* getPointerOrNull(T = void)(Pointer address) {
		if (address == 0) return null;
		return cast(T *)getPointer(address);
	}
	
	/**
	 * Obtains a pointer to a physical memory position.
	 *
	 * @param  address  Psp memory address.
	 *
	 * @return A physical PC pointer.
	 */
	public void* getPointer(Pointer address) {
		/*version (VERSION_VIRTUAL_ALLOC) {
			return baseMemory + (address & 0x0FFFFFFF);
		} else*/ {
			// Throws a MemoryException for an invalid address.
			static pure string InvalidAddress() {
				return q{
					if (ignoreErrors) {
						.writefln("InvalidAddressException: 0x%08X", address);
						return dummyBuffer.ptr;
					} else {
						throw(new InvalidAddressException(address));
					}
				};
			}

			// If version(VERSION_CHECK_MEMORY), check that the address is in a specified segment or throws an InvalidAddressException.
			static pure string CheckAddress(string segmentName) {
				return "version (VERSION_CHECK_MEMORY) if ((address < Segments." ~ segmentName ~ ".low) || (address >= (Segments." ~ segmentName ~ ".high))) " ~ InvalidAddress ~ ";";
			}

			// Returns 
			static pure string ReturnSegment(string segmentName) {
				return "return &" ~ segmentName ~ "[address & Segments." ~ segmentName ~ ".mask];";
			}

			// Check the address in this segment if version(VERSION_CHECK_MEMORY) and returns the host pointer.
			static pure string CheckAndReturnSegment(string segmentName) {
				return CheckAddress(segmentName) ~ ReturnSegment(segmentName);
			}
			
			//.writefln("Memory.getPointer(0x%08X)", address);

			address &= 0x1FFFFFFF; // Ignore last 3 bits (cache / kernel)
			switch (address >> 24) {
				/////// hp
				case 0b_00000:
					mixin(CheckAndReturnSegment("scratchPad"));
				break;
				/////// hp
				case 0b_00100:
					mixin(CheckAndReturnSegment("frameBuffer"));
				break;
				/////// hp
				case 0b_01000:
				case 0b_01001:
				case 0b_01010: // SLIM ONLY
				case 0b_01011: // SLIM ONLY
					mixin(CheckAndReturnSegment("mainMemory"));
				break;
				/////// hp
				case 0b_11111: // HO IO2
					mixin(CheckAndReturnSegment("hwVectors"));
				break;
				case 0b_11100: // HW IO1
					mixin(InvalidAddress);
					//return null;
				break;
				default:
					mixin(InvalidAddress);
				break;
			}
		}
	}

	/**
	 * Obtains a guest address from a physical memory address.
	 *
	 * @param  ptr  A physical PC pointer.
	 *
	 * @return Psp memory address.
	 */
	public Pointer getPointerReverse(void *_ptr) {
		Pointer retval = getPointerReverseOrNull(_ptr);
		if (retval == 0) {
			if (ignoreErrors) {
				writefln("Can't find original pointer of address 0x%08X", cast(uint)_ptr);
			} else {
				throw(new Exception(std.string.format("Can't find original pointer of address 0x%08X", cast(uint)_ptr)));
			}

		}
		return retval;
	}
	
	public T* ptrHostToGuest(T)(T* v) {
		return cast(T *)getPointerReverseOrNull(v);
	}

	public T* ptrGuestToHost(T)(T* v) {
		return cast(T *)getPointerOrNull(v);
	}

	/**
	 * Obtains a guest address from a physical memory address.
	 *
	 * @param  ptr  A physical PC pointer.
	 *
	 * @return Psp memory address.
	 */
	public Pointer getPointerReverseOrNull(void *_ptr) {
		auto ptr = cast(ubyte *)_ptr;

		bool between(ubyte[] buffer) { return (ptr >= &buffer[0]) && (ptr < &buffer[$]); }
		string checkMap(string name, uint mapStart) { return "if (between(" ~ name ~ ")) return (ptr - " ~ name ~ ".ptr) + " ~ to!string(mapStart) ~ ";"; }
		
		mixin(checkMap("scratchPad",  0x00010000));
		mixin(checkMap("frameBuffer", 0x04000000));
		mixin(checkMap("mainMemory",  0x08000000));
		return 0;
	}

	/**
	 * Implementation of the read/write functions with several memory sizes.
	 */
	template ReadWriteTemplate() {
		T twrite(T)(uint address, T value) {
			version (VERSION_CHECK_ALIGNMENT) {
				assert(((address & ((T.sizeof) - 1)) == 0), std.string.format("Address 0x%08X not aligned to %d bytes.", address, (T.sizeof >> 3)));
			}
			return *cast(T*)getPointer(address) = value;
		}

		T tread(T)(uint address) {
			version (VERSION_CHECK_ALIGNMENT) {
				//.writefln("%d", T.sizeof);
				assert(((address & ((T.sizeof) - 1)) == 0), std.string.format("Address 0x%08X not aligned to %d bytes.", address, (T.sizeof >> 3)));
			}
			return *cast(T*)getPointer(address);
		}
	}

	/**
	 * Implementation of opSlice and opIndex functions.
	 */
	template ArrayTemplate() {
		/**
		 * Obtains a mutable slice of the memory.
		 * @param  start  Memory address where the slice start.
		 * @param  end    Memory address where the slice end.
		 *
		 * @return Array slice with the data read.
		 */
		public ubyte[] opSlice(uint start, uint end) {
			assert(start <= end);

			// Implementation using stream. (Returns an immutable copy and it's safer)
			static if (0) {
				long backPosition = position; scope (exit) position = backPosition;
				position = start;
				return cast(ubyte[])readString(end - start);
			}
			// Implementation using getPointer. (Mutable and unsafe).
			else {
				assert((getPointer(end) - getPointer(start)) == end - start);
				return (cast(ubyte *)getPointer(start))[0..end - start];
			}
		}

		/**
		 * Sets a slice of the memory.
		 *
		 * @param  data   Array slice with the data to write.
		 * @param  start  Memory address where the slice start.
		 * @param  end    Memory address where the slice end.
		 *
		 * @return Array slice with the data written.
		 *
		 * <code>
		 * memory[0..10] = 0;
		 * </code>
		 */
		public ubyte[] opSliceAssign(ubyte[] data, uint start, uint end) {
			assert(start <= end);
			assert(data.length == end - start);

			// Implementation using stream. (Returns an immutable copy and it's safer)
			static if (0) {
				long backPosition = position; scope (exit) position = backPosition;
				position = start;
				write(data);
				return data;
			}
			// Implementation using getPointer. (Mutable and unsafe).
			else {
				assert((getPointer(end) - getPointer(start)) == end - start);
				auto slice = (cast(ubyte *)getPointer(start))[0..end - start];
				slice[] = data[];
				return slice;
			}
		}

		/**
		 * Obtains a single byte from memory.
		 *
		 * @param  address  Memory address to load from.
		 *
		 * @return A single byte with the data in that memory address.
		 */
		ubyte opIndex(uint address) { return tread!(ubyte)(address); }

		/**
		 * Sets a single byte on memory.
		 *
		 * @param  address  Memory address to write to.
		 *
		 * @return A single byte with the data set in that memory address.
		 */
		ubyte opIndexAssign(ubyte value, uint address) { twrite(address, value); return tread!(ubyte)(address); }
	}

	mixin ReadWriteTemplate;
	mixin ArrayTemplate;
}

class PspMemoryStream : Stream {
	Memory memory;
	
	public this(Memory memory) {
		this.memory = memory;
		streamInit();
	}
	
	/// Position of the stream.
	ulong streamPosition = 0;

	/**
	 * Initializes the stream.
	 */
	void streamInit() {
		this.seekable  = true;
		this.readable  = true;
		this.writeable = true;
	}

	/**
	 * Reads a block of memory from this stream.
	 *
	 * @param  _data  Pointer of an array that will store the contents of the stream.
	 * @param  _len   Number of bytes that will be readed.
	 *
	 * @return Number of bytes readed. Will always be the number of requested bytes to read.
	 */
	override size_t readBlock(void *_data, size_t len) {
		ubyte *data = cast(ubyte*)_data; int rlen = len;
		try {
			while (len-- > 0) *data++ = memory.tread!(ubyte)(cast(uint)streamPosition++);
		} catch (Exception e) {
			return 0;
		}
		return rlen;
	}

	/**
	 * Writes a block of memory in this tream.
	 *
	 * @param  _data  Pointer of an array that contains the data to write.
	 * @param  _len   Number of bytes that will be written.
	 *
	 * @return Number of bytes written. Will always be the number of requested bytes to write.
	 */
	override size_t writeBlock(const void *_data, size_t len) {
		ubyte *data = cast(ubyte*)_data; int rlen = len;
		try {
			while (len-- > 0) memory.twrite!(ubyte)(cast(uint)streamPosition++, *data++);
		} catch (Exception e) {
			return 0;
		}
		return rlen;
	}

	/**
	 * Seeks the stream.
	 *
	 * @param  offset  Offset data.
	 * @param  whence  Type of seeking.
	 *
	 * @return Current position in the stream.
	 */
	override ulong seek(long offset, SeekPos whence) {
		final switch (whence) {
			case SeekPos.Current: streamPosition += offset; break;
			case SeekPos.Set: streamPosition = offset; break;
			case SeekPos.End: streamPosition = 0x10000000 + offset; break;
		}
		return streamPosition;
	}

	/**
	 * Determines wheter the stream reached the end or not.
	 *
	 * @return Always false, because never will get to the end of the stream.
	 */
	override bool eof() { return false; }
}

/+
// http://hitmen.c02.at/files/yapspd/psp_doc/chap4.html#sec4.10
class Cache {
	struct Row {
		ubyte data[64];
	}

	union {
		Row rows[512];
		ubyte data[0x8000]; // 32 KB
	}

	short cached[0x80000]; // 32MB of memory in 64byte segments.
}
+/

/*
struct MemorySegment { enum Type { PHY, DMA } Type type; uint addressStart, addressMask; string name; }

const PspMemorySegmentsFat = [
	MemorySegment( MemorySegment.Type.PHY, 0x00010000, 0x00003FFF, "Scratchpad"       ), // 16 KB
	MemorySegment( MemorySegment.Type.PHY, 0x04000000, 0x001FFFFF, "Frame Buffer"     ), // 2 MB
	MemorySegment( MemorySegment.Type.PHY, 0x08000000, 0x01FFFFFF, "Main Memory"      ), // FAT: 32 MB | SLIM: 64 MB
	MemorySegment( MemorySegment.Type.DMA, 0x1C000000, 0x03BFFFFF, "Hardware IO 1"    ),
	MemorySegment( MemorySegment.Type.PHY, 0x1FC00000, 0x000FFFFF, "Hardware Vectors" ), // 1 MB
	MemorySegment( MemorySegment.Type.DMA, 0x1FD00000, 0x002FFFFF, "Hardware IO 2"    ),
	MemorySegment( MemorySegment.Type.PHY, 0x88000000, 0x01FFFFFF, "Kernel Memory"    ), // Main Memory
];
*/
