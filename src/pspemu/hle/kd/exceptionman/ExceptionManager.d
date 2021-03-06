module pspemu.hle.kd.exceptionman.ExceptionManager; // kd/exceptionman.prx (sceExceptionManager):

import pspemu.hle.ModuleNative;

class ExceptionManagerForKernel : HleModuleHost {
	mixin TRegisterModule;

	void initNids() {
		mixin(registerFunction!(0x565C0B0E, sceKernelRegisterDefaultExceptionHandler));
	}

	void* exceptionHandler;

	/**
	 * Register a default exception handler.
	 *
	 * @param func - Pointer to the exception handler function
	 * @note The exception handler function must start with a NOP
	 *
	 * @return 0 on success, < 0 on error
	 */
	int sceKernelRegisterDefaultExceptionHandler(void* func) {
		if (func is null) return -1;
		exceptionHandler = func;
		//unimplemented();
		return 0;
	}
}
