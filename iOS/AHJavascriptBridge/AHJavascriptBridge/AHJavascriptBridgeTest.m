//
//  AHJavascriptBridgeTest.m
//  AHKit
//
//  Created by Alan Miu on 15/12/17.
//  Copyright (c) 2015年 AutoHome. All rights reserved.
//

#import "AHJavascriptBridgeTest.h"
#import "AHJavascriptBridge.h"

@interface AHJavascriptBridgeTest () {
    AHJavascriptBridge *_jsBridge;
}

@end

@implementation AHJavascriptBridgeTest

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self log:@"--- Native Log ---"];
    
    _webView.delegate = self;
    
    NSString* htmlPath = [[NSBundle mainBundle] pathForResource:@"AHJavascriptBridgeTest" ofType:@"html"];
    NSString* appHtml = [NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
    NSURL *baseURL = [NSURL fileURLWithPath:htmlPath];
    [_webView loadHTMLString:appHtml baseURL:baseURL];
    
    // 创建bridge
    _jsBridge = [[AHJavascriptBridge alloc] initWhitWebview:_webView method:self];
//    _jsBridge.isDebug = YES;
    
    __weak typeof(self) wSelf = self;
    
    // 桥接完成事件
    [_jsBridge onJsBridgeReady:^(id args, AHJBCallbackBlock callback) {
        [wSelf log:@"ON_JS_BRIDGE_READY..."];
        callback(nil);
    }];
    
    // deprecated, 被onJsBridgeReady()取代,
    [_jsBridge bindMethod:@"onBridgeReady" method:^(id args, AHJBCallbackBlock callback) {
        [wSelf log:@"onBridgeReady..."];
        callback(nil);
    }];
    
    _webView.delegate = self;
}

- (void)batchBindMethodWhitWebView:(UIWebView *)webView bridge:(AHJavascriptBridge *)bridge {
    __weak typeof(self) wSelf = self;
    // 绑定方法, 提供给JS调用
    [bridge bindMethod:@"callNative" method:^(id args, AHJBCallbackBlock callback) {
        if (args)
            [wSelf log:[NSString stringWithFormat:@"method: callNative, %@ - %@", NSStringFromClass([args class]), args]];
        else
            [wSelf log:[NSString stringWithFormat:@"method: callNative, nil"]];
        callback(args);
    }];
    
    // 绑定方法, 提供给JS调用
    [bridge bindMethod:@"asyncCallNative" method:^(id args, AHJBCallbackBlock callback) {
        if (args)
            [wSelf log:[NSString stringWithFormat:@"method: callNative, %@ - %@", NSStringFromClass([args class]), args]];
        else
            [wSelf log:[NSString stringWithFormat:@"method: callNative, nil"]];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            callback(args);
        });
    }];
}

- (IBAction)callJs:(id)sender {
    [self log:@"invoke: callJs(args - json object)"];
    [_jsBridge invoke:@"callJs" methodArgs:@{@"Native" : @"Hello Js"} callback:^(id result) {
        [self log:[NSString stringWithFormat:@"return: %@ - %@", NSStringFromClass([result class]), result]];
    }];
    
    [self log:@"invoke: callJs(args - json array)"];
    [_jsBridge invoke:@"callJs" methodArgs:@[@"Hi" , @"Hey", @"Hello"] callback:^(id result) {
        [self log:[NSString stringWithFormat:@"return: %@ - %@", NSStringFromClass([result class]), result]];
    }];
    
    [self log:@"invoke: callJs(args - string )"];
    [_jsBridge invoke:@"callJs" methodArgs:@"Hello Js" callback:^(id result) {
        [self log:[NSString stringWithFormat:@"return: %@ - %@", NSStringFromClass([result class]), result]];
    }];
    
    [self log:@"invoke: callJs(args - nil )"];
    [_jsBridge invoke:@"callJs" methodArgs:nil callback:^(id result) {
        if (result)
            [self log:[NSString stringWithFormat:@"return: %@ - %@", NSStringFromClass([result class]), result]];
        else
            [self log:@"return: nil"];
        
    }];
}

- (IBAction)asyncCallJs:(id)sender {
    [self log:@"asyncinvoke: asyncCallJs(args is json object)"];
    [_jsBridge invoke:@"asyncCallJs" methodArgs:@{@"Native" : @"Hello Js"} callback:^(id result) {
        [self log:[NSString stringWithFormat:@"return: %@ - %@", NSStringFromClass([result class]), result]];
    }];
}

- (IBAction)jsBindMethodNames:(id)sender {
    [self log:@"invoke: jsBindMethodNames"];
    [_jsBridge getJsBindMethodNames:^(id result) {
        [self log:[NSString stringWithFormat:@"return: %@ - %@", NSStringFromClass([result class]), result]];
    }];
}

- (void)log:(NSString *)log {
    _tvLog.text = [_tvLog.text stringByAppendingString:[log stringByAppendingString:@"\n"]];    
    _tvLog.layoutManager.allowsNonContiguousLayout = NO;
    [_tvLog scrollRectToVisible:CGRectMake(0, _tvLog.contentSize.height-15, _tvLog.contentSize.width, 10) animated:NO];
}

#pragma mark - UIWebViewDelegate
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    NSLog(@"shouldStartLoadWithRequest");
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    NSLog(@"webViewDidStartLoad");
}
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    NSLog(@"webViewDidFinishLoad");
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
