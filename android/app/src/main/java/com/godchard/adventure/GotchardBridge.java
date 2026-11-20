package com.godchard.adventure;

import android.app.Activity;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.os.VibratorManager;
import android.webkit.JavascriptInterface;

public class GotchardBridge {
    private static final String PREF_NAME = "gotchard_native_save_v4";
    private static final String KEY_STATE = "save_json";

    private final Activity activity;
    private final Runnable immersiveRunner;
    private final SharedPreferences prefs;

    public GotchardBridge(Activity activity, Runnable immersiveRunner) {
        this.activity = activity;
        this.immersiveRunner = immersiveRunner;
        this.prefs = activity.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
    }

    private Vibrator getVibrator() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            VibratorManager vm = (VibratorManager) activity.getSystemService(Context.VIBRATOR_MANAGER_SERVICE);
            return vm != null ? vm.getDefaultVibrator() : null;
        } else {
            @SuppressWarnings("deprecation")
            Vibrator v = (Vibrator) activity.getSystemService(Context.VIBRATOR_SERVICE);
            return v;
        }
    }

    @JavascriptInterface
    public void vibrateOneShot(int ms) {
        try {
            int dur = Math.max(5, Math.min(200, ms));
            Vibrator vib = getVibrator();
            if (vib == null || !vib.hasVibrator()) return;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vib.vibrate(VibrationEffect.createOneShot(dur, VibrationEffect.DEFAULT_AMPLITUDE));
            } else {
                @SuppressWarnings("deprecation")
                Vibrator legacy = vib;
                legacy.vibrate(dur);
            }
        } catch (Throwable ignored) {}
    }

    @JavascriptInterface
    public void vibratePattern(String csv) {
        try {
            if (csv == null || csv.isEmpty()) return;
            String[] parts = csv.split(",");
            long[] timings = new long[parts.length + 1];
            timings[0] = 0L;
            for (int i = 0; i < parts.length; i++) {
                timings[i + 1] = Math.max(5L, Math.min(250L, Long.parseLong(parts[i].trim())));
            }
            Vibrator vib = getVibrator();
            if (vib == null || !vib.hasVibrator()) return;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vib.vibrate(VibrationEffect.createWaveform(timings, -1));
            } else {
                @SuppressWarnings("deprecation")
                Vibrator legacy = vib;
                legacy.vibrate(timings, -1);
            }
        } catch (Throwable ignored) {}
    }

    @JavascriptInterface
    public void saveState(String json) {
        if (json == null) return;
        prefs.edit().putString(KEY_STATE, json).apply();
    }

    @JavascriptInterface
    public String loadState() {
        return prefs.getString(KEY_STATE, "");
    }

    @JavascriptInterface
    public void enterImmersive() {
        activity.runOnUiThread(immersiveRunner);
    }

    @JavascriptInterface
    public void exitApp() {
        activity.runOnUiThread(() -> {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                activity.finishAndRemoveTask();
            } else {
                activity.finish();
            }
        });
    }
}
