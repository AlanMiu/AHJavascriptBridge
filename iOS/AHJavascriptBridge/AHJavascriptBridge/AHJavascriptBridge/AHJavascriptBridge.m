//
//  AHJavascriptBridge.m
//  AHKit
//
//  Created by Alan Miu on 15-1-15.
//  Copyright (c) 2015年 AutoHome. All rights reserved.
//

#import "AHJavascriptBridge.h"

#define BRIDGE_PROTOCOL_SCHEME  @"ahjb"
#define BRIDGE_PROTOCOL_HOST    @"_AUTOHOME_JAVASCRIPT_BRIDGE_"
#define BRIDGE_PROTOCOL_URL     BRIDGE_PROTOCOL_SCHEME + "://" + BRIDGE_PROTOCOL_HOST

#define JS_GET_JS_COMMANDS      @"_getJsCommands"
#define JS_RECEIVE_COMMANDS     @"_receiveCommands"

// for Native
#define METHOD_ON_JS_BRIDGE_READY           @"ON_JS_BRIDGE_READY"
#define METHOD_GET_JS_BIND_METHOD_NAMES     @"GET_JS_BIND_METHOD_NAMES"
// for JS
#define METHOD_GET_NATIVE_BIND_METHODS      @"getNativeBindMethods" // deprecated, 命名简单易冲突
#define METHOD_GET_NATIVE_BIND_METHOD_NAMES @"GET_NATIVE_BIND_METHOD_NAMES"

#define COMMAND_METHOD_NAME             @"methodName"
#define COMMAND_METHOD_ARGS             @"methodArgs"
#define COMMAND_CALLBACK_ID             @"callbackId"
#define COMMAND_RETURN_CALLBACK_ID      @"returnCallbackId"
#define COMMAND_RETURN_CALLBACK_DATA    @"returnCallbackData"

// AHJavascriptBridgeTest.js文件压缩后的代码
#define JS_INJECTION @";(function(){if(window.AHJavascriptBridge){return}var METHOD_ON_JS_BRIDGE_READY='ON_JS_BRIDGE_READY';var METHOD_GET_JS_BIND_METHOD_NAMES='GET_JS_BIND_METHOD_NAMES';var METHOD_GET_NATIVE_BIND_METHOD_NAMES='GET_NATIVE_BIND_METHOD_NAMES';var BRIDGE_PROTOCOL_URL='ahjb://_AUTOHOME_JAVASCRIPT_BRIDGE_';var iframeTrigger;var AJI=window._AUTOHOME_JAVASCRIPT_INTERFACE_;var commandQueue=[];var mapMethod={};var mapCallback={};var callbackNum=0;var ua=navigator.userAgent;var isIOS=ua.indexOf('iPhone')>-1||ua.indexOf('iPad')>-1||ua.indexOf('Mac')>-1;var isAndroid=ua.indexOf('Android')>-1||ua.indexOf('Adr')>-1||ua.indexOf('Linux')>-1;function invoke(methodName,methodArgs,callback){var command=_createCommand(methodName,methodArgs,callback,null,null);_sendCommand(command)}function bindMethod(name,method){mapMethod[name]=method}function unbindMethod(name){delete mapMethod[name]}function getJsBindMethodNames(){var methodNames=[];for(var methodName in mapMethod){methodNames.push(methodName)}return methodNames}function getNativeBindMethodNames(callback){invoke(METHOD_GET_NATIVE_BIND_METHOD_NAMES,null,callback)}function _checkNativeCommand(){var strCommands=AJI.getNativeCommands();if(strCommands){var commands=eval(strCommands);for(var i=0;i<commands.length;i++){_handleCommand(commands[i])}}}function _init(){_initBindMethods();if(typeof onBridgeReady==='function'){onBridgeReady()}var event=document.createEvent('HTMLEvents');event.initEvent(METHOD_ON_JS_BRIDGE_READY);document.dispatchEvent(event);invoke(METHOD_ON_JS_BRIDGE_READY,null,null)}function _initBindMethods(){bindMethod(METHOD_GET_JS_BIND_METHOD_NAMES,function(args,callback){callback(getJsBindMethodNames())})}function _sendCommand(command){if(isIOS){if(!iframeTrigger){iframeTrigger=document.createElement('iframe');iframeTrigger.style.display='none';document.documentElement.appendChild(iframeTrigger)}commandQueue.push(command);iframeTrigger.src=BRIDGE_PROTOCOL_URL}else{if(isAndroid){commandQueue.push(command);var jsonCommands=JSON.stringify(commandQueue);commandQueue=[];AJI.receiveCommands(jsonCommands)}}}function _getJsCommands(){var jsonCommands=JSON.stringify(commandQueue);commandQueue=[];return jsonCommands}function _receiveCommands(strCommands){var commands=eval(strCommands);for(var i=0;i<commands.length;i++){_handleCommand(commands[i])}}function _handleCommand(command){setTimeout(function(){if(!command){return}if(command.methodName){var method=mapMethod[command.methodName];if(method){method(command.methodArgs,function(result){if(command.callbackId){var returnCommand=_createCommand(null,null,null,command.callbackId,result);_sendCommand(returnCommand)}})}}else{if(command.returnCallbackId){var callback=mapCallback[command.returnCallbackId];if(callback){callback(command.returnCallbackData);delete mapCallback[command.returnCallbackId]}}}})}function _createCommand(methodName,methodArgs,callback,returnCallbackId,returnCallbackData){var command={};if(methodName){command.methodName=methodName}if(methodArgs){command.methodArgs=methodArgs}if(callback){callbackNum++;var callbackId='js_callback_'+callbackNum;mapCallback[callbackId]=callback;command.callbackId=callbackId}if(returnCallbackId){command.returnCallbackId=returnCallbackId}if(returnCallbackData){command.returnCallbackData=returnCallbackData}return command}window.AHJavascriptBridge={invoke:invoke,bindMethod:bindMethod,unbindMethod:unbindMethod,getJsBindMethodNames:getJsBindMethodNames,getNativeBindMethodNames:getNativeBindMethodNames,_checkNativeCommand:_checkNativeCommand,_getJsCommands:_getJsCommands,_receiveCommands:_receiveCommands};_init()})();"

