//
//  CustomCameraViewController.m
//  CustomCamera
//
//  Created by Chris van Es on 24/02/2014.
//
//

#import "CustomCameraViewController.h"

#import <Cordova/CDV.h>
#import <AVFoundation/AVFoundation.h>

@implementation CustomCameraViewController {
    void(^_callback)(UIImage*);
    AVCaptureSession *_captureSession;
    AVCaptureDevice *_rearCamera;
    AVCaptureStillImageOutput *_stillImageOutput;
    UIView *_buttonPanel;
    UIButton *_captureButton;
    UIButton *_backButton;
    UIImageView *_topLeftGuide;
    UIImageView *_topRightGuide;
    UIImageView *_bottomLeftGuide;
    UIImageView *_bottomRightGuide;
	UILabel * _topTextLabel;
	NSString * _topTextString;
	UILabel * _statusLabel;
    UIActivityIndicatorView *_activityIndicator;
	AVCaptureVideoPreviewLayer *_previewLayer;
}


int camTop;
int camLeft;
int camWidth;
int camHeight;

static const CGFloat kCaptureButtonWidthPhone = 64;
static const CGFloat kCaptureButtonHeightPhone = 64;
static const CGFloat kBackButtonWidthPhone = 50;
static const CGFloat kBackButtonHeightPhone = 50;
static const CGFloat kBorderImageWidthPhone = 50;
static const CGFloat kBorderImageHeightPhone = 50;
static const CGFloat kHorizontalInsetPhone = 5;
static const CGFloat kVerticalInsetPhone = 50;
static const CGFloat kCaptureButtonVerticalInsetPhone = 5;

static const CGFloat kCaptureButtonWidthTablet = 75;
static const CGFloat kCaptureButtonHeightTablet = 75;
static const CGFloat kBackButtonWidthTablet = 50;
static const CGFloat kBackButtonHeightTablet = 50;
static const CGFloat kBorderImageWidthTablet = 50;
static const CGFloat kBorderImageHeightTablet = 50;
static const CGFloat kHorizontalInsetTablet = 100;
static const CGFloat kVerticalInsetTablet = 50;
static const CGFloat kCaptureButtonVerticalInsetTablet = 10;

static const CGFloat kAspectRatio = 125.0f / 86;

- (id)initWithCallback:(void(^)(UIImage*))callback {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _callback = callback;
	_captureSession = [[AVCaptureSession alloc] init];
        _captureSession.sessionPreset = AVCaptureSessionPresetPhoto;
    }
    return self;
}

- (void)dealloc {
    [_captureSession stopRunning];
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.view.backgroundColor = [UIColor blackColor];
        
	 //if ([AVCaptureDevice respondsToSelector:@selector(authorizationStatusForMediaType:)]) {
            AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
            if (authStatus == AVAuthorizationStatusDenied ||
                authStatus == AVAuthorizationStatusRestricted) {
                // If iOS 8+, offer a link to the Settings app
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-pointer-compare"
                NSString* settingsButton = (&UIApplicationOpenSettingsURLString != NULL)
                    ? NSLocalizedString(@"Settings", nil)
                    : nil;
#pragma clang diagnostic pop

                // Denied; show an alert
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[[UIAlertView alloc] initWithTitle:[[NSBundle mainBundle]
                                                         objectForInfoDictionaryKey:@"CFBundleDisplayName"]
                                                message:NSLocalizedString(@"Access to the camera has been prohibited; please enable it in the Settings app to continue.", nil)
                                               delegate:nil
                                      cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                      otherButtonTitles:settingsButton, nil] show];
                });
            }
        //}

	int width = self.view.bounds.size.width;
	int height =  self.view.bounds.size.height;
	camHeight = height * .9;
	camWidth = (width * camHeight)/height;
	camLeft = (width - camWidth) / 2;
	camTop = (height - camHeight) / 2;
    
    //AVCaptureVideoPreviewLayer *previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_captureSession];
	_previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_captureSession];
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    //previewLayer.frame = self.view.bounds;
	_previewLayer.frame = CGRectMake(camLeft, camTop, camWidth, camHeight);

    [[self.view layer] addSublayer:_previewLayer];
    
    [self.view addSubview:[self createOverlay]];
    _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _activityIndicator.center = self.view.center;
    [self.view addSubview:_activityIndicator];
    [_activityIndicator startAnimating];
}

