package com.obnil.flutter_music_app

import android.app.PictureInPictureParams
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.obnil.flutter_music_app/pip"
    private var isPlayingMusic = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPip" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val aspectRatio = Rational(1, 1)
                            val pipParams = PictureInPictureParams.Builder()
                                .setAspectRatio(aspectRatio)
                                .build()
                            val success = enterPictureInPictureMode(pipParams)
                            result.success(success)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "setPlayingState" -> {
                    isPlayingMusic = call.argument<Boolean>("isPlaying") ?: false
                    result.success(true)
                }
                "isPipSupported" -> {
                    result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Automatically enter PiP when playing music and leaving app
        if (isPlayingMusic && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val pipParams = PictureInPictureParams.Builder()
                    .setAspectRatio(Rational(1, 1))
                    .build()
                enterPictureInPictureMode(pipParams)
            } catch (e: Exception) {
                // Ignore exception if PiP cannot be entered
            }
        }
    }
}
