//
//  JHPhotoVideoRecordVC.h
//  JHPhotoVIdeoRecord
//
//  Created by gjh on 17/2/24.
//  Copyright © 2017年 gjh. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 录制模式

 - GPUImageShowStyleOnlyPhoto: 只进行拍照
 - GPUImageShowStyleOnlyVideo: 只进行摄像
 - GPUImageShowStyleAll: 两者共存
 */
typedef NS_ENUM(NSUInteger, GPUImageShowStyle) {
    GPUImageShowStyleOnlyPhoto = 0,
    GPUImageShowStyleOnlyVideo,
    GPUImageShowStyleAll
};

typedef NS_ENUM(NSUInteger, LZVideoRecordOrientation) {
    LZVideoRecordOrientationPortrait,
    LZVideoRecordOrientationPortraitDown,
    LZVideoRecordOrientationLandscapeRight,
    LZVideoRecordOrientationLandscapeLeft,
};

@protocol JHRecorderVideoDelegate <NSObject>

- (void)finishAliPlayShortVideo:(NSString *)videoPath;

- (void)finishAliPhotoImage:(NSString *)imagePath;

@end

@interface JHPhotoVideoRecordVC : UIViewController

@property (nonatomic, assign) id <JHRecorderVideoDelegate> delegate;

/* 录制模式 */
@property (nonatomic, assign) GPUImageShowStyle showStyle;

/* 视频限制的时间长度，不传值或为0默认为10秒(单位是秒) */
@property (nonatomic, assign) NSUInteger limitTime;

@end
