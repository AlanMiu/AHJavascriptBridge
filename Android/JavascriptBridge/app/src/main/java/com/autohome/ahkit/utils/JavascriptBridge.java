package com.autohome.ahkit.utils;

import android.graphics.Bitmap;
import android.os.Handler;
import android.os.Looper;
import android.text.TextUtils;
import android.util.Log;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import org.apache.http.util.EncodingUtils;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Created by Alan Miu on 15/5/6.
 */
public class JavascriptBridge extends WebViewClient {
    private static final String AUTOHOME_JAVASCRIPT_INTERFACE = "_AUTOHOME_JAVASCRIPT_INTERFACE_";
    private static final String JS_CHECK_NATIVE_COMMAND = "AHJavascriptBridge._checkNativeCommand";
    // for Native
    private static final String METHOD_ON_JS_BRIDGE_READY = "ON_JS_BRIDGE_READY";
    private static final String METHOD_GET_JS_BIND_METHOD_NAMES = "GET_JS_BIND_METHOD_NAMES";
    // for JS
    private static final String METHOD_GET_NATIVE_BIND_METHODS = "getNativeBindMethods"; // deprecated, 命名简单易冲突
    private static final String METHOD_GET_NATIVE_BIND_METHOD_NAMES = "GET_NATIVE_BIND_METHOD_NAMES";

    private WebView mWebView;
    private Handler mHandler = new Handler();
    private List<Command> mCommandQueue = new ArrayList<>();
    private Map<String, Method> mMapMethod = new HashMap<>();
    private Map<String, Callback> mMapCallback = new HashMap<>();
    private AtomicInteger callbackNum = new AtomicInteger(0);

    public boolean isDebug;

    public JavascriptBridge(WebView view) {
        this(view, null);
    }

    public JavascriptBridge(WebView view, BatchBindMethod method) {
        mWebView = view;
        view.getSettings().setJavaScriptEnabled(true);
        view.addJavascriptInterface(this, AUTOHOME_JAVASCRIPT_INTERFACE);

        initBindMethods();

        if (method != null)
            method.bind(view, this);
    }

    /**
     * 初始化自带的绑定方法
     */
    private void initBindMethods() {
        // 获取Native绑定的方法(deprecated, 被METHOD_GET_NATIVE_BIND_METHOD_NAMES取代)
        bindMethod(METHOD_GET_NATIVE_BIND_METHODS, new Method() {
            @Override
            public void execute(Object args, Callback callback) {
                if (mMapMethod != null && mMapMethod.size() > 0) {
                    try {
                        callback.execute(new JSONObject().put("result", new JSONArray(mMapMethod.keySet())));
                    } catch (JSONException e) {
                        e.printStackTrace();
                    }
                }
                callback.execute(null);
            }
        });

        // 获取Native绑定的方法
        bindMethod(METHOD_GET_NATIVE_BIND_METHOD_NAMES, new Method() {
            @Override
            public void execute(Object args, Callback callback) {
                if (mMapMethod != null && mMapMethod.size() > 0)
                    callback.execute(new JSONArray(mMapMethod.keySet()));
                callback.execute(null);
            }
        });
    }

    /**
     * 调用JS方法
     *
     * @param methodName 方法名
     * @param methodArgs 方法参数
     * @param callback   回调方法
     */
    public void invoke(String methodName, Object methodArgs, Callback callback) {
        synchronized (this) {
            Command command = new Command(methodName, methodArgs, createCallbackId(callback));
            trigger(command);
        }
    }

    /**
     * Native绑定方法, 提供给JS调用
     *
     * @param name   方法名
     * @param method 方法实现
     */
    public void bindMethod(String name, Method method) {
        synchronized (this) {
            mMapMethod.put(name, method);
        }
    }

    /**
     * 解除绑定Native方法
     *
     * @param name 方法名
     */
    public void unbindMethod(String name) {
        synchronized (this) {
            mMapMethod.remove(name);
        }
    }

    /**
     * 获取所有Native绑定的方法名
     *
     * @return 方法名
     */
    public Set<String> getNativeBindMethodNames() {
        synchronized (this) {
            return mMapMethod.keySet();
        }
    }

    /**
     * 桥接完成事件
     *
     * @param method 事件处理方法
     */
    public void onJsBridgeReady(Method method) {
        bindMethod(JavascriptBridge.METHOD_ON_JS_BRIDGE_READY, method);
    }

    /**
     * 获取所有JS绑定的方法名
     *
     * @param callback 返回的数据回调方法
     */
    public void getJsBindMethodNames(Callback callback) {
        invoke(JavascriptBridge.METHOD_GET_JS_BIND_METHOD_NAMES, null, callback);
    }

