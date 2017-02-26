//
//  JHPhotoVideoRecordVC.m
//  JHPhotoVIdeoRecord
//
//  Created by gjh on 17/2/24.
//  Copyright © 2017年 gjh. All rights reserved.
//

#import "JHPhotoVideoRecordVC.h"
#import "GPUImage.h"
#import <CoreMotion/CoreMotion.h>

#define kMARGap 20.0
#define kMARSwitchW 30
#define kLimitRecLen 10.7f
#define kCameraWidth 540.0f
#define kCameraHeight 960.0f
#define kRecordW 87

#define kRecordCenter CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height - 70)

#define kFaceUColor [UIColor colorWithRed:66 / 255.0 green:222 / 255.0 blue:182 / 255.0 alpha:1]

#define kScaleKey @"scale_layer"

#define kWeakSelf __weak typeof(self) weakSelf = self;

#define RMDefaultVideoPath [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Movie.MP4"]
#define RMDefaultImagePath [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Image.PNG"]

/* 屏幕大小 */
#define LZ_SCREEN_WIDTH  [[UIScreen mainScreen] bounds].size.width
#define LZ_SCREEN_HEIGHT [[UIScreen mainScreen] bounds].size.height

@interface JHPhotoVideoRecordVC () <CAAnimationDelegate> {
    CGFloat _allTime;
    UIImage *_tempImg;
    AVPlayerLayer *_avplayer;
}
//******** UIKit Property *************
@property (nonatomic, strong) UISlider *sliderView;
@property (nonatomic, strong) UIButton *flashSwitch;
@property (nonatomic, strong) UIButton *filterSwitch;
@property (nonatomic, strong) UIButton *cameraSwitch;
@property (nonatomic, strong) UIButton *recordButton;
@property (nonatomic, strong) UIButton *downButton;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIButton *recaptureButton;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) GPUImageView *cameraView;
@property (nonatomic, strong) UIImageView *imageView;

//******** Animation Property **********
@property (nonatomic, strong) CAShapeLayer *cycleLayer;
@property (nonatomic, strong) CAShapeLayer *progressLayer;
@property (nonatomic, strong) CAShapeLayer *ballLayer;
@property (nonatomic, strong) CALayer *focusLayer;
@property (nonatomic, strong) CADisplayLink *timer;
@property (nonatomic, strong) CABasicAnimation *scaleAnimation;

//******** Media Property **************
@property (nonatomic, copy) NSString *moviePath;
@property (nonatomic, strong) NSDictionary *audioSettings;
@property (nonatomic, strong) NSMutableDictionary *videoSettings;

//******** GPUImage Property ***********
@property (nonatomic, strong) GPUImageStillCamera *videoCamera;
@property (nonatomic, strong) GPUImageFilterGroup *normalFilter;
@property (nonatomic, strong) GPUImageMovieWriter *movieWriter;

@property (nonatomic, assign) UIInterfaceOrientation orientationLast; //方向
@property (nonatomic, strong) CMMotionManager *motionManager;
@property (nonatomic, assign) BOOL isCapturing; //是否正在拍摄中
@property (nonatomic, assign) LZVideoRecordOrientation recordOrientation;

@end

@implementation JHPhotoVideoRecordVC

#pragma mark - Life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    _isCapturing = NO;
    
    [self setupUI];
    
    [self setupNotification];
    
    [self performSelector:@selector(hiddenHintLabel) withObject:nil afterDelay:4.0f];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self configInitScreenMode];
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    /* 隐藏状态栏 */
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
    if([self.motionManager isAccelerometerAvailable]){
        [self orientationChange];
    }
}