- (UIView*)createOverlay {
    UIView *overlay = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  
	_buttonPanel = [[UIView alloc] initWithFrame:CGRectZero];
    [_buttonPanel setBackgroundColor:[UIColor colorWithWhite:0 alpha:0.75f]];
    //[overlay addSubview:_buttonPanel];

    
    _captureButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_captureButton setImage:[UIImage imageNamed:@"www/img2/cameraoverlay/capture_button.png"] forState:UIControlStateNormal];
    [_captureButton setImage:[UIImage imageNamed:@"www/img2/cameraoverlay/capture_button_pressed.png"] forState:UIControlStateSelected];
    [_captureButton setImage:[UIImage imageNamed:@"www/img2/cameraoverlay/capture_button_pressed.png"] forState:UIControlStateHighlighted];
    [_captureButton addTarget:self action:@selector(takePictureWaitingForCameraToFocus) forControlEvents:UIControlEventTouchUpInside];
    [overlay addSubview:_captureButton];
    
    _backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_backButton setBackgroundImage:[UIImage imageNamed:@"www/img2/cameraoverlay/back_button.png"] forState:UIControlStateNormal];
    [_backButton setBackgroundImage:[UIImage imageNamed:@"www/img2/cameraoverlay/back_button_pressed.png"] forState:UIControlStateHighlighted];
    //[_backButton setTitle:@"Cancel" forState:UIControlStateNormal];
    //[_backButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    //[[_backButton titleLabel] setFont:[UIFont systemFontOfSize:18]];
    [_backButton addTarget:self action:@selector(dismissCameraPreview) forControlEvents:UIControlEventTouchUpInside];
    [overlay addSubview:_backButton];
    
    _topLeftGuide = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"www/img2/cameraoverlay/border_top_left.png"]];
    [overlay addSubview:_topLeftGuide];
    
    _topRightGuide = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"www/img2/cameraoverlay/border_top_right.png"]];
    [overlay addSubview:_topRightGuide];
    
    
	/*
	_bottomLeftGuide = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"www/img2/cameraoverlay/border_bottom_left.png"]];
    [overlay addSubview:_bottomLeftGuide];
    
    _bottomRightGuide = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"www/img2/cameraoverlay/border_bottom_right.png"]];
    [overlay addSubview:_bottomRightGuide];
	*/

	_topTextLabel = [[UILabel alloc] init];
	[overlay addSubview:_topTextLabel];

	_statusLabel = [[UILabel alloc] init];
	[overlay addSubview:_statusLabel];

    return overlay;
}

- (void)setTopText:(NSString *)s {
   _topTextString = [[NSString alloc] initWithFormat:@"%@", s];
}

- (void)viewWillLayoutSubviews {
	[self layoutForPhone];
    /*if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self layoutForTablet];
    } else {
        [self layoutForPhone];
    }*/
}

