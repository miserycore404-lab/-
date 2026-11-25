package com.linebyline.app;

import android.Manifest;
import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.provider.MediaStore;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import android.speech.tts.TextToSpeech;
import android.util.Base64;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.webkit.JavascriptInterface;
import android.webkit.PermissionRequest;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.Toast;

import androidx.core.content.FileProvider;
import androidx.webkit.WebViewAssetLoader;

import com.google.mlkit.vision.common.InputImage;
import com.google.mlkit.vision.text.TextRecognition;
import com.google.mlkit.vision.text.latin.TextRecognizerOptions;

import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Locale;

/** Hosts the study app (bundled in assets/www) and gives it native camera, text reading, voice, mic, sharing and reminders. */
public class MainActivity extends Activity {
    private static final String START_URL = "https://appassets.androidplatform.net/assets/www/index.html";
    private static final int REQ_FILE = 10, REQ_CAMERA_PERM = 11, REQ_MIC_PERM = 12, REQ_NOTIF_PERM = 13;

    private WebView web;
    private FrameLayout root;
    private TextToSpeech tts;
    private boolean ttsReady = false;
    private SpeechRecognizer recognizer;
    private String pendingMicLang = null;
    private ValueCallback<Uri[]> fileCallback;
    private Uri cameraUri;
    private WebChromeClient.FileChooserParams pendingChooser;
    private final Handler ui = new Handler(Looper.getMainLooper());

    @Override
    protected void onCreate(Bundle saved) {
        super.onCreate(saved);
        root = new FrameLayout(this);
        web = new WebView(this);
        root.addView(web, new FrameLayout.LayoutParams(-1, -1));
        setContentView(root);
        setupEdgeToEdge();

        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setDatabaseEnabled(true);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setAllowFileAccess(false);
        s.setAllowContentAccess(true);
        s.setTextZoom(100);

        final WebViewAssetLoader loader = new WebViewAssetLoader.Builder()
                .addPathHandler("/assets/", new WebViewAssetLoader.AssetsPathHandler(this)).build();
        web.setWebViewClient(new WebViewClient() {
            @Override public WebResourceResponse shouldInterceptRequest(WebView v, WebResourceRequest r) {
                return loader.shouldInterceptRequest(r.getUrl());
            }
            @Override public boolean shouldOverrideUrlLoading(WebView v, WebResourceRequest r) {
                Uri u = r.getUrl();
                if ("appassets.androidplatform.net".equals(u.getHost())) return false;
                try { startActivity(new Intent(Intent.ACTION_VIEW, u)); } catch (ActivityNotFoundException ignored) {}
                return true;
            }
        });
        web.setWebChromeClient(new WebChromeClient() {
            @Override public boolean onShowFileChooser(WebView v, ValueCallback<Uri[]> cb, FileChooserParams p) {
                if (fileCallback != null) fileCallback.onReceiveValue(null);
                fileCallback = cb;
                if (p.isCaptureEnabled() && acceptsImages(p)) {
                    if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                        pendingChooser = p;
                        requestPermissions(new String[]{Manifest.permission.CAMERA}, REQ_CAMERA_PERM);
                    } else openCamera();
                } else openPicker(p);
                return true;
            }
            @Override public void onPermissionRequest(PermissionRequest req) { req.deny(); }
        });
        web.addJavascriptInterface(new Bridge(), "Native");

