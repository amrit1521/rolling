package org.apache.cordova.plugins;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;

import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.PackageManager.NameNotFoundException;
import android.util.Log;
import android.widget.Toast;

public class CheckKey extends CordovaPlugin {

	public static final String LOG_PROV = "PhoneGapLog";
	public static final String LOG_NAME = "CheckKey Plugin";

	@Override
	public boolean execute(final String action, final JSONArray args, final CallbackContext callbackContext) {
		if (action.equals("get")) {
			cordova.getThreadPool().execute(new Runnable() {
				@Override
				public void run() {
					final Boolean key = getKeyStatus();
					if (key != null) {
						callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, key));
					} else {
						callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, false));
					}
				}
			});
			return true;
		} else {
			Log.e(LOG_PROV, LOG_NAME + ": Error: " + PluginResult.Status.INVALID_ACTION);
			callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.INVALID_ACTION));
			return false;
		}
	}

	private Boolean getKeyStatus() {
		Boolean key = false;
		final PackageManager manager = cordova.getActivity().getPackageManager();
		if (manager.checkSignatures("org.teusink.droidpapers", "org.teusink.droidpapers.donate")
				== PackageManager.SIGNATURE_MATCH) {
			String version = "0.0.0";
			try {
				final PackageInfo pInfo = cordova.getActivity().getPackageManager().getPackageInfo("org.teusink.droidpapers.donate", 0);
				version = pInfo.versionName;
				if (version.equals("1.0.0")) {
					key = true;
				} else {
					showToast("You need to install the latest official license key","short");
					key = false;
				}
			} catch (NameNotFoundException e) {
				key = false;
			}
		} else {
			key = false;
		}
		return key;
	}

	private void showToast(final String message, final String duration) {
		cordova.getActivity().runOnUiThread(new Runnable() {
			@Override
			public void run() {
				if(duration.equals("long")) {
					Toast.makeText(cordova.getActivity(), message, Toast.LENGTH_LONG).show();
				} else {
					Toast.makeText(cordova.getActivity(), message, Toast.LENGTH_SHORT).show();
				}
			}
		});
	}
}