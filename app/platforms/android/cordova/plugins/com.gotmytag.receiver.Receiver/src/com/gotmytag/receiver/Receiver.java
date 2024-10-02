package com.gotmytag.receiver;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Bundle;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;

import org.json.JSONArray;
import org.json.JSONException;

// import android.util.Log;

public class Receiver extends CordovaPlugin {

    // private static final String LOG_TAG = "AppReceiver";
    private static String BROADCAST_ACTION = "com.android.vending.INSTALL_REFERRER";

    private CallbackContext callback;
    private String extraKey;
    BroadcastReceiver receiver;

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);

        IntentFilter intentFilter = new IntentFilter(BROADCAST_ACTION);
        this.receiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                getExtra(intent);
            }
        };
        cordova.getActivity().registerReceiver(this.receiver, intentFilter);
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) {
        try {
            if (action.equals("onReceive")) {
                this.extraKey = args.getString(0);
                this.callback = callbackContext;
            }
            return true;
        } catch (JSONException e) {
        }
        return false;
    }

    private void getExtra(Intent intent) {
        Bundle extras = intent.getExtras();
        if (extras != null) {

            String referrerString = extras.getString(this.extraKey);

            if (referrerString != null) {
                this.callback.success(referrerString);
            }
        }
    }

} // end of class