-(void)viewWillDisappear:(BOOL)animated {
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Private Method

- (void)setupUI {
    
    self.view.backgroundColor = [UIColor blackColor];
    /* 整个拍摄相机 */
    self.cameraView = ({
        GPUImageView *g = [[GPUImageView alloc] init];
        [g.layer addSublayer:self.focusLayer];
        [g addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusTap:)]];
        [g setFillMode:kGPUImageFillModePreserveAspectRatioAndFill];
        [self.view addSubview:g];
        g;
    });
    /* 用于展示拍照后的图片 */
    self.imageView = ({
        UIImageView *i = [[UIImageView alloc] init];
        i.hidden = YES;
        [self.view addSubview:i];
        i;
    });
    /* 闪光灯开关 */
    self.flashSwitch = ({
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        [b setBackgroundImage:[UIImage imageNamed:@"record_light_off"] forState:UIControlStateNormal];
        [b setBackgroundImage:[UIImage imageNamed:@"record_light_on"] forState:UIControlStateSelected];
        [b addTarget:self action:@selector(flashAction:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:b];
        b;
    });
    
    /* 前后摄像头转换开关 */
    self.cameraSwitch = ({
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        [b setBackgroundImage:[UIImage imageNamed:@"video_turn"] forState:UIControlStateNormal];
        [b setBackgroundImage:[UIImage imageNamed:@"video_turn"] forState:UIControlStateSelected];
        [b addTarget:self action:@selector(turnAction:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:b];
        b;
    });
    /* 录制按钮 */
    self.recordButton = ({
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        [b setBackgroundImage:[UIImage imageNamed:@"camera_btn_camera_normal_87x87_"] forState:UIControlStateNormal];
        [b setBackgroundImage:[UIImage imageNamed:@"camera_btn_camera_normal_87x87_"] forState:UIControlStateHighlighted];
        [b addTarget:self action:@selector(beginRecord) forControlEvents:UIControlEventTouchDown];
        [b addTarget:self action:@selector(endRecord) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
        [self.view addSubview:b];
        b;
    });
    /* 提示文字 */
    self.hintLabel = ({
        UILabel *hint = [[UILabel alloc] init];
        hint.textColor = [UIColor whiteColor];
        hint.font = [UIFont systemFontOfSize:16.];
        hint.layer.cornerRadius = 6;
        hint.text = @"轻触拍照，按住摄像";
        hint.textAlignment = NSTextAlignmentCenter;
        [self.view addSubview:hint];
        hint;
    });
    /* 发送按钮 */
    self.downButton = ({
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.alpha = 0.0;
        [b addTarget:self action:@selector(saveAction) forControlEvents:UIControlEventTouchUpInside];
        [b setBackgroundImage:[UIImage imageNamed:@"video_ok"] forState:UIControlStateNormal];
        [self.view addSubview:b];
        b;
    });
    /* 取消按钮 */
    self.recaptureButton = ({
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.alpha = 0.0;
        [b setBackgroundImage:[UIImage imageNamed:@"video_back"] forState:UIControlStateNormal];
        [b addTarget:self action:@selector(recaptureAction) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:b];
        b;
    });
    /* 关闭按钮 */
    self.closeButton = ({
        UIButton *close = [UIButton buttonWithType:UIButtonTypeCustom];
        [close setImage:[UIImage imageNamed:@"close"] forState:UIControlStateNormal];
        close.imageEdgeInsets = UIEdgeInsetsMake(12, 12, 12, 12);
        [close addTarget:self action:@selector(closeButtonAction) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:close];
        close;
    });
    
    self.sliderView = ({
        UISlider *s = [[UISlider alloc] init];
        [s setThumbImage:[UIImage new] forState:UIControlStateNormal];
        s;
    });
    /* 圆环状 */
    self.cycleLayer = ({
        CAShapeLayer *l = [CAShapeLayer layer];
        l.lineWidth = 5.0f;
        UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:kRecordCenter radius:kRecordW / 2 startAngle:0 endAngle:2 * M_PI clockwise:YES];
        l.path = path.CGPath;
        l.fillColor = nil;
        l.strokeColor = [UIColor whiteColor].CGColor;
        l;
    });
    /* 录制视频进度条 */
    self.progressLayer = ({
        CAShapeLayer *l = [CAShapeLayer layer];
        l.lineWidth = 5.0f;
        l.fillColor = nil;
        l.strokeColor = kFaceUColor.CGColor;
        l.lineCap = kCALineCapRound;
        l;
    });
    /* 录制视频中间的绿色圆形 */
    self.ballLayer = ({
        CAShapeLayer *l = [CAShapeLayer layer];
        l.lineWidth = 1.0f;
        l.fillColor = kFaceUColor.CGColor;
        l.strokeColor = kFaceUColor.CGColor;
        l.lineCap = kCALineCapRound;
        l;
    });
    
    switch (_showStyle) {
        case GPUImageShowStyleOnlyPhoto:
            _hintLabel.text = @"请轻触拍照";
            break;
        case GPUImageShowStyleOnlyVideo:
            _hintLabel.text = @"请按住摄像";
            break;
        case GPUImageShowStyleAll:
            _hintLabel.text = @"轻触拍照，按住摄像";
            break;
            
        default:
            break;
    }
    //    [self.flashSwitch setHidden:YES];
    self.filterSwitch.selected = YES;
    self.filterSwitch.hidden = YES;
    
    [self.videoCamera addTarget:self.normalFilter];
    [self.normalFilter addTarget:self.cameraView];
    
    _movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:[NSURL fileURLWithPath:self.moviePath] size:CGSizeMake(kCameraWidth, kCameraWidth) fileType:AVFileTypeQuickTimeMovie outputSettings:self.videoSettings];
    self.videoCamera.audioEncodingTarget = _movieWriter;
    
    [self.videoCamera startCameraCapture];
}

