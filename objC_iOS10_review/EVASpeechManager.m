//
//  EVASpeechManager.m
//  objC_iOS10_review
//
//  Created by Evgeniy Akhmerov on 29/06/16.
//  Copyright © 2016 Evgeniy Akhmerov. All rights reserved.
//

#define SHOW_ME printf("%s\n", __PRETTY_FUNCTION__);
#define P_ERROR(err) printf("Error: %s", [err.localizedDescription cStringUsingEncoding:NSUTF8StringEncoding]);

@import Speech;
@import AVFoundation;

#import "EVASpeechManager.h"

typedef NS_ENUM(NSUInteger, EVASpeechManagerError) {
  EVASpeechManagerErrorUnsupportedLocale,
  EVASpeechManagerErrorSpeechRecognitionDenied,
  EVASpeechManagerErrorManagerIsBusy,
};

static NSString *const EVASpeechManagerRequestIdentifier = @"com.zhurov.EVASpeechManagerRequestIdentifier";
static NSUInteger const bus = 0;

@interface EVASpeechManager () <SFSpeechRecognitionTaskDelegate>

@property SFSpeechRecognizer *recognizer;
@property AVAudioEngine *audioEngine;
@property (nonatomic) SFSpeechAudioBufferRecognitionRequest *request;
@property SFSpeechRecognitionTask *currentTask;
@property (copy) NSString *buffer;

@end

@implementation EVASpeechManager

#pragma mark - Life cycle

+ (instancetype)sharedManager {
  static EVASpeechManager *manager = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    manager = [[self alloc] init];
  });
  return manager;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    [self requestAuthorization];
    [self setup];
  }
  return self;
}

#pragma mark - Custom Accessors
#pragma mark - Actions
#pragma mark - Public

- (void)startRecognizeWithSuccess:(void(^)(BOOL success))success {
  BOOL isRunning = [self isTaskInProgress];
  (isRunning) ? [self informDelegateErrorType:EVASpeechManagerErrorManagerIsBusy] : [self performRecognize];
  
  if (success != nil) {
    success(!isRunning);
  }
}

- (void)stopRecognize {
  if ([self isTaskInProgress]) {
    [self.currentTask finish];
    [self.audioEngine stop];
  }
}

#pragma mark - Private

- (void)setup {
  _recognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale currentLocale]];
  if (!_recognizer) {
    [self informDelegateErrorType:(EVASpeechManagerErrorUnsupportedLocale)];
  } else {
    _recognizer.defaultTaskHint = SFSpeechRecognitionTaskHintDictation;
    
    self.request = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
    self.request.interactionIdentifier = EVASpeechManagerRequestIdentifier;
    
    self.audioEngine = [[AVAudioEngine alloc] init];
    AVAudioInputNode *node = self.audioEngine.inputNode;
    AVAudioFormat *recordingFormat = [node outputFormatForBus:bus];
    __weak typeof(self) weakSelf = self;
    [node installTapOnBus:bus
               bufferSize:1024
                   format:recordingFormat
                    block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
                      __strong typeof(weakSelf) strongSelf = weakSelf;
                      [strongSelf.request appendAudioPCMBuffer:buffer];
                    }];
  }
}

- (void)handleAuthorizationStatus:(SFSpeechRecognizerAuthorizationStatus)s {
  switch (s) {
    case SFSpeechRecognizerAuthorizationStatusNotDetermined:
      [self requestAuthorization];
      break;
    case SFSpeechRecognizerAuthorizationStatusDenied:
      [self informDelegateErrorType:(EVASpeechManagerErrorSpeechRecognitionDenied)];
      break;
    case SFSpeechRecognizerAuthorizationStatusRestricted:
      // TODO: неизведанное состояние. исследовать позже
      break;
    case SFSpeechRecognizerAuthorizationStatusAuthorized: {
      //  do nothing
    }
      break;
  }
}

- (void)requestAuthorization {
  __weak typeof(self) weakSelf = self;
  [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
    __strong typeof(weakSelf) strongSelf = weakSelf;
    [strongSelf handleAuthorizationStatus:status];
  }];
}

- (void)performRecognize {
  [self.audioEngine prepare];
  NSError *error = nil;
  if ([self.audioEngine startAndReturnError:&error]) {
    self.currentTask = [self.recognizer recognitionTaskWithRequest:self.request
                                                          delegate:self];
  } else {
    [self informDelegateError:error];
  }
}

- (BOOL)isTaskInProgress {
  return (self.currentTask.state == SFSpeechRecognitionTaskStateRunning);
}

- (NSError *)errorWithCode:(NSInteger)code description:(NSString *)description {
  return [NSError errorWithDomain:NSStringFromClass([self class]) code:code userInfo:@{ NSLocalizedDescriptionKey: description }];
}

- (NSError *)errorByType:(EVASpeechManagerError)errorType {
  switch (errorType) {
    case EVASpeechManagerErrorUnsupportedLocale:
      return [self errorWithCode:-999 description:@"Current locale is not supported"];
    case EVASpeechManagerErrorSpeechRecognitionDenied:
      return [self errorWithCode:100 description:@"Speech recognition denied by user"];
    case EVASpeechManagerErrorManagerIsBusy:
      return [self errorWithCode:500 description:@"Manager in recognizing progress now"];
  }
}

- (void)informDelegateError:(NSError *)error {
  if ([self.delegate respondsToSelector:@selector(manager:didFailWithError:)]) {
    [self.delegate manager:self didFailWithError:error];
  }
}

- (void)informDelegateErrorType:(EVASpeechManagerError)errorType {
  [self informDelegateError:[self errorByType:errorType]];
}

#pragma mark - Segue
#pragma mark - Animations

#pragma mark - Protocol conformance

#pragma mark SFSpeechRecognitionTaskDelegate

- (void)speechRecognitionTask:(SFSpeechRecognitionTask *)task didFinishRecognition:(SFSpeechRecognitionResult *)recognitionResult {
  self.buffer = recognitionResult.bestTranscription.formattedString;
}

- (void)speechRecognitionTask:(SFSpeechRecognitionTask *)task didFinishSuccessfully:(BOOL)successfully {
  if (!successfully) {
    //  Error: SessionId=com.siri.cortex.ace.speech.session.event.SpeechSessionId@439e90ed, Message=Timeout waiting for command after 30000 ms
    //  Error: SessionId=com.siri.cortex.ace.speech.session.event.SpeechSessionId@714a717a, Message=Empty recognition
    [self informDelegateError:task.error];
  } else {
    [self.delegate manager:self didRecognizeText:[self.buffer copy]];
  }
}

#pragma mark - Notifications handlers
#pragma mark - Gestures handlers
#pragma mark - KVO
#pragma mark - NSCopying
#pragma mark - NSObject

@end