@interface AHJavascriptBridge () {
    UIWebView *_webView;
    NSMutableArray *_commandQueue;
    NSMutableDictionary *_dicCallback;
    NSMutableDictionary *_dicMethod;
    NSUInteger _callbackNum;
    BOOL _isBridgeReady;
}

@end

@implementation AHJavascriptBridge

- (id)init {
    NSAssert(0, @"error, should call initWhitWebview");
    return nil;
}

- (id)initWhitWebview:(UIWebView *)webView {
    return [self initWhitWebview:webView method:nil];
}

- (id)initWhitWebview:(UIWebView *)webView method:(id<AHJBBatchBindMethod>)method {
    self = [super init];
    if (self) {
        _webView = webView;
        _delegate = webView.delegate;
        _webView.delegate = self;
        _commandQueue = [[NSMutableArray alloc] init];
        _dicCallback = [[NSMutableDictionary alloc] init];
        _dicMethod= [[NSMutableDictionary alloc] init];
        
        [self initBindMethods];

        if (method)
            [method batchBindMethodWhitWebView:webView bridge:self];
        
        [_webView addObserver:self forKeyPath:@"delegate" options:NSKeyValueObservingOptionNew context:nil];
    }
    return self;
}

/**
 *  初始化自带的绑定方法
 */
- (void)initBindMethods {
    __weak typeof(self) wSelf = self;
    
    // 获取Native绑定的方法(deprecated, 被METHOD_GET_NATIVE_BIND_METHOD_NAMES取代)
    [self bindMethod:METHOD_GET_NATIVE_BIND_METHODS method:^(id args, AHJBCallbackBlock callback) {
        NSDictionary *dicResult = [NSDictionary dictionaryWithObjectsAndKeys:[wSelf getNativeBindMethodNames], @"result", nil];
        callback(dicResult);
    }];
    
    // 获取Native绑定的方法
    [self bindMethod:METHOD_GET_NATIVE_BIND_METHOD_NAMES method:^(id args, AHJBCallbackBlock callback) {
        callback([wSelf getNativeBindMethodNames]);
    }];
}

/**
 *  调用JS方法
 *
 *  @param methodName 方法名
 *  @param methodArgs 方法参数
 *  @param callback   回调方法
 */
- (void)invoke:(NSString *)methodName methodArgs:(id)methodArgs callback:(AHJBCallbackBlock)callback {
    @synchronized(self) {
        AHJBCommand *commad = [[AHJBCommand alloc] initWhitMethodName:methodName methodArgs:methodArgs callbackId:[self createCallbackId:callback]];
        [self sendCommand:commad];
    }
}

/**
 *  Native绑定方法, 提供给JS调用
 *
 *  @param name     方法名
 *  @param method   方法实现
 */
- (void)bindMethod:(NSString *)name method:(AHJBMethodBlock)method {
    @synchronized(self) {
        [_dicMethod setObject:method forKey:name];
    }
}

/**
 *  解除绑定Native方法
 *
 *  @param name   方法名
 */
- (void)unbindMethod:(NSString *)name {
    @synchronized(self) {
        [_dicMethod removeObjectForKey:name];
    }
}