- (void)setupNotification {
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayDidEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}
#pragma mark -- 屏幕的横屏竖屏
- (void)configInitScreenMode {
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    [self configView:orientation];
}

/**
 配置录制过程中的方向
 */
- (void)configVideoOutputOrientation
{
    switch (self.orientationLast) {
        case UIInterfaceOrientationPortrait:
            self.recordOrientation = LZVideoRecordOrientationPortrait;
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            self.recordOrientation = LZVideoRecordOrientationPortraitDown;
            break;
        case UIInterfaceOrientationLandscapeRight:
            self.recordOrientation = LZVideoRecordOrientationLandscapeRight;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            self.recordOrientation = LZVideoRecordOrientationLandscapeLeft;
            break;
        default:
            NSLog(@"不支持的录制方向");
            break;
    }
}

- (UIInterfaceOrientation)orientationChange {
    kWeakSelf
    [self.motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue currentQueue] withHandler:^(CMAccelerometerData * _Nullable accelerometerData, NSError * _Nullable error) {
        CMAcceleration acceleration = accelerometerData.acceleration;
        UIInterfaceOrientation orientationNew;
        if (acceleration.x >= 0.75) {
            orientationNew = UIInterfaceOrientationLandscapeLeft;
        }
        else if (acceleration.x <= -0.75) {
            orientationNew = UIInterfaceOrientationLandscapeRight;
        }
        else if (acceleration.y <= -0.75) {
            orientationNew = UIInterfaceOrientationPortrait;
        }
        else if (acceleration.y >= 0.75) {
            orientationNew = UIInterfaceOrientationPortraitUpsideDown;
        }
        else {
            // Consider same as last time
            return;
        }
        
        if (!weakSelf.isCapturing) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (orientationNew == weakSelf.orientationLast)
                    return;
                [weakSelf configView:orientationNew];
                weakSelf.orientationLast = orientationNew;
            });
        }
    }];
    
    return self.orientationLast;
}
#pragma mark - Load View
- (void)configView:(UIInterfaceOrientation)aOrientation {
    switch (aOrientation) {
        case UIInterfaceOrientationLandscapeRight: {
            [self configLandscapeRightUI];
        }
            break;
        case UIInterfaceOrientationLandscapeLeft: {
            [self configLandscapeLeftUI];
        }
            break;
        case UIInterfaceOrientationPortrait: {
            [self configPortraitUI];
        }
            break;
        default: {
            NSLog(@"不支持的方向");
        }
            break;
    }
}

- (void)configPortraitUI {
    if (self.orientationLast == UIInterfaceOrientationLandscapeLeft) {
        self.flashSwitch.transform = CGAffineTransformRotate(self.flashSwitch.transform, M_PI_2);
        self.cameraSwitch.transform = CGAffineTransformRotate(self.cameraSwitch.transform, M_PI_2);
    } else if (self.orientationLast == UIInterfaceOrientationLandscapeRight) {
        self.flashSwitch.transform = CGAffineTransformRotate(self.flashSwitch.transform, -M_PI_2);
        self.cameraSwitch.transform = CGAffineTransformRotate(self.cameraSwitch.transform, -M_PI_2);
    }
}

- (void)configLandscapeRightUI {
    if (self.orientationLast == UIInterfaceOrientationPortrait || self.orientationLast == UIInterfaceOrientationUnknown) {
        self.flashSwitch.transform = CGAffineTransformRotate(self.flashSwitch.transform, M_PI_2);
        self.cameraSwitch.transform = CGAffineTransformRotate(self.cameraSwitch.transform, M_PI_2);
    } else if (self.orientationLast == UIInterfaceOrientationLandscapeLeft) {
        self.flashSwitch.transform = CGAffineTransformRotate(self.flashSwitch.transform, -M_PI);
        self.cameraSwitch.transform = CGAffineTransformRotate(self.cameraSwitch.transform, -M_PI);
    }
}

- (void)configLandscapeLeftUI {
    if (self.orientationLast == UIInterfaceOrientationLandscapeRight) {
        self.flashSwitch.transform = CGAffineTransformRotate(self.flashSwitch.transform, -M_PI);
        self.cameraSwitch.transform = CGAffineTransformRotate(self.cameraSwitch.transform, -M_PI);
        
    } else if (self.orientationLast == UIInterfaceOrientationPortrait || self.orientationLast == UIInterfaceOrientationUnknown) {
        self.flashSwitch.transform = CGAffineTransformRotate(self.flashSwitch.transform, -M_PI_2);
        self.cameraSwitch.transform = CGAffineTransformRotate(self.cameraSwitch.transform, -M_PI_2);
    }
}

