//
//  IAAudio.h
//  InterAppDataEx
//
//  Created by hayashi on 10/8/13.
//  Copyright (c) 2013 Qoncept. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioUnit/AudioUnit.h>

@interface IAAGenerator : NSObject
+(NSString*)iaaName;
+(AudioComponentDescription)iaaDescription;
+(AudioComponent)findComponent;
+(AudioStreamBasicDescription)streamDescription;
-(id)initWithData:(NSData*)data;
@end

