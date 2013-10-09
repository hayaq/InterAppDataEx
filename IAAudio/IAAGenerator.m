#import "IAAGenerator.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioUnit/AudioUnit.h>

typedef struct IAAData{
	uint8_t *bytes;
	uint32_t totalBytes;
	uint32_t procBytes;
}IAAData;

void AudioUnitPropertyChanged(void *inRefCon, AudioUnit inUnit,
							  AudioUnitPropertyID inID, AudioUnitScope inScope,
							  AudioUnitElement inElement);

OSStatus renderCallback(void *inRefCon,
						AudioUnitRenderActionFlags 	*ioActionFlags,
						const AudioTimeStamp 		*inTimeStamp,
						UInt32 						inBusNumber,
						UInt32 						inNumberFrames,
						AudioBufferList 			*ioData);


@implementation IAAGenerator{
	AudioUnit _remoteIOUnit;
	NSData   *_sendData;
	IAAData   _sendDataInfo;
	NSString *_iaaName;
	AudioComponentDescription _iaaDesc;
}

+(NSString*)iaaName{
	return @"IAADataEx";
}

+(AudioComponentDescription)iaaDescription{
	AudioComponentDescription desc;
	desc.componentType = kAudioUnitType_RemoteGenerator;
	desc.componentSubType = 'aaaa';
	desc.componentManufacturer = 'qqqq';
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;
	return desc;
}

+(AudioComponent)findComponent{
	NSString *iaaName = [IAAGenerator iaaName];
	AudioComponentDescription searchDesc = [IAAGenerator iaaDescription];
	AudioComponentDescription foundDesc = { 0, 0, 0, 0, 0 };
	AudioComponent foundComp = NULL;
	AudioComponent comp = NULL;
	while( (comp=AudioComponentFindNext(comp,&searchDesc)) ){
		AudioComponentDescription desc;
		if( AudioComponentGetDescription(comp, &desc)!=noErr){
			continue;
		}
		if( desc.componentType != kAudioUnitType_RemoteGenerator ){
			continue;
		}
		CFStringRef cmpName = NULL;
		AudioComponentCopyName(comp,&cmpName);
		if( [iaaName isEqual:(__bridge NSString*)(cmpName)] ){
			foundComp = comp;
			foundDesc = desc;
			CFRelease(cmpName);
			break;
		}
		CFRelease(cmpName);
	}
	return foundComp;
}

+(AudioStreamBasicDescription)streamDescription{
	AudioStreamBasicDescription fmt;
	fmt.mSampleRate = [[AVAudioSession sharedInstance] sampleRate];
	fmt.mFormatID = kAudioFormatLinearPCM;
	fmt.mFormatFlags = kAudioFormatFlagIsPacked|kAudioFormatFlagIsSignedInteger;
	fmt.mBytesPerPacket = 4;
	fmt.mFramesPerPacket = 1;
	fmt.mBytesPerFrame = 4;
	fmt.mChannelsPerFrame = 2;
	fmt.mBitsPerChannel = 2 * 8;
	return fmt;
}

-(id)initWithData:(NSData *)data{
	self = [super init];
	_sendData = data;
	_sendDataInfo.bytes = (uint8_t*)[data bytes];
	_sendDataInfo.totalBytes = (uint32_t)[data length];
	_iaaName = [IAAGenerator iaaName];
	_iaaDesc = [IAAGenerator iaaDescription];
	[self initGeneratorAudioUnit];
	return self;
}

-(void)start{
	NSLog(@"[IAAGenerator]: Start remoteIOUnit");
	_sendDataInfo.procBytes = 0;
	AudioOutputUnitStart(_remoteIOUnit);
}

-(void)stop{
	NSLog(@"[IAAGenerator]: Stop remoteIOUnit");
	AudioOutputUnitStop(_remoteIOUnit);
}

-(void)initGeneratorAudioUnit
{
	AudioComponentDescription desc;
	desc.componentType = kAudioUnitType_Output;
	desc.componentSubType = kAudioUnitSubType_RemoteIO;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;
	
	AudioComponent output = AudioComponentFindNext(NULL, &desc);
	AudioComponentInstanceNew(output, &_remoteIOUnit);
	
	UInt32 flag = 1;
	AudioUnitSetProperty(_remoteIOUnit,
						 kAudioOutputUnitProperty_EnableIO,
						 kAudioUnitScope_Output,
						 0,&flag,sizeof(flag));
	
	AudioStreamBasicDescription fmt = [IAAGenerator streamDescription];
	
	AudioUnitSetProperty(_remoteIOUnit,
						 kAudioUnitProperty_StreamFormat,
						 kAudioUnitScope_Input,
						 0,&fmt,sizeof(fmt));
	
	AudioUnitSetProperty(_remoteIOUnit,
						 kAudioUnitProperty_StreamFormat,
						 kAudioUnitScope_Output,
						 0,&fmt,sizeof(fmt));
	
	AURenderCallbackStruct callback;
	callback.inputProc = renderCallback;
	callback.inputProcRefCon = &_sendDataInfo;
	AudioUnitSetProperty(_remoteIOUnit,
						 kAudioUnitProperty_SetRenderCallback,
						 kAudioUnitScope_Global,
						 0,&callback,sizeof(callback));
	
	AudioOutputUnitPublish(&_iaaDesc, (__bridge CFStringRef)_iaaName, 1, _remoteIOUnit);
	AudioUnitAddPropertyListener(_remoteIOUnit,
								 kAudioUnitProperty_IsInterAppConnected,
								 AudioUnitPropertyChanged,(__bridge void *)(self));
	
	AudioUnitInitialize(_remoteIOUnit);
}



@end

void AudioUnitPropertyChanged(void *inRefCon, AudioUnit inUnit,
							  AudioUnitPropertyID inID, AudioUnitScope inScope,
							  AudioUnitElement inElement)
{
	IAAGenerator *generator = (__bridge IAAGenerator*)inRefCon;
    if( inID==kAudioUnitProperty_IsInterAppConnected ){
        UInt32 connect;
        UInt32 dataSize = sizeof(UInt32);
        AudioUnitGetProperty(inUnit, kAudioUnitProperty_IsInterAppConnected,
							 kAudioUnitScope_Global, 0, &connect, &dataSize);
        if( connect ){
			NSLog(@"[IAAGenerator]: IAA Connected");
			[generator start];
        }else{
			[generator stop];
			NSLog(@"[IAAGenerator]: IAA Disconnected");
		}
    }
}

OSStatus renderCallback(void *inRefCon,
						AudioUnitRenderActionFlags 	*ioActionFlags,
						const AudioTimeStamp 		*inTimeStamp,
						UInt32 						inBusNumber,
						UInt32 						inNumberFrames,
						AudioBufferList 			*ioData)

{
	IAAData *sendData = (IAAData*)inRefCon;
	uint32_t *ptr = (uint32_t*)ioData->mBuffers[0].mData;
	int byteSize = inNumberFrames*4;
	memset(ptr, 0, byteSize);
	if( sendData->procBytes == 0 ){
		*ptr++ = sendData->totalBytes;
		byteSize -= 4;
	}
	if( sendData->procBytes+byteSize > sendData->totalBytes ){
		byteSize = sendData->totalBytes - sendData->procBytes;
	}
	if( byteSize > 0 ){
		uint8_t *src = sendData->bytes+sendData->procBytes;
		memcpy(ptr, src, byteSize);
		sendData->procBytes += byteSize;
	}
	return noErr;
}