/**
 控件的布局
 */
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    self.cameraView.frame = self.view.bounds;
    
    switch (_recordOrientation) {
        case LZVideoRecordOrientationPortrait:
        case LZVideoRecordOrientationPortraitDown:
            self.imageView.frame = self.view.bounds;
            break;
        case LZVideoRecordOrientationLandscapeLeft:
        case LZVideoRecordOrientationLandscapeRight:
            self.imageView.frame = CGRectMake(0, (LZ_SCREEN_HEIGHT-LZ_SCREEN_WIDTH*LZ_SCREEN_WIDTH/LZ_SCREEN_HEIGHT)/2, LZ_SCREEN_WIDTH, LZ_SCREEN_WIDTH*LZ_SCREEN_WIDTH/LZ_SCREEN_HEIGHT);
            break;
        default:
            break;
    }
    /* 摄像头转换按钮 */
    self.cameraSwitch.frame = CGRectMake(self.view.frame.size.width - kMARSwitchW*2 - kMARGap, 10, 72, 72);
    /* 闪光灯转换 */
    self.flashSwitch.frame = CGRectMake(CGRectGetMinX(self.cameraSwitch.frame) - kMARSwitchW , 30, kMARSwitchW, kMARSwitchW);
    //    self.flashSwitch.frame = CGRectMake(CGRectGetMinX(self.filterSwitch.frame) - kMARSwitchW - kMARGap, 30, kMARSwitchW, kMARSwitchW);
    /* 录制按钮 */
    self.recordButton.bounds = CGRectMake(0, 0, kRecordW, kRecordW);
    self.recordButton.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height - 70);
    self.hintLabel.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height - 140);
    self.hintLabel.bounds = CGRectMake(0, 50, 150, 30);
    /* 关闭按钮 */
    self.closeButton.center = CGPointMake((self.view.frame.size.width - kRecordW) / 4, self.recordButton.center.y);
    self.closeButton.bounds = CGRectMake(0, 0, 60, 60);
    
    /* 发送、返回按钮 */
    self.downButton.center = CGPointMake(self.view.frame.size.width - 80, self.view.frame.size.height - 70);
    self.downButton.bounds = CGRectMake(0, 0, 72, 72);
    self.recaptureButton.center = CGPointMake(80, self.downButton.center.y);
    self.recaptureButton.bounds = CGRectMake(0, 0, 72, 72);
}

#pragma mark - Logic Method

