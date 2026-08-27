package app.eloq.eloq

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

class MainActivity : FlutterActivity() {
    private val audioExecutor = Executors.newSingleThreadExecutor()
    private val audioGeneration = AtomicInteger(0)

    @Volatile
    private var audioTrack: AudioTrack? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.eloq.eloq/native_audio"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val sampleRate = call.argument<Int>("sampleRate") ?: 24000
                    startAudio(sampleRate)
                    result.success(null)
                }
                "write" -> {
                    val bytes = call.arguments as? ByteArray
                    if (bytes == null) {
                        result.error("invalid_audio", "Audio bytes are required.", null)
                    } else {
                        writeAudio(bytes)
                        result.success(null)
                    }
                }
                "stop" -> {
                    stopAudio()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startAudio(sampleRate: Int) {
        val generation = audioGeneration.incrementAndGet()
        releaseTrack()
        audioExecutor.execute {
            if (generation != audioGeneration.get()) return@execute
            val minimum = AudioTrack.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            val bufferSize = maxOf(minimum, sampleRate * 2)
            val track = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setBufferSizeInBytes(bufferSize)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
            if (generation != audioGeneration.get()) {
                track.release()
                return@execute
            }
            audioTrack = track
            track.play()
        }
    }

    private fun writeAudio(bytes: ByteArray) {
        val generation = audioGeneration.get()
        audioExecutor.execute {
            if (generation != audioGeneration.get()) return@execute
            val track = audioTrack ?: return@execute
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                track.write(bytes, 0, bytes.size, AudioTrack.WRITE_BLOCKING)
            } else {
                @Suppress("DEPRECATION")
                track.write(bytes, 0, bytes.size)
            }
        }
    }

    private fun stopAudio() {
        audioGeneration.incrementAndGet()
        releaseTrack()
    }

    @Synchronized
    private fun releaseTrack() {
        val track = audioTrack ?: return
        audioTrack = null
        runCatching { track.pause() }
        runCatching { track.flush() }
        runCatching { track.stop() }
        runCatching { track.release() }
    }

    override fun onDestroy() {
        stopAudio()
        audioExecutor.shutdownNow()
        super.onDestroy()
    }
}
