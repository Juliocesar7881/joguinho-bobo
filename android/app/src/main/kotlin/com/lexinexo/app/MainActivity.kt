package com.lexinexo.app

import android.media.AudioAttributes
import android.media.SoundPool
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var audioChannel: MethodChannel? = null
    private var soundPool: SoundPool? = null
    private var successSoundId = 0

    @Volatile
    private var successSoundLoaded = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val audioAttributes =
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        val pool =
            SoundPool.Builder()
                .setMaxStreams(1)
                .setAudioAttributes(audioAttributes)
                .build()

        soundPool = pool
        pool.setOnLoadCompleteListener { _, sampleId, status ->
            if (sampleId == successSoundId) {
                successSoundLoaded = status == 0
            }
        }
        successSoundId = pool.load(this, R.raw.lexinexo_success, 1)

        audioChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, audioChannelName).also {
                channel ->
                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        playSuccessMethod -> result.success(playSuccess())
                        else -> result.notImplemented()
                    }
                }
            }
    }

    override fun onDestroy() {
        audioChannel?.setMethodCallHandler(null)
        audioChannel = null
        successSoundLoaded = false
        successSoundId = 0
        soundPool?.release()
        soundPool = null
        super.onDestroy()
    }

    private fun playSuccess(): Boolean {
        val pool = soundPool ?: return false
        val soundId = successSoundId
        if (!successSoundLoaded || soundId == 0) {
            return false
        }

        return try {
            pool.play(soundId, playbackVolume, playbackVolume, 1, 0, 1.0f) != 0
        } catch (_: RuntimeException) {
            false
        }
    }

    private companion object {
        const val audioChannelName = "com.lexinexo.app/audio"
        const val playSuccessMethod = "playSuccess"
        const val playbackVolume = 0.72f
    }
}