- (void)layoutForPhone {
    CGRect bounds = [[UIScreen mainScreen] bounds];
    
	UIFont* font = [UIFont fontWithName:@"Arial" size:18];
	UIColor *color = [UIColor whiteColor];
	[_topTextLabel setFrame: CGRectMake(0, 0, bounds.size.width, camTop - 2)];
	[_topTextLabel setText: _topTextString];
	[_topTextLabel setFont: font];
	[_topTextLabel setBackgroundColor: [UIColor clearColor]];
	[_topTextLabel setTextColor:color];
	[_topTextLabel setTextAlignment:NSTextAlignmentCenter];

	
	//[_statusLabel setFrame: CGRectMake((bounds.size.width / 2) + kCaptureButtonWidthPhone, bounds.size.height - kCaptureButtonHeightPhone - kCaptureButtonVerticalInsetPhone, bounds.size.width/4, kVerticalInsetPhone - 10)];
	[_statusLabel setFrame: CGRectMake(camWidth + camLeft - 200, camTop + camHeight + 1, 200, 40)];
	[_statusLabel setFont: font];
	[_statusLabel setText: @"Ready"];
	[_statusLabel setBackgroundColor: [UIColor clearColor]];
	[_statusLabel setTextColor:color];
	[_statusLabel setTextAlignment:NSTextAlignmentRight];

	_captureButton.frame = CGRectMake((bounds.size.width / 2) - (kCaptureButtonWidthPhone / 2),
										//camTop + camHeight + camTop - kCaptureButtonHeightPhone,
															bounds.size.height - kCaptureButtonHeightPhone,

										kCaptureButtonWidthPhone,
                                      kCaptureButtonHeightPhone);

	_backButton.frame = CGRectMake(camLeft,
										//camTop + camHeight + camTop - kCaptureButtonHeightPhone,
										bounds.size.height - kCaptureButtonHeightPhone,

										kCaptureButtonWidthPhone,
                                      kCaptureButtonHeightPhone);

	_topLeftGuide.frame = CGRectMake(camLeft,
                                     camTop,
                                     kBorderImageWidthPhone,
                                     kBorderImageHeightPhone);
    
    _topRightGuide.frame = CGRectMake(camLeft + camWidth - kBorderImageWidthPhone,
                                      camTop,
                                      kBorderImageWidthPhone,
                                      kBorderImageHeightPhone);
	/*
	_bottomLeftGuide.frame = CGRectMake(camLeft,
                                        camTop + camHeight - kBorderImageHeightPhone,
                                        kBorderImageWidthPhone,
                                        kBorderImageHeightPhone);
    
    _bottomRightGuide.frame = CGRectMake(camLeft + camWidth - kBorderImageWidthPhone,
                                         camTop + camHeight - kBorderImageHeightPhone,
                                         kBorderImageWidthPhone,
                                         kBorderImageHeightPhone);
	*/

	/*
    _captureButton.frame = CGRectMake((bounds.size.width / 2) - (kCaptureButtonWidthPhone / 2),
                                      bounds.size.height - kCaptureButtonHeightPhone - kCaptureButtonVerticalInsetPhone,
                                      kCaptureButtonWidthPhone,
                                      kCaptureButtonHeightPhone);
	*/
    
    //_backButton.frame = CGRectMake((CGRectGetMinX(_captureButton.frame) - kBackButtonWidthPhone) / 2,
	/*
	_backButton.frame = CGRectMake(5,
                                   CGRectGetMinY(_captureButton.frame) + ((kCaptureButtonHeightPhone - kBackButtonHeightPhone) / 2),
                                   kBackButtonWidthPhone,
                                   kBackButtonHeightPhone);
	
    
    _buttonPanel.frame = CGRectMake(0,
                                    CGRectGetMinY(_captureButton.frame) - kCaptureButtonVerticalInsetPhone,
                                    bounds.size.width,
                                    kCaptureButtonHeightPhone + (kCaptureButtonVerticalInsetPhone * 2));
    
	
    CGFloat screenAspectRatio = bounds.size.height / bounds.size.width;
    if (screenAspectRatio <= 1.5f) {
        [self layoutForPhoneWithShortScreen];
    } else {
        [self layoutForPhoneWithTallScreen];
    }*/
}