- (void)beginRecord {
    
    _isCapturing = YES;
    
    [self configVideoOutputOrientation];
    unlink([self.moviePath UTF8String]);
    
    [self.view.layer addSublayer:self.cycleLayer];
    [self.view.layer addSublayer:self.progressLayer];
    [self.view.layer addSublayer:self.ballLayer];
    
    switch (_showStyle) {
        case GPUImageShowStyleOnlyPhoto:
            self.recordButton.hidden = NO;
            self.cycleLayer.hidden = YES;
            self.progressLayer.hidden = YES;
            self.ballLayer.hidden = YES;
            break;
        case GPUImageShowStyleOnlyVideo:
            self.recordButton.hidden = YES;
            break;
        case GPUImageShowStyleAll:
            
            break;
            
        default:
            break;
    }
    
    [self hideAllFunctionButton];
    
    [(self.filterSwitch.selected ? self.normalFilter : self.normalFilter) addTarget:self.movieWriter];
    /* 设置录制时的方向 */
    switch (_recordOrientation) {
        case LZVideoRecordOrientationPortrait:
            [self.movieWriter startRecording];
            break;
        case LZVideoRecordOrientationLandscapeLeft:
            [self.movieWriter startRecordingInOrientation:CGAffineTransformMakeRotation(M_PI_2)];
            break;
        case LZVideoRecordOrientationLandscapeRight:
            [self.movieWriter startRecordingInOrientation:CGAffineTransformMakeRotation(-M_PI_2)];
            break;
        case LZVideoRecordOrientationPortraitDown:
            [self.movieWriter startRecordingInOrientation:CGAffineTransformMakeRotation(M_PI)];
            break;
        default:
            break;
    }
    /* 时间的增加 */
    _timer = [CADisplayLink displayLinkWithTarget:self selector:@selector(timerupdating)];
    _timer.frameInterval = 3;
//    _timer.preferredFramesPerSecond = 3;
    [_timer addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    _allTime = 0;
}


- (void)endRecord {
    
    _isCapturing = NO;
    if (!_timer) {
        return;
    }
    
    [_timer invalidate];
    _timer = nil;
    
    [self.cycleLayer removeFromSuperlayer];
    [self.progressLayer removeFromSuperlayer];
    [self.ballLayer removeFromSuperlayer];
    
    //    [self showAllFunctionButton];
    
    self.recordButton.alpha = 0;
    self.recordButton.frame = self.downButton.frame;
    [UIView animateWithDuration:0.8 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:1.5 options:UIViewAnimationOptionTransitionCurlUp animations:^{
        
        switch (_showStyle) {
            case GPUImageShowStyleOnlyPhoto:
                if (_allTime < 0.5) {
                    //                    self.recordButton.alpha = 0;
                    self.closeButton.alpha = 0;
                    self.recaptureButton.alpha = 1.0;
                    self.downButton.alpha = 1.0;
                }
                break;
            case GPUImageShowStyleOnlyVideo:
                if (_allTime > 0.5) {
                    //                    self.recordButton.alpha = 0;
                    self.closeButton.alpha = 0;
                    self.recaptureButton.alpha = 1.0;
                    self.downButton.alpha = 1.0;
                }
                break;
            case GPUImageShowStyleAll:
                self.closeButton.alpha = 0;
                self.recaptureButton.alpha = 1.0;
                self.downButton.alpha = 1.0;
                break;
                
            default:
                break;
        }
        
        
    } completion:^(BOOL finished) {
        
    }];
    
    [(self.filterSwitch.selected ? self.normalFilter : self.normalFilter) removeTarget:self.movieWriter];
    
    if (_allTime < 0.5) {
        // 储存到图片库,并且设置回调.
        [self.movieWriter finishRecording];
        
        if (_showStyle == GPUImageShowStyleOnlyVideo) {
            [self createNewWritter];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.imageView.hidden = NO;
            });
            [self recaptureAction];
        } else {
            UIImageOrientation imageOrientation = UIImageOrientationUp;
            switch (_recordOrientation) {
                case LZVideoRecordOrientationPortrait:
                    break;
                case LZVideoRecordOrientationLandscapeLeft:
                    imageOrientation = UIImageOrientationRight;
                    break;
                case LZVideoRecordOrientationLandscapeRight:
                    imageOrientation = UIImageOrientationLeft;
                    break;
                case LZVideoRecordOrientationPortraitDown:
                    imageOrientation = UIImageOrientationDown;
                    break;
                default:
                    break;
            }
            
            kWeakSelf
            [self.videoCamera capturePhotoAsImageProcessedUpToFilter:self.normalFilter withOrientation:imageOrientation withCompletionHandler:^(UIImage *processedImage, NSError *error) {
                //                UIImageOrientation imageOrientation = processedImage.imageOrientation;
                if(imageOrientation != UIImageOrientationUp) {
                    //以下为调整图片角度的部分
                    UIGraphicsBeginImageContext(processedImage.size);
                    [processedImage drawInRect:CGRectMake(0, 0, processedImage.size.width, processedImage.size.height)];
                    processedImage = UIGraphicsGetImageFromCurrentImageContext();
                    UIGraphicsEndImageContext();
                } else {
                    /* 清空控件的旋转方向 */
                    //                    self.imageView.transform = CGAffineTransformIdentity;
                    //                    switch (_recordOrientation) {
                    //                        case LZVideoRecordOrientationPortrait:
                    //                            break;
                    //                        case LZVideoRecordOrientationLandscapeLeft:
                    //                            self.imageView.transform = CGAffineTransformRotate(self.imageView.transform, M_PI_2);
                    //                            break;
                    //                        case LZVideoRecordOrientationLandscapeRight:
                    //                            self.imageView.transform = CGAffineTransformRotate(self.imageView.transform, -M_PI_2);
                    //                            break;
                    //                        case LZVideoRecordOrientationPortraitDown:
                    //                            self.imageView.transform = CGAffineTransformRotate(self.imageView.transform, M_PI);
                    //                            break;
                    //                        default:
                    //                            break;
                    //                    }
                }
                _tempImg = processedImage;
                [self createNewWritter];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.imageView setImage:processedImage];
                    weakSelf.imageView.hidden = NO;
                    self.cameraView.alpha = 0;
                });
            }];
        }
    }else {
        // 储存到视频库,并且设置回调.
        kWeakSelf
        [self.movieWriter finishRecordingWithCompletionHandler:^{
            [self createNewWritter];
            dispatch_async(dispatch_get_main_queue(), ^{
                _avplayer = [AVPlayerLayer playerLayerWithPlayer:[AVPlayer playerWithURL:[NSURL fileURLWithPath:RMDefaultVideoPath]]];
                _avplayer.frame = weakSelf.view.bounds;
                
                //                switch (_recordOrientation) {
                //                    case LZVideoRecordOrientationPortrait:
                //                        break;
                //                    case LZVideoRecordOrientationLandscapeLeft:
                //                        _avplayer.affineTransform = CGAffineTransformRotate(_avplayer.affineTransform, M_PI_2);
                //                        _avplayer.frame = CGRectMake(0, (LZ_SCREEN_HEIGHT-LZ_SCREEN_WIDTH*LZ_SCREEN_WIDTH/LZ_SCREEN_HEIGHT)/2, LZ_SCREEN_WIDTH, LZ_SCREEN_WIDTH*LZ_SCREEN_WIDTH/LZ_SCREEN_HEIGHT);
                //                        break;
                //                    case LZVideoRecordOrientationLandscapeRight:
                //                        _avplayer.affineTransform = CGAffineTransformRotate(_avplayer.affineTransform, -M_PI_2);
                //                        _avplayer.frame = CGRectMake(0, (LZ_SCREEN_HEIGHT-LZ_SCREEN_WIDTH*LZ_SCREEN_WIDTH/LZ_SCREEN_HEIGHT)/2, LZ_SCREEN_WIDTH, LZ_SCREEN_WIDTH*LZ_SCREEN_WIDTH/LZ_SCREEN_HEIGHT);
                //                        break;
                //                    case LZVideoRecordOrientationPortraitDown:
                //                        _avplayer.affineTransform = CGAffineTransformRotate(_avplayer.affineTransform, M_PI);
                //                        break;
                //                    default:
                //                        break;
                //                }
                [self.view.layer insertSublayer:_avplayer above:self.cameraView.layer];
                self.cameraView.alpha = 0;
                [_avplayer.player play];
                if (_showStyle == GPUImageShowStyleOnlyPhoto) {
                    [self recaptureAction];
                }
            });
        }];
    }
}