/**
 *  获取所有Native绑定的方法名
 *
 *  @return 方法名
 */
- (NSArray *)getNativeBindMethodNames {
    @synchronized(self) {
        return [_dicMethod allKeys];
    }
}

/**
 *  桥接完成事件
 *
 *  @param method 事件处理方法
 */
- (void)onJsBridgeReady:(AHJBMethodBlock)method {
    [self bindMethod:METHOD_ON_JS_BRIDGE_READY method:method];
}

/**
 *  获取所有JS绑定的方法名
 *
 *  @param callback 返回的数据回调方法
 */
- (void)getJsBindMethodNames:(AHJBCallbackBlock)callback {
    [self invoke:METHOD_GET_JS_BIND_METHOD_NAMES methodArgs:nil callback:callback];
}

/**
 *  发送命令
 */
- (void)sendCommand:(AHJBCommand *)command {
    @synchronized(self) {
        [self checkIsBridgeReady];
        if (command) {
            [_commandQueue addObject:[command toJson]];
        }
        if ([_commandQueue count] > 0) {
            [self call:JS_RECEIVE_COMMANDS args:_commandQueue];
            [_commandQueue removeAllObjects];
        }
    }
}

/**
 *  直接调用JS方法
 *
 *  @param function 方法名称
 *  @param args     方法参数
 *
 *  @return 执行方法后的返回值
 */
- (NSString *)call:(NSString *)function args:(id)args {
    NSString *jsonArgs = nil;
    if (args) {
        jsonArgs = [self jsonToString:args];
        // 字符转义
        NSArray *arrEscapeCharKey = [NSArray arrayWithObjects:@"\\", @"\"", @"\'", @"\n", @"\r", @"\f", @"\u2028", @"\u2029", nil];
        NSArray *arrEscapeCharValue = [NSArray arrayWithObjects:@"\\\\", @"\\\"", @"\\\'", @"\\n", @"\\r", @"\\f", @"\\u2028", @"\\u2029", nil];
        for (NSInteger i = 0; i < arrEscapeCharKey.count; i++) {
            jsonArgs = [jsonArgs stringByReplacingOccurrencesOfString:arrEscapeCharKey[i] withString:arrEscapeCharValue[i]];
        }
    }
    
    NSString *strScript = nil;
    if (jsonArgs) {
        strScript = [NSString stringWithFormat:@"AHJavascriptBridge.%@('%@');", function, jsonArgs];
    } else {
        strScript = [NSString stringWithFormat:@"AHJavascriptBridge.%@();", function];
    }
    
    NSString *result = [_webView stringByEvaluatingJavaScriptFromString:strScript];
    return result;
}

/**
 *  接收JS发送的字符串命令组
 */
- (void)receiveCommands {
    NSString *strCommands = [self call:JS_GET_JS_COMMANDS args:nil];
    id commands = [self stringToJson:strCommands];
    if ([commands isKindOfClass:[NSArray class]]) {
        for (NSDictionary *jsonCommand in commands) {
            [self handleCommand:jsonCommand];
        }
    }
}

/**
 *  处理命令
 *
 *  @param jsonCommand json命令
 */
- (void)handleCommand:(NSDictionary *)jsonCommand {
    if (jsonCommand) {
        @synchronized (self) {
            AHJBCommand *command = [[AHJBCommand alloc] initWhitJson:jsonCommand];
            // 执行命令
            if (command.methodName.length > 0) {
                AHJBMethodBlock method = _dicMethod[command.methodName];
                if (method) {
                    method(command.methodArgs, ^(id result) {
                        if (command.callbackId) {
                            AHJBCommand *returnCommand = [[AHJBCommand alloc] initWhitReturnCallbackId:command.callbackId returnCallbackData:result];
                            [self sendCommand:returnCommand];
                        }
                    });
                }
            }
            // 回调命令
            else if (command.returnCallbackId.length > 0) {
                AHJBCallbackBlock callback = _dicCallback[command.returnCallbackId];
                if (callback) {
                    callback(command.returnCallbackData);
                    callback = nil;
                    [_dicCallback removeObjectForKey:command.returnCallbackId];
                }
            }
        }
    }
}

/**
 *  检查JavascriptBridge是否已注入
 */
- (void)checkIsBridgeReady {
    if (!_isBridgeReady) {
        _isBridgeReady = [[_webView stringByEvaluatingJavaScriptFromString:@"typeof AHJavascriptBridge == 'object'"] isEqualToString:@"true"];
    }
    if (!_isBridgeReady) {
        [_webView stringByEvaluatingJavaScriptFromString:[self injectionCode]];
        _isBridgeReady = YES;
    }
}

