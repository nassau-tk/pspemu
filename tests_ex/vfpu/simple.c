/*
FPU Test. Originally from jpcsp project:
http://code.google.com/p/jpcsp/source/browse/trunk/demos/src/fputest/main.c
Modified to perform automated tests.
*/

//#pragma compile, "%PSPSDK%/bin/psp-gcc" -I. -I"%PSPSDK%/psp/sdk/include" -L. -L"%PSPSDK%/psp/sdk/lib" -D_PSP_FW_VERSION=150 -Wall -g simple.c ../common/emits.c -lpspsdk -lc -lpspuser -lpspkernel -o simple.elf
//#pragma compile, "%PSPSDK%/bin/psp-fixup-imports" simple.elf

#include <pspkernel.h>
#include <stdio.h>
#include <string.h>
#include "../common/emits.h"

PSP_MODULE_INFO("vfpu test", 0, 1, 1);

PSP_MAIN_THREAD_ATTR(THREAD_ATTR_USER | PSP_THREAD_ATTR_VFPU);

void __attribute__((noinline)) vcopy(ScePspFVector4 *v0, ScePspFVector4 *v1) {
	asm volatile (
		"lv.q   C100, %1\n"
		"sv.q   C100, %0\n"

		: "+m" (*v0) : "m" (*v1)
	);
}

void __attribute__((noinline)) vdotq(ScePspFVector4 *v0, ScePspFVector4 *v1, ScePspFVector4 *v2) {
	asm volatile (
		"lv.q   C100, %1\n"
		"lv.q   C200, %2\n"
		"vdot.q S000, C100, C200\n"
		"sv.q   C000, %0\n"

		: "+m" (*v0) : "m" (*v1), "m" (*v2)
	);
}

void __attribute__((noinline)) vsclq(ScePspFVector4 *v0, ScePspFVector4 *v1, ScePspFVector4 *v2) {
	asm volatile (
		"lv.q   C100, %1\n"
		"lv.q   C200, %2\n"
		"vscl.q C300, C100, S200\n"
		"sv.q   C300, %0\n"

		: "+m" (*v0) : "m" (*v1), "m" (*v2)
	);
}

void __attribute__((noinline)) vmidt(int size, ScePspFVector4 *v0, ScePspFVector4 *v1) {
	asm volatile (
		"lv.q    R000, %1\n"
		"lv.q    R001, %1\n"
		"lv.q    R002, %1\n"
		"lv.q    R003, %1\n"

		: "+m" (*v0) : "m" (*v1)
	);
	
	switch (size) {
		case 2: asm volatile("vmidt.p M000\n"); break;
		case 3: asm volatile("vmidt.t M000\n"); break;
		case 4: asm volatile("vmidt.q M000\n"); break;
	}

	asm volatile (
		"sv.q    R000, 0x00+%0\n"
		"sv.q    R001, 0x10+%0\n"
		"sv.q    R002, 0x20+%0\n"
		"sv.q    R003, 0x30+%0\n"

		: "+m" (*v0) : "m" (*v1)
	);
}

ScePspFVector4 v0, v1, v2;
ScePspFVector4 matrix[4];

void initValues() {
	// Reset output values
	v0.x = 1001;
	v0.y = 1002;
	v0.z = 1003;
	v0.w = 1004;

	v1.x = 17;
	v1.y = 13;
	v1.z = -5;
	v1.w = 11;

	v2.x = 3;
	v2.y = -7;
	v2.z = -15;
	v2.w = 19;
}

void checkMatrixIdentity() {
	int vsize, x, y;
	ScePspFVector4 matrix2[4];
	for (vsize = 2; vsize <= 4; vsize++) {
		v0.x = 100;
		v0.y = 101;
		v0.z = 102;
		v0.w = 103;
		vmidt(vsize, &matrix[0], &v0);
		for (y = 0; y < 4; y++) {
			matrix2[y] = v0;
			for (x = 0; x < 4; x++) {
				if (x < vsize && y < vsize) {
					((float *)&matrix2[y])[x] = (float)(x == y);
				}
			}
		}
		/*
		Kprintf("-------------------\n");
		for (y = 0; y < 4; y++) Kprintf("(%3.0f, %3.0f, %3.0f, %3.0f)\n", matrix[y].x, matrix[y].y, matrix[y].z, matrix[y].w);
		Kprintf("+\n");
		for (y = 0; y < 4; y++) Kprintf("(%3.0f, %3.0f, %3.0f, %3.0f)\n", matrix2[y].x, matrix2[y].y, matrix2[y].z, matrix2[y].w);
		Kprintf("\n");
		*/
		emitInt(memcmp((void *)&matrix, (void *)&matrix2, sizeof(matrix)));
	}
	
	//Kprintf("Test! %f, %f, %f, %f, %f, %f, %f, %f, %f, %f\n", 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0);
	//Kprintf("Test! %d, %d, %d, %d\n", 1, 2, 3, -3);
}

int main(int argc, char *argv[]) {
	initValues();
	vcopy(&v0, &v1);
	emitFloat(v0.x);
	emitFloat(v0.y);
	emitFloat(v0.z);
	emitFloat(v0.w);

	initValues();
	vdotq(&v0, &v1, &v2);
	emitFloat(v0.x);

	initValues();
	vsclq(&v0, &v1, &v2);
	emitFloat(v0.x);
	emitFloat(v0.y);
	emitFloat(v0.z);
	emitFloat(v0.w);

	checkMatrixIdentity();

	return 0;
}