- (void)timerupdating {
    _allTime += 0.05;
    [self updateProgress:_allTime / kLimitRecLen];
}

- (void)createNewWritter {
    
    _movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:[NSURL fileURLWithPath:self.moviePath] size:CGSizeMake(kCameraWidth, kCameraWidth) fileType:AVFileTypeQuickTimeMovie outputSettings:self.videoSettings];
    /// 如果不加上这一句，会出现第一帧闪现黑屏
    [_videoCamera addAudioInputsAndOutputs];
    _videoCamera.audioEncodingTarget = _movieWriter;
}


- (void)hideAllFunctionButton {
    
    //    self.recordButton.hidden = YES;
    /* 隐藏三个图标 */
    [UIView animateWithDuration:0.5 animations:^{
        self.filterSwitch.alpha = 0;
        self.cameraSwitch.alpha = 0;
        self.flashSwitch.alpha = 0;
    }];
}

- (void)showAllFunctionButton {
    
    //    self.recordButton.hidden = NO;
    [UIView animateWithDuration:0.5 animations:^{
        self.filterSwitch.alpha = 1.0;
        self.cameraSwitch.alpha = 1.0;
        self.flashSwitch.alpha = 1.0;
    }];
}

#pragma mark - AnimationDelegate

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    [self performSelector:@selector(focusLayerNormal) withObject:self afterDelay:1.0f];
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    if (_avplayer) {
        [_avplayer.player pause];
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    if (_avplayer) {
        [_avplayer.player play];
    }
}

#pragma mark - User Action

- (void)saveAction {
    /* 拍照图片 */
    if (_tempImg) {
        UIImageWriteToSavedPhotosAlbum(_tempImg, self, nil, nil);
        NSString *imagePath = RMDefaultImagePath;
        [UIImagePNGRepresentation(_tempImg) writeToFile:imagePath atomically:YES];// 将图片写入文件
        if ([self.delegate respondsToSelector:@selector(finishAliPhotoImage:)]) {
            [self.delegate finishAliPhotoImage:imagePath];
        }
    }else {
        dispatch_async(dispatch_get_main_queue(), ^{
            UISaveVideoAtPathToSavedPhotosAlbum(RMDefaultVideoPath, self, nil, nil);
        });
        
        if ([self.delegate respondsToSelector:@selector(finishAliPlayShortVideo:)]) {
            [self.delegate finishAliPlayShortVideo:RMDefaultVideoPath];
        }
    }
    //    [self recaptureAction];
    [self closeButtonAction];
}

