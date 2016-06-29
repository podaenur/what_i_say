//
//  EVASpeechManager.h
//  objC_iOS10_review
//
//  Created by Evgeniy Akhmerov on 29/06/16.
//  Copyright © 2016 Evgeniy Akhmerov. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol EVASpeechManagerDelegate;


@interface EVASpeechManager : NSObject

@property (weak) id<EVASpeechManagerDelegate> delegate;

+ (instancetype)sharedManager;

- (void)startRecognizeWithSuccess:(void(^)(BOOL success))success;
- (void)stopRecognize;

@end


@protocol EVASpeechManagerDelegate <NSObject>

- (void)manager:(EVASpeechManager *)manager didRecognizeText:(NSString *)text;

@optional
- (void)manager:(EVASpeechManager *)manager didFailWithError:(NSError *)error;

@end
