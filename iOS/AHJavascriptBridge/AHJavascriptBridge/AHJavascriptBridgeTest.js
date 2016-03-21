;
(function() {
    // for iOS
    if (window.AHJavascriptBridge) return;

    var BRIDGE_PROTOCOL_SCHEME = 'ahjb';
    var BRIDGE_PROTOCOL_HOST = '_AUTOHOME_JAVASCRIPT_BRIDGE_';
    var BRIDGE_PROTOCOL_URL = BRIDGE_PROTOCOL_SCHEME + '://' + BRIDGE_PROTOCOL_HOST;

    var METHOD_ON_JS_BRIDGE_READY = 'ON_JS_BRIDGE_READY';
    var METHOD_GET_JS_BIND_METHOD_NAMES = 'GET_JS_BIND_METHOD_NAMES';
    var METHOD_GET_NATIVE_BIND_METHOD_NAMES = 'GET_NATIVE_BIND_METHOD_NAMES';

    var iframeTrigger;
    var commandQueue = [];
    var mapMethod = {};
    var mapCallback = {};
    var callbackNum = 0;

    /**
     *  调用Native方法
     *
     *  @param methodName   方法名
     *  @param methodArgs   方法参数
     *  @param callback     回调方法
     */
    function invoke(methodName, methodArgs, callback) {
        var command = _createCommand(methodName, methodArgs, callback, null, null);
        _trigger(command);
    }

    /**
     *  JS绑定方法, 提供给Native调用
     *
     *  @param name    方法名
     *  @param method  方法实现
     */
    function bindMethod(name, method) {
        mapMethod[name] = method;
    }

    /**
     *  解除JS绑定方法
     *
     *  @param name 方法名
     */
    function unbindMethod(name) {
        delete mapMethod[name];
    }

    /**
     *  获取所有JS绑定的方法名
     */
    function getJsBindMethodNames() {
        var methodNames = [];
        for (var methodName in mapMethod) {
            methodNames.push(methodName);
        }
        return methodNames
    }

    /**
     * 获取所有Native绑定的方法名
     *
     * @param callback 返回的数据回调方法
     */
    function getNativeBindMethodNames(callback) {
        invoke(METHOD_GET_NATIVE_BIND_METHOD_NAMES, null, callback);
    }

    /**
     * 初始化
     */
    function _init() {
        iframeTrigger = document.createElement('iframe');
        iframeTrigger.style.display = 'none';
        document.documentElement.appendChild(iframeTrigger);

        _initBindMethods();

        // deprecated, 被事件通知取代
        if (typeof onBridgeReady === 'function')
            onBridgeReady();

        // 通知JS桥接完成(事件&方法)
        var event = document.createEvent('HTMLEvents');
        event.initEvent(METHOD_ON_JS_BRIDGE_READY);
        document.dispatchEvent(event);

        // 通知Native桥接完成
        invoke(METHOD_ON_JS_BRIDGE_READY, null, null);
    }

    /**
     * 初始化自带的绑定方法
     */
    function _initBindMethods() {
        // 获取JS所有绑定的方法
        bindMethod(METHOD_GET_JS_BIND_METHOD_NAMES, function(args, callback) {
            callback(getJsBindMethodNames());
        });
    }

    /**
     *  触发Native检查命令队列
     *
     *  @param command 命令
     */
    function _trigger(command) {
        commandQueue.push(command);
        iframeTrigger.src = BRIDGE_PROTOCOL_URL;
    }

    /**
     *  Native获取JS待处理的命令组
     */
    function _getJsCommands() {
        var jsonCommands = JSON.stringify(commandQueue);
        commandQueue = [];
        return jsonCommands;
    }

    /**
     *  接收Native发送的字符串命令组
     *
     *  @param strCommands 字符串命令组
     */
    function _receiveCommands(strCommands) {
        var commands = eval(strCommands);
        for (var i = 0; i < commands.length; i++) {
            _handleCommand(commands[i]);
        }
    }

    /**
     *  处理命令
     *
     *  @param command 命令
     */
    function _handleCommand(command) {
        setTimeout(function() {
            if (!command) return;
            // 执行命令
            if (command.methodName) {
                var method = mapMethod[command.methodName];
                if (method) {
                    method(command.methodArgs, function(result) {
                        if (command.callbackId) {
                            var returnCommand = _createCommand(null, null, null, command.callbackId, result);
                            _trigger(returnCommand);
                        }
                    });
                }
            }
            // 回调命令
            else if (command.returnCallbackId) {
                var callback = mapCallback[command.returnCallbackId];
                if (callback) {
                    callback(command.returnCallbackData);
                    delete mapCallback[command.returnCallbackId];
                }
            }

        });
    }

    /**
     *  创建命令
     *
     *  @param methodName           方法名
     *  @param methodArgs           方法参数
     *  @param callback             回调方法
     *  @param returnCallbackId     返回的回调方法ID
     *  @param returnCallbackData   返回的回调方法数据
     */
    function _createCommand(methodName, methodArgs, callback, returnCallbackId, returnCallbackData) {
        var command = {};
        if (methodName) command.methodName = methodName;
        if (methodArgs) command.methodArgs = methodArgs;
        if (callback) {
            callbackNum++;
            var callbackId = 'js_callback_' + callbackNum;
            mapCallback[callbackId] = callback;
            command.callbackId = callbackId;
        }
        if (returnCallbackId) command.returnCallbackId = returnCallbackId;
        if (returnCallbackData) command.returnCallbackData = returnCallbackData;
        return command;
    }

    window.AHJavascriptBridge = {
        invoke: invoke,
        bindMethod: bindMethod,
        unbindMethod: unbindMethod,
        getJsBindMethodNames: getJsBindMethodNames,
        getNativeBindMethodNames: getNativeBindMethodNames,
        _getJsCommands: _getJsCommands,
        _receiveCommands: _receiveCommands,
    }

    _init();

})();
