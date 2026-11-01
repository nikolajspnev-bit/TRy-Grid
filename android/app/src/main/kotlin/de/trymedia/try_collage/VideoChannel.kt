package de.trymedia.try_collage

import android.graphics.Bitmap
import android.graphics.Matrix
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Video Bausteine für TRy Grid:
 * Bilder aus einem Video lesen (als RGBA) und Bilder zu einer MP4 zusammensetzen.
 * Alles läuft nacheinander in einem eigenen Thread.
 */
class VideoChannel : MethodChannel.MethodCallHandler {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val readers = HashMap<Int, Reader>()
    private var encoder: Encoder? = null
    private var nextId = 1

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        worker.execute {
            try {
                val value: Any? = when (call.method) {
                    "probe" -> probe(call.argument<String>("path")!!)
                    "openReader" -> {
                        val id = nextId++
                        readers[id] = Reader(
                            call.argument<String>("path")!!,
                            call.argument<Int>("maxSide")!!,
                        )
                        id
                    }
                    "frame" -> {
                        val r = readers[call.argument<Int>("id")!!] ?: error("Reader fehlt")
                        r.frame(call.argument<Number>("timeMs")!!.toLong())
                    }
                    "closeReader" -> {
                        readers.remove(call.argument<Int>("id")!!)?.close()
                        null
                    }
                    "startEncoder" -> {
                        encoder?.abort()
                        encoder = Encoder(
                            call.argument<String>("path")!!,
                            call.argument<Int>("width")!!,
                            call.argument<Int>("height")!!,
                            call.argument<Int>("fps")!!,
                            call.argument<Int>("bitrate")!!,
                        )
                        null
                    }
                    "addFrame" -> {
                        (encoder ?: error("Encoder fehlt")).add(call.argument<ByteArray>("rgba")!!)
                        null
                    }
                    "finishEncoder" -> {
                        val e = encoder ?: error("Encoder fehlt")
                        encoder = null
                        e.finish()
                    }
                    else -> {
                        main.post { result.notImplemented() }
                        return@execute
                    }
                }
                main.post { result.success(value) }
            } catch (t: Throwable) {
                main.post { result.error("video", t.message ?: t.toString(), null) }
            }
        }
    }

    private fun probe(path: String): Map<String, Any> {
        val m = MediaMetadataRetriever()
        try {
            m.setDataSource(path)
            val w = m.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toInt() ?: 0
            val h = m.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toInt() ?: 0
            val rot = m.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toInt() ?: 0
            val dur = m.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLong() ?: 0L
            val turned = rot == 90 || rot == 270
            return mapOf(
                "width" to if (turned) h else w,
                "height" to if (turned) w else h,
                "durationMs" to dur,
            )
        } finally {
            m.release()
        }
    }

    /** Liest Bilder aus einem Video, möglichst der Reihe nach (schneller). */
    private class Reader(path: String, private val maxSide: Int) {
        private val m = MediaMetadataRetriever().apply { setDataSource(path) }
        private val durationMs =
            m.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLong() ?: 0L
        private val rotation =
            m.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toInt() ?: 0
        private val rawW = m.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toInt() ?: 0
        private val rawH = m.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toInt() ?: 0
        private val frameCount = if (Build.VERSION.SDK_INT >= 28) {
            m.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_FRAME_COUNT)?.toInt() ?: 0
        } else 0
        private var cacheStart = -1
        private var cache: List<Bitmap> = emptyList()

        fun frame(timeMs: Long): Map<String, Any> {
            val t = timeMs.coerceIn(0, max(0, durationMs - 1))
            var bmp: Bitmap? = null
            if (Build.VERSION.SDK_INT >= 28 && frameCount > 0 && durationMs > 0) {
                val idx = ((t.toDouble() / durationMs) * frameCount).toInt().coerceIn(0, frameCount - 1)
                if (idx < cacheStart || idx >= cacheStart + cache.size) {
                    cache.forEach { it.recycle() }
                    // Große Videos (4K) in kleinen Paketen, sonst wird der Speicher knapp.
                    val batch = if (rawW.toLong() * rawH > 2_500_000L) 2 else 8
                    val n = min(batch, frameCount - idx)
                    cache = try {
                        m.getFramesAtIndex(idx, n)
                    } catch (e: Throwable) {
                        emptyList()
                    }
                    cacheStart = idx
                }
                bmp = cache.getOrNull(idx - cacheStart)
            }
            if (bmp == null) {
                bmp = m.getFrameAtTime(t * 1000, MediaMetadataRetriever.OPTION_CLOSEST)
                    ?: error("Kein Bild bei $t ms")
            }
            return toRgba(fixRotation(bmp))
        }

        /** Manche Geräte liefern das Bild ungedreht: dann selbst drehen. */
        private fun fixRotation(b: Bitmap): Bitmap {
            val turned = rotation == 90 || rotation == 270
            val wantLandscape = if (turned) rawH > rawW else rawW > rawH
            val isLandscape = b.width > b.height
            if (rotation == 0 || rawW == rawH || wantLandscape == isLandscape) return b
            val mtx = Matrix().apply { postRotate(rotation.toFloat()) }
            return Bitmap.createBitmap(b, 0, 0, b.width, b.height, mtx, true)
        }

        private fun toRgba(src: Bitmap): Map<String, Any> {
            val scale = min(1.0, maxSide.toDouble() / max(src.width, src.height))
            val w = max(1, (src.width * scale).roundToInt())
            val h = max(1, (src.height * scale).roundToInt())
            var b = if (w != src.width || h != src.height) Bitmap.createScaledBitmap(src, w, h, true) else src
            if (b.config != Bitmap.Config.ARGB_8888) b = b.copy(Bitmap.Config.ARGB_8888, false)
            val buf = ByteBuffer.allocate(w * h * 4)
            b.copyPixelsToBuffer(buf)
            return mapOf("width" to w, "height" to h, "rgba" to buf.array())
        }

        fun close() {
            cache.forEach { it.recycle() }
            cache = emptyList()
            m.release()
        }
    }

    /** Schreibt RGBA Bilder als H.264 in eine MP4 Datei. */
    private class Encoder(
        private val path: String,
        private val w: Int,
        private val h: Int,
        private val fps: Int,
        bitrate: Int,
    ) {
        private val codec: MediaCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        private val muxer = MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        private val info = MediaCodec.BufferInfo()
        private var track = -1
        private var started = false
        private var index = 0L

        init {
            val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, w, h).apply {
                setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible)
                setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
                setInteger(MediaFormat.KEY_FRAME_RATE, fps)
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            }
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()
        }

        private fun pts() = index * 1_000_000L / fps

        fun add(rgba: ByteArray) {
            var inIdx = codec.dequeueInputBuffer(10_000)
            while (inIdx < 0) {
                drain(false)
                inIdx = codec.dequeueInputBuffer(10_000)
            }
            val image = codec.getInputImage(inIdx) ?: error("Kein Eingabebild")
            fillYuv(image, rgba)
            codec.queueInputBuffer(inIdx, 0, w * h * 3 / 2, pts(), 0)
            index++
            drain(false)
        }

        private fun fillYuv(image: android.media.Image, rgba: ByteArray) {
            val yP = image.planes[0]
            val uP = image.planes[1]
            val vP = image.planes[2]
            val yB = yP.buffer
            val uB = uP.buffer
            val vB = vP.buffer
            val yRow = yP.rowStride
            val yPix = yP.pixelStride
            for (j in 0 until h) {
                var p = j * w * 4
                val rowBase = j * yRow
                for (i in 0 until w) {
                    val r = rgba[p].toInt() and 0xFF
                    val g = rgba[p + 1].toInt() and 0xFF
                    val b = rgba[p + 2].toInt() and 0xFF
                    yB.put(rowBase + i * yPix, (((66 * r + 129 * g + 25 * b + 128) shr 8) + 16).toByte())
                    p += 4
                }
            }
            val uRow = uP.rowStride
            val uPix = uP.pixelStride
            val vRow = vP.rowStride
            val vPix = vP.pixelStride
            for (j in 0 until h / 2) {
                for (i in 0 until w / 2) {
                    val p = ((j * 2) * w + i * 2) * 4
                    val r = rgba[p].toInt() and 0xFF
                    val g = rgba[p + 1].toInt() and 0xFF
                    val b = rgba[p + 2].toInt() and 0xFF
                    uB.put(j * uRow + i * uPix, (((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128).toByte())
                    vB.put(j * vRow + i * vPix, (((112 * r - 94 * g - 18 * b + 128) shr 8) + 128).toByte())
                }
            }
        }

        private fun drain(end: Boolean) {
            var idle = 0
            while (true) {
                val out = codec.dequeueOutputBuffer(info, if (end) 10_000 else 0)
                when {
                    out == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                        if (!end || ++idle > 500) return
                    }
                    out == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        track = muxer.addTrack(codec.outputFormat)
                        muxer.start()
                        started = true
                    }
                    out >= 0 -> {
                        val buf = codec.getOutputBuffer(out)
                        if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) info.size = 0
                        if (buf != null && info.size > 0 && started) {
                            buf.position(info.offset)
                            buf.limit(info.offset + info.size)
                            muxer.writeSampleData(track, buf, info)
                        }
                        codec.releaseOutputBuffer(out, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                    }
                }
            }
        }

        fun finish(): String {
            var inIdx = codec.dequeueInputBuffer(10_000)
            while (inIdx < 0) {
                drain(false)
                inIdx = codec.dequeueInputBuffer(10_000)
            }
            codec.queueInputBuffer(inIdx, 0, 0, pts(), MediaCodec.BUFFER_FLAG_END_OF_STREAM)
            drain(true)
            codec.stop()
            codec.release()
            if (started) muxer.stop()
            muxer.release()
            return path
        }

        fun abort() {
            try { codec.stop() } catch (_: Throwable) {}
            try { codec.release() } catch (_: Throwable) {}
            try { if (started) muxer.stop() } catch (_: Throwable) {}
            try { muxer.release() } catch (_: Throwable) {}
        }
    }
}
