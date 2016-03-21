package com.autohome.ahkit;

import android.app.Activity;
import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.text.method.ScrollingMovementMethod;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.WebView;
import android.widget.Button;
import android.widget.TextView;

import com.autohome.ahkit.utils.JavascriptBridge;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * Created by Alan on 15/5/13.
 */
public class JavascriptBridgeTest extends Activity {
    private WebView mWebView;
    private TextView mTextView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        setContentView(R.layout.javascriptbridge_test);

        mTextView = (TextView) findViewById(R.id.textView);
        mTextView.setMovementMethod(ScrollingMovementMethod.getInstance());
        mTextView.setText("--- Native Log ---\n");
        mWebView = (WebView) findViewById(R.id.webView);

        final JavascriptBridge jsBridge = new JavascriptBridge(mWebView, mBatchBindMethod);
//        jsBridge.isDebug = true;

        // 桥接完成事件
        jsBridge.onJsBridgeReady(new JavascriptBridge.Method() {
            @Override
            public void execute(Object args, JavascriptBridge.Callback callback) {
                log("ON_JS_BRIDGE_READY...");
                callback.execute(null);
            }
        });

        // deprecated, 被onJsBridgeReady()取代
        jsBridge.bindMethod("onBridgeReady", new JavascriptBridge.Method() {
            @Override
            public void execute(Object args, JavascriptBridge.Callback callback) {
                log("onBridgeReady...");
                callback.execute(null);
            }
        });


        mWebView.setWebViewClient(jsBridge);
        mWebView.loadUrl("file:///android_asset/AHJavascriptBridgeTest.html");

        Button callJs = (Button) findViewById(R.id.callJs);
        callJs.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                log("invoke: callJs(args - json object)");
                JSONObject jsonObject = null;
                try {
                    jsonObject = new JSONObject("{\"Native\" : \"Hello Js\"}");
                } catch (JSONException e) {
                    e.printStackTrace();
                }
                jsBridge.invoke("callJs", jsonObject, new JavascriptBridge.Callback() {
                    @Override
                    public void execute(Object result) {
                        log("return: " + result.getClass().getSimpleName() + "-" + result);
                    }
                });

                log("invoke: callJs(args - json array)");
                JSONArray jsonArray = null;
                try {
                    jsonArray = new JSONArray("[\"Hi\", \"Hey\", \"Hello\"]");
                } catch (JSONException e) {
                    e.printStackTrace();
                }
                jsBridge.invoke("callJs", jsonArray, new JavascriptBridge.Callback() {
                    @Override
                    public void execute(Object result) {
                        log("return: " + result.getClass().getSimpleName() + "-" + result);
                    }
                });

                log("invoke: callJs(args - string)");
                jsBridge.invoke("callJs", "Hello Js", new JavascriptBridge.Callback() {
                    @Override
                    public void execute(Object result) {
                        log("return: " + result.getClass().getSimpleName() + "-" + result);
                    }
                });

                log("invoke: callJs(args - null)");
                jsBridge.invoke("callJs", null, new JavascriptBridge.Callback() {
                    @Override
                    public void execute(Object result) {
                        if (result != null)
                            log("return: " + result.getClass().getSimpleName() + "-" + result);
                        else
                            log("return: null");
                    }
                });
            }
        });

        Button asyncCallJs = (Button) findViewById(R.id.asyncCallJs);
        asyncCallJs.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                log("asyncinvoke: asyncCallJs(args - json object)");
                JSONObject jsonObject = null;
                try {
                    jsonObject = new JSONObject("{\"Native\" : \"Hello Js\"}");
                } catch (JSONException e) {
                    e.printStackTrace();
                }
                jsBridge.invoke("asyncCallJs", jsonObject, new JavascriptBridge.Callback() {
                    @Override
                    public void execute(Object result) {
                        log("return: " + result.getClass().getSimpleName() + "-" + result);
                    }
                });
            }
        });

        Button btnMethods = (Button) findViewById(R.id.getJsBindMethodNames);
        btnMethods.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                log("invoke: getJsBindMethodNames");
                jsBridge.getJsBindMethodNames(new JavascriptBridge.Callback() {
                    @Override
                    public void execute(Object result) {
                        log("return: " + result.getClass().getSimpleName() + "-" + result);
                    }
                });
            }
        });

    }

    private JavascriptBridge.BatchBindMethod mBatchBindMethod = new JavascriptBridge.BatchBindMethod() {
        @Override
        public void bind(final WebView view, JavascriptBridge bridge) {
            // 绑定方法, 提供给JS调用
            bridge.bindMethod("callNative", new JavascriptBridge.Method() {
                @Override
                public void execute(final Object args, final JavascriptBridge.Callback callback) {
                    if (args != null)
                        log("method: callNative, " + args.getClass().getSimpleName() + "-" + args);
                    else
                        log("method: callNative, null");
                    callback.execute(args);
                }
            });
            // 绑定方法, 提供给JS调用
            bridge.bindMethod("asyncCallNative", new JavascriptBridge.Method() {
                @Override
                public void execute(final Object args, final JavascriptBridge.Callback callback) {
                    if (args != null)
                        log("method: asyncCallNative, " + args.getClass().getSimpleName() + "-" + args);
                    else
                        log("method: asyncCallNative, null");
                    view.postDelayed(new Runnable() {
                        @Override
                        public void run() {
                            callback.execute(args);
                        }
                    }, 3000);
                }
            });
        }
    };


    private void log(final String log) {
        mTextView.post(new Runnable() {
            @Override
            public void run() {
                mTextView.setText(mTextView.getText() + log + "\n");
            }
        });

    }

}