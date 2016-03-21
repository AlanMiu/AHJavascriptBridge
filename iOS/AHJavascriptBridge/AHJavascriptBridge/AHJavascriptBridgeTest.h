//
//  AHJavascriptBridgeTest.h
//  AHKit
//
//  Created by Alan Miu on 15/12/17.
//  Copyright (c) 2015年 AutoHome. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AHJavascriptBridge.h"

@interface AHJavascriptBridgeTest : UIViewController <UIWebViewDelegate, AHJBBatchBindMethod>

@property (weak, nonatomic) IBOutlet UIButton *callJS;
@property (weak, nonatomic) IBOutlet UITextView *tvLog;
@property (weak, nonatomic) IBOutlet UIWebView *webView;

@end
