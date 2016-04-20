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
    
    self.navigationController.navigationBar.translucent = NO;
    
    [self log:@"--- Native Log ---"];
    
    WKWebView *wv = [[WKWebView alloc] initWithFrame:_webView.bounds];
//    wv.delegate = self;
    wv.navigationDelegate = self;
    
    // 创建bridge
    _jsBridge = [[AHJavascriptBridge alloc] initWithWebview:wv method:self];
//    _jsBridge.isDebug = YES;
    
    NSString* htmlPath = [[NSBundle mainBundle] pathForResource:@"AHJavascriptBridgeTest" ofType:@"html"];
    NSString* appHtml = [NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
    NSURL *baseURL = [NSURL fileURLWithPath:htmlPath];
    [wv loadHTMLString:appHtml baseURL:baseURL];
    
    [_webView addSubview:wv];
    
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

    // 测试修改delegate是否正常
//    wv.delegate = self;
    wv.navigationDelegate = self;
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
    NSLog(@"#UI# shouldStartLoadWithRequest");
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    NSLog(@"#UI# webViewDidStartLoad");
}
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    NSLog(@"#UI# webViewDidFinishLoad");
}

#pragma mark - WKNavigationDelegate
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSLog(@"#WK# decidePolicyForNavigationAction: %@", navigationAction);
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    NSLog(@"#WK# decidePolicyForNavigationResponse: %@", navigationResponse);
    decisionHandler(WKNavigationResponsePolicyAllow);
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    NSLog(@"didStartProvisionalNavigation: %@", navigation);
}

- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation {
    NSLog(@"#WK# didReceiveServerRedirectForProvisionalNavigation: %@", navigation);
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"#WK# didFailProvisionalNavigation: %@, %@", navigation, error);
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
    NSLog(@"#WK# didCommitNavigation: %@", navigation);
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSLog(@"#WK# didFinishNavigation: %@", navigation);
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"#WK# didFailNavigation: %@, %@", navigation, error);
}

- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
    NSLog(@"#WK# didReceiveAuthenticationChallenge: %@", challenge);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