- (void)recaptureAction {
    
    [_avplayer.player pause];
    [_avplayer removeFromSuperlayer];
    _avplayer = nil;
    _tempImg = nil;
    self.imageView.hidden = YES;
    self.recordButton.hidden = NO;
    self.recordButton.bounds = CGRectMake(0, 0, kRecordW, kRecordW);
    self.recordButton.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height - 70);
    self.recordButton.alpha = 1.0;
    self.downButton.alpha = 0.0;
    self.recaptureButton.alpha = 0.0;
    self.closeButton.alpha = 1.0;
    self.cameraView.alpha = 1.0;
    /* 重新返回录制节目的时候显示各个控件 */
    [self showAllFunctionButton];
}

- (void)closeButtonAction {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)turnAction:(id)sender {
    
    [self.videoCamera pauseCameraCapture];
    
    if (self.videoCamera.cameraPosition == AVCaptureDevicePositionBack) {
        self.flashSwitch.hidden = YES;
        //        self.filterSwitch.selected = NO;
    }else {
        self.flashSwitch.hidden = NO;
        //        self.filterSwitch.selected = YES;
    }
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self.videoCamera rotateCamera];
        [self.videoCamera resumeCameraCapture];
    });
    
    [self performSelector:@selector(animationCamera) withObject:self afterDelay:0.2f];
    
}

- (void)flashAction:(id)sender {
    
    if (self.flashSwitch.selected) {
        self.flashSwitch.selected = NO;
        if ([self.videoCamera.inputCamera lockForConfiguration:nil]) {
            [self.videoCamera.inputCamera setTorchMode:AVCaptureTorchModeOff];
            [self.videoCamera.inputCamera setFlashMode:AVCaptureFlashModeOff];
            [self.videoCamera.inputCamera unlockForConfiguration];
        }
    }else {
        self.flashSwitch.selected = YES;
        if ([self.videoCamera.inputCamera lockForConfiguration:nil]) {
            [self.videoCamera.inputCamera setTorchMode:AVCaptureTorchModeOn];
            [self.videoCamera.inputCamera setFlashMode:AVCaptureFlashModeOn];
            [self.videoCamera.inputCamera unlockForConfiguration];
            
        }
    }
}