/**
 *  Json字符串转Json字典
 *
 *  @param str Json字符串
 *
 *  @return NSDictionary
 */
- (id)stringToJson:(NSString *)str {
    return [NSJSONSerialization JSONObjectWithData:[str dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
}

/**
 *  Json字典转Json字符串
 *
 *  @param obj 对象
 *
 *  @return Json字符串
 */
- (NSString *)jsonToString:(id)obj {
    return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:obj options:0 error:nil] encoding:NSUTF8StringEncoding];
}

/**
 * 创建回调方法ID
 *
 * @param callback 回调方法
 * @return 回调方法ID 或 空
 */
- (NSString *)createCallbackId:(AHJBCallbackBlock)callback {
    if (callback) {
        NSString *callbackId = [NSString stringWithFormat:@"native_callback_%ld", (long)++_callbackNum];
        _dicCallback[callbackId] = [callback copy];
        return callbackId;
    }
    return nil;
}

/**
 *  获取JsBridge注入代码
 *
 *  @return JsBridge注入代码
 */
- (NSString *)injectionCode {
    NSString *js = JS_INJECTION;
    if (_isDebug) {
        // 从资源文件中获取JS注入代码, 方便调试
        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"AHJavascriptBridgeTest" ofType:@"js"];
        js = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    }
    return js;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    UIWebView *webView = object;
    if (webView == _webView && webView.delegate != self) {
        _delegate = webView.delegate;
        _webView.delegate = self;
    }
}

#pragma mark - UIWebViewDelegate
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    if (webView != _webView) return YES;
    
    if ([request.URL.absoluteString isEqualToString:@"about:blank"]) {
        return NO;
    }
    
    if ([request.URL.scheme isEqualToString:BRIDGE_PROTOCOL_SCHEME]) {
        if ([request.URL.host isEqualToString:BRIDGE_PROTOCOL_HOST]) {
            [self receiveCommands];
        }
        return NO;
    }
    
    if (_delegate && [_delegate respondsToSelector:@selector(webView:shouldStartLoadWithRequest:navigationType:)]) {
        return [_delegate webView:webView shouldStartLoadWithRequest:request navigationType:navigationType];
    }
    
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    if (webView != _webView) return;
    
    _isBridgeReady = NO;
    
    if (_delegate && [_delegate respondsToSelector:@selector(webViewDidStartLoad:)]) {
        [_delegate webViewDidStartLoad:webView];
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    if (webView != _webView) return;
    
    [self sendCommand:nil];
    
    if (_delegate && [_delegate respondsToSelector:@selector(webViewDidFinishLoad:)]) {
        [_delegate webViewDidFinishLoad:webView];
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    if (webView != _webView) return;
    
    if (_delegate && [_delegate respondsToSelector:@selector(webView:didFailLoadWithError:)]) {
        [_delegate webView:webView didFailLoadWithError:error];
    }
}

- (void)dealloc {
    [_webView removeObserver:self forKeyPath:@"delegate"];
}

@end

@implementation AHJBCommand

- (instancetype)initWhitJson:(NSDictionary *)json {
    self = [super init];
    if (self && json) {
        _methodName = json[COMMAND_METHOD_NAME];
        _methodArgs = json[COMMAND_METHOD_ARGS];
        _callbackId = json[COMMAND_CALLBACK_ID];
        _returnCallbackId = json[COMMAND_RETURN_CALLBACK_ID];
        _returnCallbackData = json[COMMAND_RETURN_CALLBACK_DATA];
    }
    return self;
}

- (instancetype)initWhitMethodName:(NSString *)methodName methodArgs:(id)methodArgs callbackId:(NSString *)callbackId {
    self = [super init];
    if (self) {
        _methodName = methodName;
        _methodArgs = methodArgs;
        _callbackId = callbackId;
    }
    return self;
}

- (instancetype)initWhitReturnCallbackId:(NSString *)returnCallbackId returnCallbackData:(id)returnCallbackData {
    self = [super init];
    if (self) {
        _returnCallbackId = returnCallbackId;
        _returnCallbackData = returnCallbackData;
    }
    return self;
}

- (NSDictionary *)toJson {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    
    if (_methodName) [json setObject:_methodName forKey:COMMAND_METHOD_NAME];
    if (_methodArgs) [json setObject:_methodArgs forKey:COMMAND_METHOD_ARGS];
    if (_callbackId) [json setObject:_callbackId forKey:COMMAND_CALLBACK_ID];
    if (_returnCallbackId) [json setObject:_returnCallbackId forKey:COMMAND_RETURN_CALLBACK_ID];
    if (_returnCallbackData) [json setObject:_returnCallbackData forKey:COMMAND_RETURN_CALLBACK_DATA];
    
    return json;
}

@end
