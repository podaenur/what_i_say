//
//  EVARootViewController.m
//  objC_iOS10_review
//
//  Created by Evgeniy Akhmerov on 29/06/16.
//  Copyright © 2016 Evgeniy Akhmerov. All rights reserved.
//

#import "EVARootViewController.h"
#import "EVASpeechManager.h"

double const EVARootViewControllerSecondsDurationMax = 60.f;
double const EVARootViewControllerTimeIntervalStep = 1.f;

@interface EVARootViewController () <EVASpeechManagerDelegate>
//  UI
@property (weak, nonatomic) IBOutlet UILabel *topText;
@property (weak, nonatomic) IBOutlet UIProgressView *timeProgress;
@property (weak, nonatomic) IBOutlet UIButton *actionButton;
@property (weak, nonatomic) IBOutlet UILabel *textInfo;
@property (weak, nonatomic) IBOutlet UITextView *textContainer;
//  Logic
@property NSTimer *countDown;
@property double timeLeft;

@end

@implementation EVARootViewController

#pragma mark - Life cycle

- (void)viewDidLoad {
  [super viewDidLoad];
  
  [EVASpeechManager sharedManager].delegate = self;
  
  [self setContainedText:nil];
  [self setInitialState];
}

#pragma mark - Custom Accessors

#pragma mark - Actions

- (IBAction)onActionPressed:(UIButton *)sender {
  sender.isSelected ? [self cancelProccess] : [self startProccess];
}

#pragma mark - Public

#pragma mark - Private

- (void)setInitialState {
  [self.countDown invalidate];
  dispatch_async(dispatch_get_main_queue(), ^{
    self.timeProgress.progress = 0.f;
    self.actionButton.selected = NO;
    [self changeTopTextToInprogress:NO];
  });
}

- (void)setContainedText:(NSString *)aText {
  self.textContainer.text = aText;
  self.textInfo.hidden = ![self.textContainer hasText];
}

- (void)handleCountDownValueChange {
  self.timeLeft += EVARootViewControllerTimeIntervalStep;
  dispatch_async(dispatch_get_main_queue(), ^{
    self.timeProgress.progress = (self.timeLeft / EVARootViewControllerSecondsDurationMax);
  });
  
  if (self.timeLeft >= EVARootViewControllerSecondsDurationMax) {
    [self cancelProccess];
  }
}

- (void)showErrorWithText:(NSString *)errorText {
  dispatch_async(dispatch_get_main_queue(), ^{
    self.topText.text = errorText;
    self.timeProgress.hidden = YES;
    self.actionButton.hidden = YES;
    self.textInfo.hidden = YES;
    self.textContainer.hidden = YES;
  });
}

- (void)changeTopTextToInprogress:(BOOL)inProgress {
  self.topText.text = (inProgress) ? @"Speak" : @"Recognition control";
}

- (void)startProccess {
  self.actionButton.selected = YES;
  
  [[EVASpeechManager sharedManager] startRecognizeWithSuccess:^(BOOL success) {
    if (!success) {
      return;
    }
    
    self.timeLeft = 0.f;
    self.countDown = [NSTimer scheduledTimerWithTimeInterval:EVARootViewControllerTimeIntervalStep
                                                      target:self
                                                    selector:@selector(handleCountDownValueChange)
                                                    userInfo:nil
                                                     repeats:YES];
    dispatch_async(dispatch_get_main_queue(), ^{
      [self changeTopTextToInprogress:YES];
    });
  }];
}

- (void)cancelProccess {
  [[EVASpeechManager sharedManager] stopRecognize];
  
  [self setInitialState];
}

#pragma mark - Segue
#pragma mark - Animations

#pragma mark - Protocol conformance
#pragma mark EVASpeechManagerDelegate

- (void)manager:(EVASpeechManager *)manager didRecognizeText:(NSString *)text {
  [self setContainedText:text];
}

- (void)manager:(EVASpeechManager *)manager didFailWithError:(NSError *)error {
  [self cancelProccess];
  [self showErrorWithText:error.localizedDescription];
}

#pragma mark - Notifications handlers
#pragma mark - Gestures handlers
#pragma mark - KVO
#pragma mark - NSCopying
#pragma mark - NSObject

@end