- (void)layoutForPhoneWithShortScreen {
    CGRect bounds = [[UIScreen mainScreen] bounds];
    CGFloat verticalInset = 5;
    CGFloat height = CGRectGetMinY(_buttonPanel.frame) - (verticalInset * 2);
    CGFloat width = height / kAspectRatio;
    CGFloat horizontalInset = (bounds.size.width - width) / 2;
    

	UIFont* font = [UIFont fontWithName:@"Arial" size:18];
	[_topTextLabel setFrame: CGRectMake(0, 0, bounds.size.width, kVerticalInsetPhone - 10)];
	[_topTextLabel setText: _topTextString];
	[_topTextLabel setFont: font];
	[_topTextLabel setBackgroundColor: [UIColor clearColor]];
	UIColor *color = [UIColor whiteColor];
	[_topTextLabel setTextColor:color];
	[_topTextLabel setTextAlignment:NSTextAlignmentCenter];

	
	[_statusLabel setFrame: CGRectMake((bounds.size.width / 2) + kCaptureButtonWidthPhone, bounds.size.height - kCaptureButtonHeightPhone - kCaptureButtonVerticalInsetPhone, bounds.size.width/4, kVerticalInsetPhone - 10)];
	[_statusLabel setText: @"Ready"];
	[_statusLabel setFont: font];
	[_statusLabel setBackgroundColor: [UIColor clearColor]];
	[_statusLabel setTextColor:color];
	[_statusLabel setTextAlignment:NSTextAlignmentCenter];
    
    _topLeftGuide.frame = CGRectMake(horizontalInset,
                                     verticalInset,
                                     kBorderImageWidthPhone,
                                     kBorderImageHeightPhone);
    
    _topRightGuide.frame = CGRectMake(bounds.size.width - kBorderImageWidthPhone - horizontalInset,
                                      verticalInset,
                                      kBorderImageWidthPhone,
                                      kBorderImageHeightPhone);
    
	/*
    _bottomLeftGuide.frame = CGRectMake(CGRectGetMinX(_topLeftGuide.frame),
                                        CGRectGetMinY(_topLeftGuide.frame) + height - kBorderImageHeightPhone,
                                        kBorderImageWidthPhone,
                                        kBorderImageHeightPhone);
    
    _bottomRightGuide.frame = CGRectMake(CGRectGetMinX(_topRightGuide.frame),
                                         CGRectGetMinY(_topRightGuide.frame) + height - kBorderImageHeightPhone,
                                         kBorderImageWidthPhone,
                                         kBorderImageHeightPhone);
										 */
}

- (void)layoutForPhoneWithTallScreen {

    CGRect bounds = [[UIScreen mainScreen] bounds];

	UIFont* font = [UIFont fontWithName:@"Arial" size:18];
	[_topTextLabel setFrame: CGRectMake(0, 0, bounds.size.width, kVerticalInsetPhone - 10)];
	[_topTextLabel setText: _topTextString];
	[_topTextLabel setFont: font];
	[_topTextLabel setBackgroundColor: [UIColor clearColor]];
	UIColor *color = [UIColor whiteColor];
	[_topTextLabel setTextColor:color];
	[_topTextLabel setTextAlignment:NSTextAlignmentCenter];

	
	[_statusLabel setFrame: CGRectMake((bounds.size.width / 2) + kCaptureButtonWidthPhone, bounds.size.height - kCaptureButtonHeightPhone - kCaptureButtonVerticalInsetPhone, bounds.size.width/4, kVerticalInsetPhone - 10)];
	[_statusLabel setText: @"Ready"];
	[_statusLabel setFont: font];
	[_statusLabel setBackgroundColor: [UIColor clearColor]];
	[_statusLabel setTextColor:color];
	[_statusLabel setTextAlignment:NSTextAlignmentCenter];

    _topLeftGuide.frame = CGRectMake(kHorizontalInsetPhone, kVerticalInsetPhone, kBorderImageWidthPhone, kBorderImageHeightPhone);
    
    _topRightGuide.frame = CGRectMake(bounds.size.width - kBorderImageWidthPhone - kHorizontalInsetPhone,
                                      kVerticalInsetPhone,
                                      kBorderImageWidthPhone,
                                      kBorderImageHeightPhone);
    
    CGFloat height = (CGRectGetMaxX(_topRightGuide.frame) - CGRectGetMinX(_topLeftGuide.frame)) * kAspectRatio;
    
	/*
    _bottomLeftGuide.frame = CGRectMake(CGRectGetMinX(_topLeftGuide.frame),
                                        CGRectGetMinY(_topLeftGuide.frame) + height - kBorderImageHeightPhone,
                                        kBorderImageWidthPhone,
                                        kBorderImageHeightPhone);
    
    _bottomRightGuide.frame = CGRectMake(CGRectGetMinX(_topRightGuide.frame),
                                         CGRectGetMinY(_topRightGuide.frame) + height - kBorderImageHeightPhone,
                                         kBorderImageWidthPhone,
                                         kBorderImageHeightPhone);
										 */
}

