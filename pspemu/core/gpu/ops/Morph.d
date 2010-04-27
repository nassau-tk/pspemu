module pspemu.core.gpu.ops.Morph;

template Gpu_Morph() {
	/**
	 * Specify morph weight entry
	 *
	 * To enable vertex morphing, pass GU_VERTICES(n), where n is between
	 * 1-8. This will change the amount of vertices passed in the vertex array,
	 * and by setting the morph weights for every vertex entry in the array,
	 * you can blend between them.
	 *
	 * Please see sceGuDrawArray() for vertex format information.
	 *
	 * @param index  - Morph weight index (0-7)
	 * @param weight - Weight to set
	**/
	// void sceGuMorphWeight(int index, float weight);
	mixin (ArrayOperation("OP_MW_n", 0, 7, q{
		gpu.state.morphWeights[Index] = command.float1;
	}));
}