    /**
     * 通过页面加载完毕事件注入JavascriptBridge
     */
    @Override
    public void onPageFinished(WebView view, String url) {
        super.onPageFinished(view, url);
        if (mWebView == view) {
            // 页面加载完成后注入JavascriptBridge
            loadUrl("javascript:" + getInjectionCode());
            trigger(null);
        }
    }

    /**
     * 接收JS发送的字符串命令组
     *
     * @param strCommands 字符串命令组
     */
    @JavascriptInterface
    public void receiveCommands(String strCommands) {
        try {
            JSONArray jsonCommands = new JSONArray(strCommands);
            for (int i = 0; i < jsonCommands.length(); i++) {
                JSONObject jsonCommand = jsonCommands.getJSONObject(i);
                handleCommand(jsonCommand);
            }
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }

    /**
     * JS获取Native待处理的命令组
     */
    @JavascriptInterface
    public String getNativeCommands() {
        synchronized (this) {
            String strCommands = null;
            if (mCommandQueue.size() > 0) {
                JSONArray array = new JSONArray();
                for (Command command : mCommandQueue) {
                    array.put(command.toJSONObject());
                }
                strCommands = array.toString();
                mCommandQueue.clear();
            }
            return strCommands;
        }
    }

    /**
     * 处理命令
     *
     * @param jsonCommand json命令
     */
    private void handleCommand(JSONObject jsonCommand) {
        if (jsonCommand != null) {
            synchronized (this) {
                final Command command = new Command(jsonCommand);
                // 执行命令
                if (!TextUtils.isEmpty(command.methodName)) {
                    final Method method = mMapMethod.get(command.methodName);
                    if (method != null) {
                        method.execute(command.methodArgs, new Callback() {
                            @Override
                            public void execute(Object result) {
                                // 回调JS方法并返回结果
                                if (!TextUtils.isEmpty(command.callbackId)) {
                                    Command returnCommand = new Command(command.callbackId, result);
                                    trigger(returnCommand);
                                }
                            }
                        });
                    }
                }
                // 回调Native方法
                else if (!TextUtils.isEmpty(command.returnCallbackId)) {
                    Object result = command.returnCallbackData;
                    Callback callback = mMapCallback.get(command.returnCallbackId);
                    if (callback != null) {
                        callback.execute(result);
                        mMapCallback.remove(command.returnCallbackId);
                    }
                }
            }
        }
    }

    /**
     * 触发JS检查命令队列
     */
    private void trigger(Command command) {
        synchronized (this) {
            if (mWebView != null) {
                if (command != null) {
                    mCommandQueue.add(command);
                }
                String strScript = "javascript:" + JS_CHECK_NATIVE_COMMAND + "()";
                loadUrl(strScript);
            }
        }
    }

    /**
     * 在主线程中加载url
     */
    private void loadUrl(final String url) {
        synchronized (this) {
            if (mWebView != null && url != null) {
                if (mWebView != null && url != null) {
                    try {
                        if (Looper.myLooper() == Looper.getMainLooper()) {
                            mWebView.loadUrl(url);
                        } else {
                            mHandler.post(new Runnable() {
                                @Override
                                public void run() {
                                    mWebView.loadUrl(url);
                                }
                            });
                        }
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }
            }
        }
    }

    /**
     * 创建回调方法ID
     *
     * @param callback 回调方法
     * @return 回调方法ID 或 空
     */
    private String createCallbackId(Callback callback) {
        if (callback != null) {
            String callbackId = "native_callback_id_" + callbackNum.getAndIncrement();
            mMapCallback.put(callbackId, callback);
            return callbackId;
        }
        return null;
    }

    // 压缩后的JsBridge注入代码
    private static final String JS_INJECTION = ";(function(){if(window.AHJavascriptBridge){return}var METHOD_ON_JS_BRIDGE_READY='ON_JS_BRIDGE_READY';var METHOD_GET_JS_BIND_METHOD_NAMES='GET_JS_BIND_METHOD_NAMES';var METHOD_GET_NATIVE_BIND_METHOD_NAMES='GET_NATIVE_BIND_METHOD_NAMES';var AJI=window._AUTOHOME_JAVASCRIPT_INTERFACE_;var commandQueue=[];var mapMethod={};var mapCallback={};var callbackNum=0;function invoke(methodName,methodArgs,callback){var command=_createCommand(methodName,methodArgs,callback,null,null);_sendCommand(command)}function bindMethod(name,method){mapMethod[name]=method}function unbindMethod(name){delete mapMethod[name]}function getJsBindMethodNames(){var methodNames=[];for(var methodName in mapMethod){methodNames.push(methodName)}return methodNames}function getNativeBindMethodNames(callback){invoke(METHOD_GET_NATIVE_BIND_METHOD_NAMES,null,callback)}function _checkNativeCommand(){var strCommands=AJI.getNativeCommands();if(strCommands){var commands=eval(strCommands);for(var i=0;i<commands.length;i++){_handleCommand(commands[i])}}}function _init(){_initBindMethods();if(typeof onBridgeReady==='function'){onBridgeReady()}var event=document.createEvent('HTMLEvents');event.initEvent(METHOD_ON_JS_BRIDGE_READY);document.dispatchEvent(event);invoke(METHOD_ON_JS_BRIDGE_READY,null,null)}function _initBindMethods(){bindMethod(METHOD_GET_JS_BIND_METHOD_NAMES,function(args,callback){callback(getJsBindMethodNames())})}function _sendCommand(command){commandQueue.push(command);var jsonCommands=JSON.stringify(commandQueue);commandQueue=[];AJI.receiveCommands(jsonCommands)}function _handleCommand(command){setTimeout(function(){if(!command){return}if(command.methodName){var method=mapMethod[command.methodName];if(method){method(command.methodArgs,function(result){if(command.callbackId){var returnCommand=_createCommand(null,null,null,command.callbackId,result);_sendCommand(returnCommand)}})}}else{if(command.returnCallbackId){var callback=mapCallback[command.returnCallbackId];if(callback){callback(command.returnCallbackData);delete mapCallback[command.returnCallbackId]}}}})}function _createCommand(methodName,methodArgs,callback,returnCallbackId,returnCallbackData){var command={};if(methodName){command.methodName=methodName}if(methodArgs){command.methodArgs=methodArgs}if(callback){callbackNum++;var callbackId='js_callback_'+callbackNum;mapCallback[callbackId]=callback;command.callbackId=callbackId}if(returnCallbackId){command.returnCallbackId=returnCallbackId}if(returnCallbackData){command.returnCallbackData=returnCallbackData}return command}window.AHJavascriptBridge={invoke:invoke,bindMethod:bindMethod,unbindMethod:unbindMethod,getJsBindMethodNames:getJsBindMethodNames,getNativeBindMethodNames:getNativeBindMethodNames,_checkNativeCommand:_checkNativeCommand};_init()})();";

    /**
     * 获取JsBridge注入代码
     *
     * @return JsBridge注入代码
     */
    private String getInjectionCode() {
        String js = JS_INJECTION;
        if (isDebug) {
            // 从资源文件中获取JS注入代码, 方便调试
            try {
                InputStream in = mWebView.getContext().getAssets().open("AHJavascriptBridgeTest.js");
                byte[] buffer = new byte[in.available()];
                in.read(buffer);
                js = EncodingUtils.getString(buffer, "UTF-8");
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
        return js;
    }

    /**
     * 方法实现接口
     */
    public interface Method {
        /**
         * 执行方法
         *
         * @param args     方法参数
         * @param callback 回调方法
         */
        void execute(Object args, Callback callback);
    }

    /**
     * 回调方法接口类
     */
    public interface Callback {
        void execute(Object result);
    }

    /**
     * 批量绑定方法
     */
    public interface BatchBindMethod {
        void bind(WebView view, JavascriptBridge bridge);
    }

    /**
     * 通讯协议命令
     */
    private class Command {
        private static final String COMMAND_METHOD_NAME = "methodName";
        private static final String COMMAND_METHOD_ARGS = "methodArgs";
        private static final String COMMAND_CALLBACK_ID = "callbackId";
        private static final String COMMAND_RETURN_CALLBACK_ID = "returnCallbackId";
        private static final String COMMAND_RETURN_CALLBACK_DATA = "returnCallbackData";

        public String methodName;
        public Object methodArgs;
        public String callbackId;
        public String returnCallbackId;
        public Object returnCallbackData;

        public Command(JSONObject json) {
            methodName = json.optString(COMMAND_METHOD_NAME, null);
            methodArgs = json.opt(COMMAND_METHOD_ARGS);
            callbackId = json.optString(COMMAND_CALLBACK_ID, null);
            returnCallbackId = json.optString(COMMAND_RETURN_CALLBACK_ID, null);
            returnCallbackData = json.opt(COMMAND_RETURN_CALLBACK_DATA);
        }

        public Command(String methodName, Object methodArgs, String callbackId) {
            this.methodName = methodName;
            this.methodArgs = methodArgs;
            this.callbackId = callbackId;
        }

        public Command(String returnCallbackId, Object returnCallbackData) {
            this.returnCallbackId = returnCallbackId;
            this.returnCallbackData = returnCallbackData;
        }

        public JSONObject toJSONObject() {
            JSONObject json = new JSONObject();
            try {
                json.put(COMMAND_METHOD_NAME, methodName);
                json.put(COMMAND_METHOD_ARGS, methodArgs);
                json.put(COMMAND_CALLBACK_ID, callbackId);
                json.put(COMMAND_RETURN_CALLBACK_ID, returnCallbackId);
                json.put(COMMAND_RETURN_CALLBACK_DATA, returnCallbackData);
            } catch (JSONException e) {
                e.printStackTrace();
            }
            return json;
        }
    }

}