- (void)layoutForTablet {
    CGRect bounds = [[UIScreen mainScreen] bounds];
    
	UIFont* font = [UIFont fontWithName:@"Arial" size:18];
	UIColor *color = [UIColor whiteColor];
	[_statusLabel setFrame: CGRectMake((bounds.size.width / 2) + kCaptureButtonWidthPhone, bounds.size.height - kCaptureButtonHeightPhone - kCaptureButtonVerticalInsetPhone, bounds.size.width/4, kVerticalInsetPhone - 10)];
	[_statusLabel setText: @"Ready"];
	[_statusLabel setFont: font];
	[_statusLabel setBackgroundColor: [UIColor clearColor]];
	[_statusLabel setTextColor:color];
	[_statusLabel setTextAlignment:NSTextAlignmentCenter];

    _captureButton.frame = CGRectMake((bounds.size.width / 2) - (kCaptureButtonWidthTablet / 2),
                                      bounds.size.height - kCaptureButtonHeightTablet - kCaptureButtonVerticalInsetTablet,
                                      kCaptureButtonWidthTablet,
                                      kCaptureButtonHeightTablet);
    
    //_backButton.frame = CGRectMake((CGRectGetMinX(_captureButton.frame) - kBackButtonWidthTablet) / 2,
	_backButton.frame = CGRectMake(5,
                                   CGRectGetMinY(_captureButton.frame) + ((kCaptureButtonHeightTablet - kBackButtonHeightTablet) / 2),
                                   kBackButtonWidthTablet,
                                   kBackButtonHeightTablet);
    
    _buttonPanel.frame = CGRectMake(0,
                                    CGRectGetMinY(_captureButton.frame) - kCaptureButtonVerticalInsetTablet,
                                    bounds.size.width,
                                    kCaptureButtonHeightTablet + (kCaptureButtonVerticalInsetTablet * 2));
    
	
	[_topTextLabel setFrame: CGRectMake(0, 0, bounds.size.width, kVerticalInsetTablet - 10)];
	[_topTextLabel setText: _topTextString];
	[_topTextLabel setFont: font];
	[_topTextLabel setBackgroundColor: [UIColor clearColor]];
	[_topTextLabel setTextColor:color];
	[_topTextLabel setTextAlignment:NSTextAlignmentCenter];
	


    _topLeftGuide.frame = CGRectMake(kHorizontalInsetTablet, kVerticalInsetTablet, kBorderImageWidthTablet, kBorderImageHeightTablet);
    
    _topRightGuide.frame = CGRectMake(bounds.size.width - kBorderImageWidthTablet - kHorizontalInsetTablet,
                                      kVerticalInsetTablet,
                                      kBorderImageWidthTablet,
                                      kBorderImageHeightTablet);
    
    CGFloat height = (CGRectGetMaxX(_topRightGuide.frame) - CGRectGetMinX(_topLeftGuide.frame)) * kAspectRatio;
    /*
    _bottomLeftGuide.frame = CGRectMake(CGRectGetMinX(_topLeftGuide.frame),
                                        CGRectGetMinY(_topLeftGuide.frame) + height - kBorderImageHeightTablet,
                                        kBorderImageWidthTablet,
                                        kBorderImageHeightTablet);
    
    _bottomRightGuide.frame = CGRectMake(CGRectGetMinX(_topRightGuide.frame),
                                         CGRectGetMinY(_topRightGuide.frame) + height - kBorderImageHeightTablet,
                                         kBorderImageWidthTablet,
                                         kBorderImageHeightTablet);
										 */
}

