#import "IAAReceiver.h"
#import "IAAGenerator.h"
#import <AVFoundation/AVFoundation.h>

typedef struct IAAData{
	uint8_t *bytes;
	uint32_t totalBytes;
	uint32_t procBytes;
}IAAData;

static AudioComponentDescription ACDescMake(OSType,OSType,OSType);

static OSStatus recordCallback(void *inRefCon,
							   AudioUnitRenderActionFlags *ioActionFlags,
							   const AudioTimeStamp *inTimeStamp,
							   UInt32 inBusNumber,
							   UInt32 inNumberFrames,
							   AudioBufferList * ioData);

@implementation IAAReceiver{
@public
	AUGraph _graph;
	AudioUnit _remoteAU;
	AudioComponent _remoteComponent;
	NSMutableData *_recvData;
	IAAData _recvDataInfo;
}

-(id)init{
	self = [super init];
	AVAudioSession *session = [AVAudioSession sharedInstance];
	[session setCategory:AVAudioSessionCategoryPlayback
			 withOptions:AVAudioSessionCategoryOptionMixWithOthers error:Nil];
	[session setActive:YES error:nil];
	[self setupRemoteAudioUnit];
	return self;
}

- (void)dealloc
{
	if( _graph ){
		AUGraphUninitialize(_graph);
		AUGraphClose(_graph);
	}
}

-(void)start{
	if( !_graph ){ return; }
	_recvData = [[NSMutableData alloc] init];
	_recvDataInfo.bytes = NULL;
	_recvDataInfo.procBytes = 0;
	_recvDataInfo.totalBytes = 0;
	AUGraphStart(_graph);
}

-(void)stop{
	if( !_graph ){ return; }
	AUGraphStop(_graph);
}

-(UIImage*)remoteAudioAppIcon{
	if( !_remoteComponent ){ return nil; }
	return AudioComponentGetIcon(_remoteComponent,60);
}

-(NSURL*)remoteAudioAppURL{
	if( !_remoteAU ){ return nil; }
	NSURL *url = NULL;
	UInt32 urlSize = sizeof(url);
	AudioUnitGetProperty(_remoteAU,
						 kAudioUnitProperty_PeerURL,
						 kAudioUnitScope_Global,
						 0, &url, &urlSize);
	return url;
}

#define AU_CHECK() if(result){ NSLog(@"AUError@%d %08X\n",__LINE__,(uint32_t)result); return; }

-(void)setupRemoteAudioUnit
{
	if( _graph ){ return; }
	
	_remoteComponent = [IAAGenerator findComponent];
	if( !_remoteComponent ){ return; }
	
	OSStatus result = NewAUGraph(&_graph);
	
	// output unit
	AudioComponentDescription outDesc = ACDescMake(kAudioUnitType_Output,
												kAudioUnitSubType_RemoteIO,
												kAudioUnitManufacturer_Apple);
	
	AudioComponentDescription mixDesc = ACDescMake(kAudioUnitType_Mixer,
												kAudioUnitSubType_MultiChannelMixer,
												kAudioUnitManufacturer_Apple);
	
	AUNode outNode = 0;
	AUNode mixNode = 0;
	AUNode inNode = 0;
	
	result = AUGraphAddNode(_graph, &outDesc, &outNode);
	AU_CHECK();
	
	result = AUGraphAddNode(_graph, &mixDesc, &mixNode);
	AU_CHECK();
	
	result = AUGraphConnectNodeInput(_graph, mixNode, 0, outNode, 0);
	AU_CHECK();
	
	AudioComponentDescription inDesc;
	AudioComponentGetDescription(_remoteComponent, &inDesc);

	AUGraphAddNode(_graph, &inDesc, &inNode);
	result = AUGraphConnectNodeInput(_graph, inNode, 0, mixNode, 0);
	AU_CHECK();
	
	result = AUGraphOpen(_graph);
	AU_CHECK();
	
	AudioStreamBasicDescription fmt = [IAAGenerator streamDescription];
	
	AUGraphNodeInfo(_graph, inNode, &inDesc, &_remoteAU);
	AU_CHECK();
	result = AudioUnitSetProperty(_remoteAU,
								  kAudioUnitProperty_StreamFormat,
								  kAudioUnitScope_Output,
								  0, &fmt, sizeof(fmt));

	AU_CHECK();
	
	AudioUnit mixUnit = NULL;
	AUGraphNodeInfo(_graph, mixNode, &mixDesc, &mixUnit);
	AU_CHECK();
	result = AudioUnitSetProperty(mixUnit,
								  kAudioUnitProperty_StreamFormat,
								  kAudioUnitScope_Output,
								  0, &fmt, sizeof(fmt));
	result = AudioUnitSetProperty(mixUnit,
								  kAudioUnitProperty_StreamFormat,
								  kAudioUnitScope_Input,
								  0, &fmt, sizeof(fmt));
	AU_CHECK();
	
	// output rendering callback
	AudioUnitAddRenderNotify(mixUnit,recordCallback,(__bridge void*)self);
	
	result = AUGraphInitialize(_graph);
	AU_CHECK();
}

-(void)completeTransfer{
	[self stop];
	[_delegate iaaReceiverDidReceiveData:_recvData];
}

-(void)progressTransfer{
	[_delegate iaaReceiverProgress:_recvDataInfo.procBytes totalBytes:_recvDataInfo.totalBytes];
}

@end

static AudioComponentDescription ACDescMake(OSType type,OSType subtype, OSType mnfc){
	AudioComponentDescription desc;
	memset(&desc, 0, sizeof(AudioComponentDescription));
	desc.componentType = type;
	desc.componentSubType = subtype;
	desc.componentManufacturer = mnfc;
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;
	return desc;
}

static OSStatus recordCallback(void *inRefCon,
							   AudioUnitRenderActionFlags *ioActionFlags,
							   const AudioTimeStamp *inTimeStamp,
							   UInt32 inBusNumber,
							   UInt32 inNumberFrames,
							   AudioBufferList * ioData){
	IAAReceiver *auGraph = (__bridge IAAReceiver*)inRefCon;
	if (*ioActionFlags != kAudioUnitRenderAction_PostRender) { return noErr; }
	if( !ioData  ){ return noErr; }
	uint8_t *ptr = (uint8_t*)ioData->mBuffers[0].mData;
	int recvBytes = inNumberFrames*4;
	
	NSMutableData *dstData = auGraph->_recvData;
	IAAData *dstDataInfo = &auGraph->_recvDataInfo;
	if( dstDataInfo->procBytes == 0 ){
		dstDataInfo->totalBytes = *(uint32_t*)ptr;
		recvBytes -= 4;
		ptr += 4;
	}
	if( (dstDataInfo->procBytes+recvBytes) > dstDataInfo->totalBytes ){
		recvBytes = dstDataInfo->totalBytes-dstDataInfo->procBytes;
	}
	if( recvBytes > 0 ){
		[dstData appendBytes:ptr length:recvBytes];
		dstDataInfo->procBytes += recvBytes;
	}
	memset(ioData->mBuffers[0].mData, 0, inNumberFrames*4);
	
	[auGraph performSelectorOnMainThread:@selector(progressTransfer) withObject:nil waitUntilDone:NO];
	
	if( dstDataInfo->procBytes >= dstDataInfo->totalBytes ){
		[auGraph performSelectorOnMainThread:@selector(completeTransfer) withObject:nil waitUntilDone:NO];
	}
	return noErr;
}