- (void)focusTap:(UITapGestureRecognizer *)tap {
    
    self.cameraView.userInteractionEnabled = NO;
    CGPoint touchPoint = [tap locationInView:tap.view];
    [self layerAnimationWithPoint:touchPoint];
    touchPoint = CGPointMake(touchPoint.x / tap.view.bounds.size.width, touchPoint.y / tap.view.bounds.size.height);
    
    if ([self.videoCamera.inputCamera isFocusPointOfInterestSupported] && [self.videoCamera.inputCamera isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        NSError *error;
        if ([self.videoCamera.inputCamera lockForConfiguration:&error]) {
            [self.videoCamera.inputCamera setFocusPointOfInterest:touchPoint];
            [self.videoCamera.inputCamera setFocusMode:AVCaptureFocusModeAutoFocus];
            
            if([self.videoCamera.inputCamera isExposurePointOfInterestSupported] && [self.videoCamera.inputCamera isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
            {
                [self.videoCamera.inputCamera setExposurePointOfInterest:touchPoint];
                [self.videoCamera.inputCamera setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            }
            
            [self.videoCamera.inputCamera unlockForConfiguration];
            
        } else {
            NSLog(@"ERROR = %@", error);
        }
    }
}

#pragma mark - Notification Action

- (void)moviePlayDidEnd:(NSNotification *)notification {
    [_avplayer.player seekToTime:kCMTimeZero];
    [_avplayer.player play];
}

#pragma mark - Animation

- (void)animationCamera {
    
    CATransition *animation = [CATransition animation];
    animation.delegate = self;
    animation.duration = .5f;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.type = @"oglFlip";
    animation.subtype = kCATransitionFromRight;
    [self.cameraView.layer addAnimation:animation forKey:nil];
    
}

- (void)updateProgress:(CGFloat)value {
    //    NSAssert(value <= 1.0 && value >= 0.0, @"Progress could't accept invail number .");
    if (value > 1.0) {
        [self endRecord];
    }else {
        UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:kRecordCenter radius:kRecordW / 2 startAngle:- M_PI_2 endAngle:2 * M_PI * (value) - M_PI_2 clockwise:YES];
        if (value - 0.1 <= CGFLOAT_MIN) {
            CGFloat val = value / 0.1;
            UIBezierPath *ballpath = [UIBezierPath bezierPathWithArcCenter:kRecordCenter radius:(kRecordW / 2  - 10) *val startAngle:0 endAngle:2 * M_PI clockwise:YES];
            self.ballLayer.path = ballpath.CGPath;
        }
        self.progressLayer.path = path.CGPath;
    }
}

- (void)focusLayerNormal {
    self.cameraView.userInteractionEnabled = YES;
    _focusLayer.hidden = YES;
}

- (void)layerAnimationWithPoint:(CGPoint)point {
    if (_focusLayer) {
        CALayer *focusLayer = _focusLayer;
        focusLayer.hidden = NO;
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [focusLayer setPosition:point];
        focusLayer.transform = CATransform3DMakeScale(2.0f,2.0f,1.0f);
        [CATransaction commit];
        
        CABasicAnimation *animation = [ CABasicAnimation animationWithKeyPath: @"transform" ];
        animation.toValue = [ NSValue valueWithCATransform3D: CATransform3DMakeScale(1.0f,1.0f,1.0f)];
        animation.delegate = self;
        animation.duration = 0.3f;
        animation.repeatCount = 1;
        animation.removedOnCompletion = NO;
        animation.fillMode = kCAFillModeForwards;
        [focusLayer addAnimation: animation forKey:@"animation"];
    }
}

#pragma mark - Property

- (GPUImageStillCamera *)videoCamera {
    if (!_videoCamera) {
        _videoCamera = [[GPUImageStillCamera alloc] initWithSessionPreset:AVCaptureSessionPresetHigh cameraPosition:AVCaptureDevicePositionBack];
        _videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait; // 镜头的方向
        _videoCamera.horizontallyMirrorFrontFacingCamera = YES;
    }
    return _videoCamera;
}

- (GPUImageFilterGroup *)normalFilter {
    if (!_normalFilter) {
        GPUImageFilter *filter = [[GPUImageFilter alloc] init]; //默认
        _normalFilter = [[GPUImageFilterGroup alloc] init];
        [(GPUImageFilterGroup *) _normalFilter setInitialFilters:[NSArray arrayWithObject: filter]];
        [(GPUImageFilterGroup *) _normalFilter setTerminalFilter:filter];
    }
    return _normalFilter;
}

- (CALayer *)focusLayer {
    if (!_focusLayer) {
        UIImage *focusImage = [UIImage imageNamed:@"touch_focus_x"];
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, focusImage.size.width, focusImage.size.height)];
        imageView.image = focusImage;
        _focusLayer = imageView.layer;
        _focusLayer.hidden = YES;
    }
    return _focusLayer;
}

- (NSString *)moviePath {
    if (!_moviePath) {
        _moviePath = RMDefaultVideoPath;
        NSLog(@"maru: %@",_moviePath);
    }
    return _moviePath;
}

- (NSDictionary *)audioSettings {
    if (!_audioSettings) {
        // 音频设置
        AudioChannelLayout channelLayout;
        memset(&channelLayout, 0, sizeof(AudioChannelLayout));
        channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
        _audioSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                          [ NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                          [ NSNumber numberWithInt: 2 ], AVNumberOfChannelsKey,
                          [ NSNumber numberWithFloat: 16000.0 ], AVSampleRateKey,
                          [ NSData dataWithBytes:&channelLayout length: sizeof( AudioChannelLayout ) ], AVChannelLayoutKey,
                          [ NSNumber numberWithInt: 32000 ], AVEncoderBitRateKey,
                          nil];
    }
    return _audioSettings;
}

- (NSMutableDictionary *)videoSettings {
    if (!_videoSettings) {
        _videoSettings = [[NSMutableDictionary alloc] init];
        [_videoSettings setObject:AVVideoCodecH264 forKey:AVVideoCodecKey];
        [_videoSettings setObject:[NSNumber numberWithInteger:kCameraWidth] forKey:AVVideoWidthKey];
        [_videoSettings setObject:[NSNumber numberWithInteger:kCameraHeight] forKey:AVVideoHeightKey];
    }
    return _videoSettings;
}

- (CABasicAnimation *)scaleAnimation {
    if (!_scaleAnimation) {
        _scaleAnimation = [CABasicAnimation animation];
        _scaleAnimation.repeatCount = HUGE_VALF;
        _scaleAnimation.duration = 0.8;
        _scaleAnimation.keyPath = @"transform.scale";
        _scaleAnimation.fromValue = [NSNumber numberWithFloat:1.0];
        _scaleAnimation.toValue = [NSNumber numberWithFloat:0.5];
        _scaleAnimation.timingFunction = [CAMediaTimingFunction functionWithName:@"easeOut"];
    }
    return _scaleAnimation;
}

/**
 五秒之后隐藏
 */
- (void)hiddenHintLabel {
    
    [UIView animateWithDuration:0.5 animations:^{
        self.hintLabel.alpha = 0.0;
    }];
}
- (CMMotionManager *)motionManager
{
    if (_motionManager == nil) {
        _motionManager = [[CMMotionManager alloc] init];
        _motionManager.accelerometerUpdateInterval = 1./15.;
        
    }
    return _motionManager;
}


@end