- (void)viewDidLoad {
	
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
     if(1 == 1){
        for (AVCaptureDevice *device in [AVCaptureDevice devices]) {
            if ([device hasMediaType:AVMediaTypeVideo] && [device position] == AVCaptureDevicePositionBack) {
                _rearCamera = device;
            }
        }
        if(_rearCamera != nil){
		    
         AVCaptureDeviceInput *cameraInput = [AVCaptureDeviceInput deviceInputWithDevice:_rearCamera error:nil];
         [_captureSession addInput:cameraInput];
         _stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
	
         [_captureSession addOutput:_stillImageOutput];
         [_captureSession startRunning];
        }
     }
        dispatch_async(dispatch_get_main_queue(), ^{
            [_activityIndicator stopAnimating];
        });
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setNeedsStatusBarAppearanceUpdate];
    //[[UIApplication sharedApplication] setStatusBarHidden:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    //[[UIApplication sharedApplication] setStatusBarHidden:NO];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    return orientation == UIDeviceOrientationPortrait;
}

- (void)dismissCameraPreview {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)takePictureWaitingForCameraToFocus {
    _captureButton.userInteractionEnabled = NO;
    _captureButton.selected = YES;
	[self takePicture];
	//[_statusLabel setText: @"Taking Picture..."];
	return;
    if (_rearCamera.focusPointOfInterestSupported && [_rearCamera isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        [_rearCamera addObserver:self forKeyPath:@"adjustingFocus" options:(NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew) context:nil];
		[_statusLabel setText: @"Focusing..."];
        [self autoFocus];
        [self autoExpose];
    } else {
        [self takePicture];
    }
}

- (void)autoFocus {
    [_rearCamera lockForConfiguration:nil];
    _rearCamera.focusMode = AVCaptureFocusModeAutoFocus;
    _rearCamera.focusPointOfInterest = CGPointMake(0.5, 0.5);
    [_rearCamera unlockForConfiguration];
}

- (void)autoExpose {
    [_rearCamera lockForConfiguration:nil];
    if (_rearCamera.exposurePointOfInterestSupported && [_rearCamera isExposureModeSupported:AVCaptureExposureModeAutoExpose]) {
		[_statusLabel setText: @"Focusing..."];
        _rearCamera.exposureMode = AVCaptureExposureModeAutoExpose;
        _rearCamera.exposurePointOfInterest = CGPointMake(0.5, 0.5);
    }
    [_rearCamera unlockForConfiguration];
}

- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
    BOOL wasAdjustingFocus = [[change valueForKey:NSKeyValueChangeOldKey] boolValue];
    BOOL isNowFocused = ![[change valueForKey:NSKeyValueChangeNewKey] boolValue];
    if (wasAdjustingFocus && isNowFocused) {
        [_rearCamera removeObserver:self forKeyPath:@"adjustingFocus"];
		[_statusLabel setText: @"Focusing..."];
        [self takePicture];
    }
}

- (void)takePicture {
	[_statusLabel setText: @"Taking Picture..."];
    AVCaptureConnection *videoConnection = [self videoConnectionToOutput:_stillImageOutput];
    [_stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler:^(CMSampleBufferRef imageSampleBuffer, NSError *error) {
        NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
		[[_previewLayer connection] setEnabled:NO];
		[_statusLabel setText: @"Processing..."];
        _callback([UIImage imageWithData:imageData]);
		
    }];
}

- (AVCaptureConnection*)videoConnectionToOutput:(AVCaptureOutput*)output {
    for (AVCaptureConnection *connection in output.connections) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
                return connection;
            }
        }
    }
    return nil;
}

@end