        tts = new TextToSpeech(this, status -> ttsReady = status == TextToSpeech.SUCCESS);
        if (saved != null) web.restoreState(saved); else web.loadUrl(START_URL);
    }

    private void setupEdgeToEdge() {
        if (Build.VERSION.SDK_INT >= 30) getWindow().setDecorFitsSystemWindows(false);
        else root.setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);
        root.setOnApplyWindowInsetsListener((v, insets) -> {
            int top, bottom, left, right;
            if (Build.VERSION.SDK_INT >= 30) {
                android.graphics.Insets bars = insets.getInsets(WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout());
                android.graphics.Insets ime = insets.getInsets(WindowInsets.Type.ime());
                top = bars.top; left = bars.left; right = bars.right; bottom = Math.max(bars.bottom, ime.bottom);
            } else {
                top = insets.getSystemWindowInsetTop(); bottom = insets.getSystemWindowInsetBottom();
                left = insets.getSystemWindowInsetLeft(); right = insets.getSystemWindowInsetRight();
            }
            v.setPadding(left, top, right, bottom);
            return insets;
        });
        applyBars(isNight());
    }

    private boolean isNight() {
        return (getResources().getConfiguration().uiMode & android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES;
    }

    private void applyBars(boolean dark) {
        int bg = dark ? Color.parseColor("#0E1220") : Color.parseColor("#F3F5F9");
        root.setBackgroundColor(bg);
        getWindow().getDecorView().setBackgroundColor(bg);
        if (Build.VERSION.SDK_INT >= 30) {
            WindowInsetsController c = getWindow().getInsetsController();
            if (c != null) {
                int mask = WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS | WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS;
                c.setSystemBarsAppearance(dark ? 0 : mask, mask);
            }
        } else if (Build.VERSION.SDK_INT >= 23) {
            int f = root.getSystemUiVisibility();
            f = dark ? (f & ~View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR) : (f | View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR);
            root.setSystemUiVisibility(f);
        }
    }

    private static boolean acceptsImages(WebChromeClient.FileChooserParams p) {
        for (String t : p.getAcceptTypes()) if (t != null && t.startsWith("image")) return true;
        return false;
    }

    private void openCamera() {
        try {
            File dir = new File(getCacheDir(), "photos");
            dir.mkdirs();
            File f = new File(dir, "photo-" + System.currentTimeMillis() + ".jpg");
            cameraUri = FileProvider.getUriForFile(this, getPackageName() + ".files", f);
            Intent i = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
            i.putExtra(MediaStore.EXTRA_OUTPUT, cameraUri);
            i.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION | Intent.FLAG_GRANT_READ_URI_PERMISSION);
            startActivityForResult(i, REQ_FILE);
        } catch (Exception e) {
            cameraUri = null;
            cancelFile();
            toast("Couldn't open the camera.");
        }
    }

    private void openPicker(WebChromeClient.FileChooserParams p) {
        cameraUri = null;
        Intent i = new Intent(Intent.ACTION_GET_CONTENT);
        i.addCategory(Intent.CATEGORY_OPENABLE);
        i.setType(acceptsImages(p) ? "image/*" : "*/*");
        try { startActivityForResult(Intent.createChooser(i, "Choose a file"), REQ_FILE); }
        catch (ActivityNotFoundException e) { cancelFile(); toast("No app found to pick files."); }
    }

    private void cancelFile() {
        if (fileCallback != null) { fileCallback.onReceiveValue(null); fileCallback = null; }
    }

    @Override
    protected void onActivityResult(int req, int res, Intent data) {
        super.onActivityResult(req, res, data);
        if (req != REQ_FILE || fileCallback == null) return;
        Uri[] out = null;
        if (res == RESULT_OK) {
            if (cameraUri != null) out = new Uri[]{cameraUri};
            else if (data != null && data.getData() != null) out = new Uri[]{data.getData()};
        }
        fileCallback.onReceiveValue(out);
        fileCallback = null;
        cameraUri = null;
    }

    @Override
    public void onRequestPermissionsResult(int req, String[] perms, int[] res) {
        boolean ok = res.length > 0 && res[0] == PackageManager.PERMISSION_GRANTED;
        if (req == REQ_CAMERA_PERM) {
            if (ok) openCamera();
            else if (pendingChooser != null) { toast("Camera permission is off. Choose a photo instead."); openPicker(pendingChooser); }
            pendingChooser = null;
        } else if (req == REQ_MIC_PERM) {
            String lang = pendingMicLang; pendingMicLang = null;
            if (ok && lang != null) startListening(lang);
            else micEvent("error", "Microphone permission is off. You can type instead.");
        } else if (req == REQ_NOTIF_PERM && !ok) {
            toast("Notifications are off, so reminders can't show. You can turn them on in Android settings.");
        }
    }

    @Override
    public void onBackPressed() {
        web.evaluateJavascript("window.__back ? window.__back() : false", v -> {
            if (!"true".equals(v)) MainActivity.super.onBackPressed();
        });
    }

    @Override protected void onResume() { super.onResume(); if (web != null) web.evaluateJavascript("window.__onResume && window.__onResume()", null); }
    @Override protected void onSaveInstanceState(Bundle out) { super.onSaveInstanceState(out); web.saveState(out); }

    @Override
    protected void onDestroy() {
        if (tts != null) tts.shutdown();
        if (recognizer != null) recognizer.destroy();
        if (web != null) web.destroy();
        super.onDestroy();
    }

    /* ---------------- JS helpers ---------------- */
    private void js(String code) { ui.post(() -> web.evaluateJavascript(code, null)); }
    private void callback(String id, boolean ok, String payload) {
        js("window.__nativeCb(" + JSONObject.quote(id) + "," + ok + "," + JSONObject.quote(payload == null ? "" : payload) + ")");
    }
    private void micEvent(String type, String text) {
        js("window.__nativeMic && window.__nativeMic(" + JSONObject.quote(type) + "," + JSONObject.quote(text == null ? "" : text) + ")");
    }
    private void toast(String m) { ui.post(() -> Toast.makeText(this, m, Toast.LENGTH_LONG).show()); }

    /* ---------------- speech recognition ---------------- */
    private void startListening(String lang) {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) { micEvent("error", "Speech recognition isn't available on this phone."); return; }
        if (recognizer != null) recognizer.destroy();
        recognizer = SpeechRecognizer.createSpeechRecognizer(this);
        recognizer.setRecognitionListener(new RecognitionListener() {
            @Override public void onReadyForSpeech(Bundle b) {}
            @Override public void onBeginningOfSpeech() {}
            @Override public void onRmsChanged(float r) {}
            @Override public void onBufferReceived(byte[] b) {}
            @Override public void onEndOfSpeech() {}
            @Override public void onEvent(int t, Bundle b) {}
            @Override public void onPartialResults(Bundle b) {
                ArrayList<String> r = b.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
                if (r != null && !r.isEmpty()) micEvent("partial", r.get(0));
            }
            @Override public void onResults(Bundle b) {
                ArrayList<String> r = b.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
                if (r != null && !r.isEmpty()) micEvent("final", r.get(0));
                micEvent("end", "");
            }
            @Override public void onError(int e) {
                String msg = (e == SpeechRecognizer.ERROR_NO_MATCH || e == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) ? "Didn't catch that. Tap the mic and try again."
                        : e == SpeechRecognizer.ERROR_NETWORK || e == SpeechRecognizer.ERROR_NETWORK_TIMEOUT ? "Speech needs an internet connection for this language."
                        : e == SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS ? "Microphone permission is off."
                        : e == SpeechRecognizer.ERROR_CLIENT ? "" : "Speech recognition stopped.";
                micEvent("error", msg);
            }
        });
        Intent i = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE, lang);
        i.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true);
        i.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2500L);
        recognizer.startListening(i);
    }

    /* ---------------- the bridge the web app calls ---------------- */
    private class Bridge {
        @JavascriptInterface public String platform() { return "android"; }

        @JavascriptInterface public void ocr(String id, String base64Jpeg) {
            try {
                byte[] bytes = Base64.decode(base64Jpeg, Base64.DEFAULT);
                Bitmap bmp = BitmapFactory.decodeByteArray(bytes, 0, bytes.length);
                if (bmp == null) { callback(id, false, "bad image"); return; }
                TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                        .process(InputImage.fromBitmap(bmp, 0))
                        .addOnSuccessListener(r -> callback(id, true, r.getText()))
                        .addOnFailureListener(e -> callback(id, false, String.valueOf(e.getMessage())));
            } catch (Exception e) { callback(id, false, String.valueOf(e.getMessage())); }
        }

        @JavascriptInterface public void speak(String text, String lang, float rate) {
            if (!ttsReady) { toast("The voice is still loading. Try again in a moment."); return; }
            Locale loc = Locale.forLanguageTag(lang);
            int r = tts.setLanguage(loc);
            if (r == TextToSpeech.LANG_MISSING_DATA || r == TextToSpeech.LANG_NOT_SUPPORTED)
                toast("No voice installed for " + loc.getDisplayLanguage(Locale.ENGLISH) + ". Add one in Android settings → Text-to-speech.");
            tts.setSpeechRate(rate);
            tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, "lbl");
        }

        @JavascriptInterface public void listen(String lang) {
            ui.post(() -> {
                if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                    pendingMicLang = lang;
                    requestPermissions(new String[]{Manifest.permission.RECORD_AUDIO}, REQ_MIC_PERM);
                } else startListening(lang);
            });
        }

        @JavascriptInterface public void stopListening() { ui.post(() -> { if (recognizer != null) recognizer.stopListening(); }); }

        @JavascriptInterface public void shareFile(String name, String mime, String content) {
            try {
                File dir = new File(getCacheDir(), "shared");
                dir.mkdirs();
                File f = new File(dir, name.replaceAll("[^\\w.\\-]", "_"));
                try (FileOutputStream o = new FileOutputStream(f)) { o.write(content.getBytes(StandardCharsets.UTF_8)); }
                Uri u = FileProvider.getUriForFile(MainActivity.this, getPackageName() + ".files", f);
                Intent send = new Intent(Intent.ACTION_SEND);
                send.setType(mime);
                send.putExtra(Intent.EXTRA_STREAM, u);
                send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                ui.post(() -> startActivity(Intent.createChooser(send, "Save or send")));
            } catch (Exception e) { toast("Couldn't create the file."); }
        }

        @JavascriptInterface public void setReminder(boolean enabled, int hour, int minute) {
            ReminderReceiver.save(MainActivity.this, enabled, hour, minute);
            ReminderReceiver.schedule(MainActivity.this);
            if (enabled && Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED)
                ui.post(() -> requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, REQ_NOTIF_PERM));
        }

        @JavascriptInterface public void vibrate(int ms) {
            Vibrator v = (Vibrator) getSystemService(VIBRATOR_SERVICE);
            if (v == null) return;
            if (Build.VERSION.SDK_INT >= 26) v.vibrate(VibrationEffect.createOneShot(Math.max(10, ms), VibrationEffect.DEFAULT_AMPLITUDE));
            else v.vibrate(ms);
        }

        @JavascriptInterface public void setDarkBars(boolean dark) { ui.post(() -> applyBars(dark)); }
    }
}
