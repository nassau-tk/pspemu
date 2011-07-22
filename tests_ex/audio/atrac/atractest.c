#include <pspsdk.h>
#include <pspkernel.h>
#include <pspatrac3.h>
#include <pspaudio.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

PSP_MODULE_INFO("atrac test", 0, 1, 1);
PSP_MAIN_THREAD_ATTR(THREAD_ATTR_USER);

int main(int argc, char *argv[]) {
	char *at3_data;
	int at3_size;

	char *decode_data;
	int decode_size;
	int n;

	FILE *file;

	int atracID;
	int maxSamples = 0;
	int result;
	int channel;
	
	u32 puiPosition;
	u32 puiDataByte;
	
	file = fopen("sample.at3", "rb");
	fseek(file, 0, SEEK_END);
	at3_size = ftell(file);
	
	fseek(file, 0, SEEK_SET);
	
	at3_data = malloc(at3_size);
	decode_data = malloc(decode_size = 512 * 1024);
	memset(at3_data, 0, at3_size);
	memset(decode_data, 0, decode_size);
	
	fread(at3_data, at3_size, 1, file);

	fclose(file);

	pspDebugScreenInit();
	
	if (pspSdkLoadStartModule("flash0:/kd/audiocodec.prx", PSP_MEMORY_PARTITION_KERNEL) < 0) {
		pspDebugScreenPrintf("Error loading module audiocodec.prx\n");
		return -1;
	}
	
	pspDebugScreenPrintf("at3: %08X, %08X\n", (unsigned int)at3_data, at3_size);
	pspDebugScreenPrintf("Header: %s\n", (char *)at3_data);
		
	atracID = sceAtracSetDataAndGetID(at3_data, at3_size);
	
	result = sceAtracSetLoopNum(atracID, 2);
	pspDebugScreenPrintf("sceAtracSetLoopNum: %08X\n", result);

	pspDebugScreenPrintf("sceAtracSetDataAndGetID: %08X\n", atracID);
	
	result = sceAtracGetMaxSample(atracID, &maxSamples);
	pspDebugScreenPrintf("sceAtracGetMaxSample: %08X, %d\n", result, maxSamples);
	
	channel = sceAudioChReserve(0, maxSamples, PSP_AUDIO_FORMAT_STEREO);
	
	result = sceAtracGetSecondBufferInfo(atracID, &puiPosition, &puiDataByte);
	pspDebugScreenPrintf("sceAtracGetSecondBufferInfo: %08X, %d, %d\n", result, puiPosition, puiDataByte);
	
	int end = 0;
	int steps = 0;
	while (!end) {
		//int remainFrame = -1;
		int remainFrame = 0;
		//int decodeBufferPosition = 0;
		int samples = 0;
		int nextSample = 0;
		u32 nextPosition = 0;
		
		if (steps < 4) {
			result = sceAtracGetNextSample(atracID, &nextSample);
			pspDebugScreenPrintf("sceAtracGetNextSample(%d): %d\n", result, nextSample);
			result = sceAtracGetNextDecodePosition(atracID, &nextPosition);
			pspDebugScreenPrintf("sceAtracGetNextDecodePosition(%d): %d\n", result, nextPosition);
		}

		result = sceAtracDecodeData(atracID, (u16 *)decode_data, &samples, &end, &remainFrame);
		
		if (steps < 4) {
			
		}
		
		sceAudioSetChannelDataLen(channel, samples);
		sceAudioOutputBlocking(channel, 0x8000, decode_data);
		
		result = sceAtracGetRemainFrame(atracID, &remainFrame);

		if (steps < 4) {
			pspDebugScreenPrintf("sceAtracDecodeData: %08X, at3_size: %d, decode_size: %d, samples: %d, end: %d, remainFrame: %d\n\n", result, at3_size, decode_size, samples, end, remainFrame);
			if (steps == 1) {
				for (n = 0; n < 32; n++) pspDebugScreenPrintf("%04X ", (u16)decode_data[n]);
			}
			pspDebugScreenPrintf("sceAtracGetRemainFrame: %08X\n", result);
		}

		steps++;
	}
	
	sceAudioChRelease(channel);
	result = sceAtracReleaseAtracID(atracID);
	pspDebugScreenPrintf("sceAtracGetRemainFrame: %08X\n", result);

	return 0;
}