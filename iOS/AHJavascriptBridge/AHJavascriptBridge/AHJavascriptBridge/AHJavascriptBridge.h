//
//  AHJavascriptBridge.h
//  AHKit
//
//  Created by Alan Miu on 15-1-15.
//  Copyright (c) 2015年 AutoHome. All rights reserved.
//

#import <UIKit/UIKit.h>
#ifdef __IPHONE_8_0
#import <WebKit/WebKit.h>
#endif

typedef void (^AHJBCallbackBlock)(id result);                           // 回调方法
typedef void (^AHJBMethodBlock)(id args, AHJBCallbackBlock callback);   // 方法实现

@protocol AHJBBatchBindMethod;

#ifdef __IPHONE_8_0
@interface AHJavascriptBridge : NSObject<UIWebViewDelegate, WKNavigationDelegate>
#else
@interface AHJavascriptBridge : NSObject<UIWebViewDelegate>
#endif

@property (nonatomic, weak) id delegate;    // UIWebViewDelegate or WKNavigationDelegate
@property (nonatomic, readonly) BOOL isDebug1;
@property (nonatomic) BOOL isDebug;

- (instancetype)initWithWebview:(UIView *)webView;
- (instancetype)initWithWebview:(UIView *)webView method:(id<AHJBBatchBindMethod>)method;

/**
 *  调用JS方法
 *
 *  @param methodName 方法名
 *  @param methodArgs 方法参数
 *  @param callback   回调方法
 */
- (void)invoke:(NSString *)methodName methodArgs:(id)methodArgs callback:(AHJBCallbackBlock)callback;

/**
 *  Native绑定方法, 提供给JS调用
 *
 *  @param name     方法名
 *  @param method   方法实现
 */
- (void)bindMethod:(NSString *)name method:(AHJBMethodBlock)method;

/**
 *  解除绑定Native方法
 *
 *  @param name   方法名
 */
- (void)unbindMethod:(NSString *)name;

/**
 *  获取所有Native绑定的方法名
 *
 *  @return 方法名
 */
- (NSArray *)getNativeBindMethodNames;

/**
 *  桥接完成事件
 *
 *  @param method 事件处理方法
 */
- (void)onJsBridgeReady:(AHJBMethodBlock)method;

/**
 *  获取所有JS绑定的方法名
 *
 *  @param callback 返回的数据回调方法
 */
- (void)getJsBindMethodNames:(AHJBCallbackBlock)callback;

@end

/**
 *  批量绑定方法
 */
@protocol AHJBBatchBindMethod <NSObject>

@required
- (void)batchBindMethodWhitWebView:(UIView *)webView bridge:(AHJavascriptBridge *)bridge;

@end

/**
 *  通讯协议命令
 */
@interface AHJBCommand : NSObject

@property (nonatomic, strong) NSString *methodName;
@property (nonatomic, strong) id methodArgs;
@property (nonatomic, strong) NSString *callbackId;
@property (nonatomic, strong) NSString *returnCallbackId;
@property (nonatomic, strong) id returnCallbackData;

- (instancetype)initWhitJson:(NSDictionary *)json;
- (instancetype)initWhitMethodName:(NSString *)methodName methodArgs:(id)methodArgs callbackId:(NSString *)callbackId;
- (instancetype)initWhitReturnCallbackId:(NSString *)returnCallbackId returnCallbackData:(id)returnCallbackData;

- (NSDictionary *)toJson;

@end
