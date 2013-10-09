#import <Foundation/Foundation.h>
#import <AudioUnit/AudioUnit.h>

@protocol IAAReceiverDelegate<NSObject>
-(void)iaaReceiverDidReceiveData:(NSData*)data;
-(void)iaaReceiverProgress:(uint32_t)recvBytes totalBytes:(uint32_t)totalBytes;
@end

@interface IAAReceiver : NSObject
@property (weak) id<IAAReceiverDelegate> delegate;
-(UIImage*)remoteAudioAppIcon;
-(NSURL*)remoteAudioAppURL;
-(void)start;
-(void)stop;
@end
