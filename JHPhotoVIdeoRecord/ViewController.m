//
//  ViewController.m
//  JHPhotoVIdeoRecord
//
//  Created by gjh on 17/2/24.
//  Copyright © 2017年 gjh. All rights reserved.
//

#import "ViewController.h"
#import "JHPhotoVideoRecordVC.h"
@interface ViewController ()<JHRecorderVideoDelegate>
- (IBAction)videoCamera:(id)sender;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)videoCamera:(id)sender {
    JHPhotoVideoRecordVC *jHPhotoVideoRecordVC = [[JHPhotoVideoRecordVC alloc] init];
    jHPhotoVideoRecordVC.delegate = self;
    jHPhotoVideoRecordVC.showStyle = GPUImageShowStyleAll;
    [self presentViewController:jHPhotoVideoRecordVC animated:YES completion:nil];
    
}

#pragma mark - JHRecorderVideoDelegate代理方法

- (void)finishAliPlayShortVideo:(NSString *)videoPath {
    /* 处理视频的方法 */
}

- (void)finishAliPhotoImage:(NSString *)imagePath {
    /* 处理照片的方法 */
    
}
@end
