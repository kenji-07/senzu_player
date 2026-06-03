// android/src/main/kotlin/dev/senzu/senzu_player/SenzuPlayerPlugin.kt

package dev.senzu.senzu_player

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.media.MediaCodecList
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import androidx.media3.common.util.UnstableApi
import android.os.Handler
import android.os.Looper
import com.google.android.gms.cast.CastMediaControlIntent
import com.google.android.gms.cast.framework.CastContext
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

@UnstableApi
class SenzuPlayerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    ActivityAware, EventChannel.StreamHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var downloadMethodChannel: MethodChannel
    private lateinit var downloadEventChannel: EventChannel

    private var appContext: Context? = null
    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null
    private var batteryReceiver: BroadcastReceiver? = null

    private var exoManager: SenzuExoPlayerManager? = null
    private var castPlugin: SenzuCastPlugin? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext

        val cp = SenzuCastPlugin(binding.applicationContext)
        castPlugin = cp

        methodChannel = MethodChannel(binding.binaryMessenger, "senzu_player/native")
        methodChannel.setMethodCallHandler(this)

        MethodChannel(binding.binaryMessenger, "senzu_player/cast")
            .setMethodCallHandler(cp)

        eventChannel = EventChannel(binding.binaryMessenger, "senzu_player/events")
        eventChannel.setStreamHandler(this)

        EventChannel(binding.binaryMessenger, "senzu_player/cast_events")
            .setStreamHandler(cp)

        exoManager = SenzuExoPlayerManager(
            context         = binding.applicationContext,
            messenger       = binding.binaryMessenger,
            textureRegistry = binding.textureRegistry
        )

        binding.platformViewRegistry.registerViewFactory(
            "senzu_player/surface",
            SenzuSurfaceViewFactory(binding.binaryMessenger)
        )

        downloadMethodChannel = MethodChannel(binding.binaryMessenger, "senzu_player/downloader")
        downloadMethodChannel.setMethodCallHandler { call, result ->
            val args = call.arguments as? Map<*, *>
            val ctx = activity ?: appContext ?: run {
                result.error("NO_CONTEXT", "Context is null", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "startDownload" -> {
                    val id = args?.get("id") as String
                    val url = args?.get("url") as String
                    val headers = (args?.get("headers") as? Map<*, *>)?.map { it.key.toString() to it.value.toString() } ?: emptyMap()
                    val drmConfig = (args?.get("drmConfig") as? Map<*, *>)?.map { it.key.toString() to it.value } ?: emptyMap()
                    val title = args?.get("title") as? String ?: ""
                    SenzuDownloadManager.startDownload(ctx, id, url, headers, drmConfig, title)
                    result.success(null)
                }
                "pauseDownload" -> {
                    val id = args?.get("id") as String
                    SenzuDownloadManager.pauseDownload(ctx, id)
                    result.success(null)
                }
                "resumeDownload" -> {
                    val id = args?.get("id") as String
                    SenzuDownloadManager.resumeDownload(ctx, id)
                    result.success(null)
                }
                "cancelDownload" -> {
                    val id = args?.get("id") as String
                    SenzuDownloadManager.cancelDownload(ctx, id)
                    result.success(null)
                }
                "deleteDownload" -> {
                    val id = args?.get("id") as String
                    SenzuDownloadManager.deleteDownload(ctx, id)
                    result.success(null)
                }
                "notifyLicenseExpired" -> {
                    val id = args?.get("id") as String
                    val title = args?.get("title") as? String ?: ""
                    SenzuDownloadManager.notifyLicenseExpired(ctx, id, title)
                    result.success(null)
                }
                "requestNotificationPermission" -> {
                    SenzuDownloadManager.requestNotificationPermission(activity)
                    result.success(null)
                }
                "setNotificationLocales" -> {
                    val downloadCompleteTitle = args?.get("downloadCompleteTitle") as? String ?: ""
                    val downloadCompleteBody = args?.get("downloadCompleteBody") as? String ?: ""
                    val downloadFailedTitle = args?.get("downloadFailedTitle") as? String ?: ""
                    val downloadFailedBody = args?.get("downloadFailedBody") as? String ?: ""
                    val licenseExpiredTitle = args?.get("licenseExpiredTitle") as? String ?: ""
                    val licenseExpiredBody = args?.get("licenseExpiredBody") as? String ?: ""
                    SenzuDownloadManager.setNotificationLocales(
                        downloadCompleteTitle, downloadCompleteBody,
                        downloadFailedTitle, downloadFailedBody,
                        licenseExpiredTitle, licenseExpiredBody
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        downloadEventChannel = EventChannel(binding.binaryMessenger, "senzu_player/downloader_events")
        downloadEventChannel.setStreamHandler(SenzuDownloadManager)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        downloadMethodChannel.setMethodCallHandler(null)
        downloadEventChannel.setStreamHandler(null)
        exoManager?.dispose()
        exoManager = null
        castPlugin?.dispose()
        castPlugin = null
        appContext = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        exoManager?.setActivity(binding.activity)
        castPlugin?.setActivity(binding.activity)
    }

    override fun onDetachedFromActivity() {
        activity = null
        exoManager?.setActivity(null)
        castPlugin?.setActivity(null)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        exoManager?.setActivity(binding.activity)
        castPlugin?.setActivity(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
        exoManager?.setActivity(null)
        castPlugin?.setActivity(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val ctx  = activity ?: appContext

        if (exoManager != null && exoManager!!.handleMethodCall(call, result)) return

        when (call.method) {

            // ── Cast initialize ────────────────────────────────────────────
            "initCast" -> {
    val appId = args?.get("appId") as? String
        ?: CastMediaControlIntent.DEFAULT_MEDIA_RECEIVER_APPLICATION_ID

    SenzuCastOptionsProvider.setAppId(appId)

    val appCtx = appContext ?: run { result.success(null); return }

    // Main thread дээр хийх ёстой
    Handler(Looper.getMainLooper()).post {
        try {
            if (!isCastContextInitialized()) {
                CastContext.getSharedInstance(appCtx)
            }
            castPlugin?.onCastInitialized()
            result.success(null)
        } catch (e: Exception) {
            println("SenzuPlayerPlugin: initCast failed — ${e.message}")
            result.error("CAST_INIT_ERROR", e.message, null)
        }
    }
}

            // ── Secure mode ────────────────────────────────────────────────
            "enableSecureMode"  -> { activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_SECURE);   result.success(null) }
            "disableSecureMode" -> { activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_SECURE);  result.success(null) }

            // ── Wakelock ───────────────────────────────────────────────────
            "enableWakelock"    -> { activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);   result.success(null) }
            "disableWakelock"   -> { activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON); result.success(null) }

            // ── Volume ─────────────────────────────────────────────────────
            "getVolume" -> {
                val am  = ctx?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                val max = am?.getStreamMaxVolume(AudioManager.STREAM_MUSIC) ?: 15
                val cur = am?.getStreamVolume(AudioManager.STREAM_MUSIC)    ?: 0
                result.success(if (max > 0) cur.toDouble() / max else 0.0)
            }
            "setVolume" -> {
                val vol = (args?.get("volume") as? Double) ?: 0.5
                val am  = ctx?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                val max = am?.getStreamMaxVolume(AudioManager.STREAM_MUSIC) ?: 15
                am?.setStreamVolume(AudioManager.STREAM_MUSIC, (vol * max).toInt(), 0)
                result.success(null)
            }

            // ── Brightness ─────────────────────────────────────────────────
            "getBrightness" -> {
                val lp = activity?.window?.attributes
                val b  = if (lp != null && lp.screenBrightness >= 0) lp.screenBrightness
                         else Settings.System.getInt(
                             ctx?.contentResolver,
                             Settings.System.SCREEN_BRIGHTNESS, 128
                         ) / 255f
                result.success(b.toDouble())
            }
            "setBrightness" -> {
                val b = (args?.get("brightness") as? Double)?.toFloat() ?: 0.5f
                activity?.runOnUiThread {
                    val lp = activity?.window?.attributes
                    lp?.screenBrightness = b
                    activity?.window?.attributes = lp
                }
                result.success(null)
            }

            // ── Battery ────────────────────────────────────────────────────
            "getBatteryLevel" -> {
                val bm = ctx?.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
                result.success(bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: -1)
            }
            "getBatteryState" -> {
                val f  = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
                val i  = ctx?.registerReceiver(null, f)
                val st = i?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
                result.success(batteryString(st))
            }

            // ── Network ────────────────────────────────────────────────────
            "getNetworkType" -> {
                val cm   = ctx?.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                val caps = cm?.getNetworkCapabilities(cm.activeNetwork)
                result.success(when {
                    caps == null -> "none"
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)     -> "wifi"
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
                    else -> "unknown"
                })
            }

            // ── HDR ────────────────────────────────────────────────────────
            "isHdrSupported" -> {
                val supported = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val wm      = ctx?.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
                    val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R)
                        ctx?.display
                    else
                        @Suppress("DEPRECATION") wm?.defaultDisplay
                    display?.hdrCapabilities?.supportedHdrTypes?.isNotEmpty() ?: false
                } else false
                result.success(supported)
            }
            "enableHdrIfSupported" -> result.success(null)

            // ── Low-latency / Live ─────────────────────────────────────────
            "setLowLatencyMode" -> {
                val targetMs = (args?.get("targetMs") as? Int) ?: 2000
                exoManager?.setLowLatencyMode(targetMs)
                result.success(null)
            }
            "getLiveLatency" -> result.success(exoManager?.getLiveLatency() ?: -1L)

            // ── Audio tracks ───────────────────────────────────────────────
            "getAudioTracks" -> result.success(exoManager?.getAudioTracks() ?: emptyList<Map<String, Any>>())
            "setAudioTrack"  -> {
                val trackId = args?.get("trackId") as? String ?: ""
                exoManager?.setAudioTrack(trackId)
                result.success(null)
            }

            // ── Codec support ──────────────────────────────────────────────
            "checkCodecSupport" -> {
                val codec = args?.get("codec") as? String ?: ""
                val supported = when (codec.lowercase()) {
                    "hevc", "h265" -> MediaCodecList(MediaCodecList.ALL_CODECS).codecInfos.any { ci ->
                        !ci.isEncoder && ci.supportedTypes.any { it.equals("video/hevc", ignoreCase = true) }
                    }
                    "av1" -> MediaCodecList(MediaCodecList.ALL_CODECS).codecInfos.any { ci ->
                        !ci.isEncoder && ci.supportedTypes.any { it.equals("video/av01", ignoreCase = true) }
                    }
                    else -> true
                }
                result.success(supported)
            }

            "checkDrmSupport" -> result.success(SenzuDrmManager.isWidevineSupported())

            // ── URL Launcher ───────────────────────────────────────────────
            "launchUrl" -> {
                val url = args?.get("url") as? String ?: ""
                val launched = if (ctx != null && url.isNotEmpty()) {
                    SenzuUrlLauncher.launchUrl(ctx, url)
                } else false
                result.success(launched)
            }

            else -> result.notImplemented()
        }
    }

    // CastContext initialize болсон эсэхийг аюулгүйгээр шалгана
    private fun isCastContextInitialized(): Boolean {
        return try {
            CastContext.getSharedInstance()
            true
        } catch (_: Exception) {
            false
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        exoManager?.setEventSink(events)

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_BATTERY_CHANGED)
            addAction("android.media.VOLUME_CHANGED_ACTION")
        }
        batteryReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                when (intent?.action) {
                    Intent.ACTION_BATTERY_CHANGED -> {
                        val lvl   = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                        val pct   = if (scale > 0) lvl * 100 / scale else -1
                        val st    = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
                        events?.success(mapOf(
                            "type"  to "battery",
                            "level" to pct,
                            "state" to batteryString(st)
                        ))
                    }
                    "android.media.VOLUME_CHANGED_ACTION" -> {
                        val am  = ctx?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                        val max = am?.getStreamMaxVolume(AudioManager.STREAM_MUSIC) ?: 15
                        val cur = am?.getStreamVolume(AudioManager.STREAM_MUSIC)    ?: 0
                        events?.success(mapOf(
                            "type"  to "volume",
                            "value" to if (max > 0) cur.toDouble() / max else 0.0
                        ))
                    }
                }
            }
        }
        // Android 13+ (API 33) нь RECEIVER_NOT_EXPORTED flag шаардлагатай.
        // Тэгэхгүй бол SecurityException гарна.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            appContext?.registerReceiver(
                batteryReceiver,
                filter,
                Context.RECEIVER_NOT_EXPORTED
            )
        } else {
            appContext?.registerReceiver(batteryReceiver, filter)
        }

    }

    override fun onCancel(arguments: Any?) {
        batteryReceiver?.let { appContext?.unregisterReceiver(it) }
        batteryReceiver = null
        eventSink = null
        exoManager?.setEventSink(null)
    }

    private fun batteryString(status: Int) = when (status) {
        BatteryManager.BATTERY_STATUS_CHARGING    -> "charging"
        BatteryManager.BATTERY_STATUS_FULL        -> "full"
        BatteryManager.BATTERY_STATUS_DISCHARGING -> "discharging"
        else                                       -> "unknown"
    }
}