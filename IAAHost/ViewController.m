//
//  ViewController.m
//  IAAHost
//
//  Created by hayashi on 10/8/13.
//  Copyright (c) 2013 Qoncept. All rights reserved.
//

#import "ViewController.h"
#import "IAAReceiver.h"

#define GENERATOR_NAME @"IAADataEx"

@interface ViewController () <IAAReceiverDelegate>{
	IAAReceiver *_receiver;
	IBOutlet UIButton *_iaaAppButton;
	IBOutlet UIImageView *_recvImage;
	IBOutlet UIProgressView *_progressView;
}
@end

@implementation ViewController

- (void)viewDidLoad{
	[super viewDidLoad];
	[[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(appDidEnterBackground)
                                                 name: UIApplicationDidEnterBackgroundNotification
                                               object: nil];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(appWillEnterForeground)
                                                 name: UIApplicationWillEnterForegroundNotification
                                               object: nil];
	[self start];
}

-(void)start{
	_progressView.progress = 0.f;
	_recvImage.image = nil;
	_receiver = [[IAAReceiver alloc] init];
	_receiver.delegate = self;
	[_iaaAppButton setImage:[_receiver remoteAudioAppIcon] forState:UIControlStateNormal];
	[_iaaAppButton setTitle:@"" forState:UIControlStateNormal];
	[_receiver start];
}

-(void)stop{
	[_receiver stop];
	_receiver = nil;
}

-(void)appWillEnterForeground{
	[self start];
}

-(void)appDidEnterBackground{
	[self stop];
}

-(void)iaaReceiverDidReceiveData:(NSData *)data{
	if( data ){
		_recvImage.image = [UIImage imageWithData:data];
	}
}

-(void)iaaReceiverProgress:(uint32_t)recvBytes totalBytes:(uint32_t)totalBytes{
	if( totalBytes > 0 ){
		_progressView.progress = (float)recvBytes/totalBytes;
	}
}

-(IBAction)iaaButtonDidTouch:(id)sender{
	NSURL *appURL = [_receiver remoteAudioAppURL];
	if( appURL ){
		[[UIApplication sharedApplication] openURL:appURL];
	}
}

@end
