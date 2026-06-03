package dev.senzu.senzu_player

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.cache.NoOpCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import androidx.media3.exoplayer.offline.DefaultDownloaderFactory
import androidx.media3.exoplayer.offline.Download
import androidx.media3.exoplayer.offline.DownloadHelper
import androidx.media3.exoplayer.offline.DownloadManager
import androidx.media3.exoplayer.offline.DownloadRequest
import androidx.media3.exoplayer.offline.DownloadService
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors

@UnstableApi
object SenzuDownloadManager : EventChannel.StreamHandler {

    private var downloadManager: DownloadManager? = null
    private var databaseProvider: StandaloneDatabaseProvider? = null
    private var downloadCache: SimpleCache? = null
    private var eventSink: EventChannel.EventSink? = null

    private var downloadCompleteTitle = "Таталт амжилттай"
    private var downloadCompleteBody = "Видеог офлайн горимд үзэх боломжтой боллоо."
    private var downloadFailedTitle = "Таталт амжилтгүй"
    private var downloadFailedBody = "Видеог татахад алдаа гарлаа."
    private var licenseExpiredTitle = "Лиценз дууссан"
    private var licenseExpiredBody = "Офлайн лицензийн хугацаа дууссан байна."

    fun setNotificationLocales(
        completeTitle: String, completeBody: String,
        failedTitle: String, failedBody: String,
        expiredTitle: String, expiredBody: String
    ) {
        if (completeTitle.isNotEmpty()) downloadCompleteTitle = completeTitle
        if (completeBody.isNotEmpty()) downloadCompleteBody = completeBody
        if (failedTitle.isNotEmpty()) downloadFailedTitle = failedTitle
        if (failedBody.isNotEmpty()) downloadFailedBody = failedBody
        if (expiredTitle.isNotEmpty()) licenseExpiredTitle = expiredTitle
        if (expiredBody.isNotEmpty()) licenseExpiredBody = expiredBody
    }

    @Synchronized
    fun getDownloadCache(context: Context): SimpleCache? {
        getDownloadManager(context.applicationContext)
        return downloadCache
    }

    @Synchronized
    fun getDownloadManager(context: Context): DownloadManager {
        if (downloadManager == null) {
            val appCtx = context.applicationContext
            databaseProvider = StandaloneDatabaseProvider(appCtx)
            val downloadDirectory = File(appCtx.filesDir, "downloads")
            downloadCache = SimpleCache(
                downloadDirectory,
                NoOpCacheEvictor(),
                databaseProvider!!
            )
            val dataSourceFactory = DefaultHttpDataSource.Factory()
            downloadManager = DownloadManager(
                appCtx,
                databaseProvider!!,
                downloadCache!!,
                dataSourceFactory,
                Executors.newSingleThreadExecutor()
            ).apply {
                maxParallelDownloads = 3
                addListener(object : DownloadManager.Listener {
                    override fun onDownloadChanged(
                        dm: DownloadManager,
                        download: Download,
                        finalException: java.lang.Exception?
                    ) {
                        val status = when (download.state) {
                            Download.STATE_QUEUED -> "queued"
                            Download.STATE_DOWNLOADING -> "downloading"
                            Download.STATE_COMPLETED -> "completed"
                            Download.STATE_FAILED -> "failed"
                            Download.STATE_REMOVING -> "paused"
                            Download.STATE_STOPPED -> "paused"
                            else -> "queued"
                        }
                        
                        val progress = download.percentDownloaded
                        val progressVal = if (progress == C.PERCENTAGE_UNSET.toFloat()) 0.0 else progress.toDouble()
                        val bytesDownloaded = download.getBytesDownloaded()
                        val totalBytes = download.contentLength

                        val result = mapOf(
                            "id" to download.request.id,
                            "progress" to progressVal,
                            "status" to status,
                            "localPath" to "offline_media://${download.request.id}",
                            "bytesDownloaded" to bytesDownloaded,
                            "totalBytes" to totalBytes
                        )
                        
                        Handler(Looper.getMainLooper()).post {
                            eventSink?.success(result)
                        }

                        // Send system notification for completion or failure
                        if (download.state == Download.STATE_COMPLETED) {
                            sendNotification(appCtx, download.request.id, downloadCompleteTitle, downloadCompleteBody)
                        } else if (download.state == Download.STATE_FAILED) {
                            val errMsg = finalException?.message ?: ""
                            val body = if (errMsg.isNotEmpty()) "$downloadFailedBody: $errMsg" else downloadFailedBody
                            sendNotification(appCtx, download.request.id, downloadFailedTitle, body)
                        }
                    }
                })
            }
        }
        return downloadManager!!
    }

    fun startDownload(
        context: Context,
        id: String,
        url: String,
        headers: Map<String, String>,
        drmConfig: Map<String, Any>,
        title: String
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && context is android.app.Activity) {
            requestNotificationPermission(context)
        }
        val appCtx = context.applicationContext
        val dm = getDownloadManager(appCtx)

        val mediaItemBuilder = MediaItem.Builder()
            .setUri(Uri.parse(url))
            .setMediaId(id)

        // DRM Configuration
        val licenseUrl = drmConfig["licenseUrl"] as? String
        if (licenseUrl != null) {
            mediaItemBuilder.setDrmConfiguration(
                MediaItem.DrmConfiguration.Builder(C.WIDEVINE_UUID)
                    .setLicenseUri(Uri.parse(licenseUrl))
                    .build()
            )
        }

        val mediaItem = mediaItemBuilder.build()

        // HLS or progressive downloader helper
        val helper = DownloadHelper.forMediaItem(
            appCtx,
            mediaItem,
            DefaultDownloaderFactory(downloadCache!!, DefaultHttpDataSource.Factory()),
            null
        )

        helper.prepare(object : DownloadHelper.Callback {
            override fun onPrepared(helper: DownloadHelper) {
                // By default select all tracks or first representation
                val request = helper.getDownloadRequest(id, null)
                DownloadService.sendAddDownload(
                    appCtx,
                    SenzuDownloadService::class.java,
                    request,
                    /* foreground= */ true
                )
            }

            override fun onPrepareError(helper: DownloadHelper, e: IOException) {
                // If it fails to prepare (e.g. progressive video not parsing as HLS), download directly
                val request = DownloadRequest.Builder(id, Uri.parse(url)).build()
                DownloadService.sendAddDownload(
                    appCtx,
                    SenzuDownloadService::class.java,
                    request,
                    /* foreground= */ true
                )
            }
        })
    }

    fun pauseDownload(context: Context, id: String) {
        val dm = getDownloadManager(context)
        dm.setStopReason(id, Download.STOP_REASON_NONE) // Stop the download
    }

    fun resumeDownload(context: Context, id: String) {
        val dm = getDownloadManager(context)
        dm.setStopReason(id, 0) // Resume the download
    }

    fun cancelDownload(context: Context, id: String) {
        DownloadService.sendRemoveDownload(
            context,
            SenzuDownloadService::class.java,
            id,
            /* foreground= */ false
        )
    }

    fun deleteDownload(context: Context, id: String) {
        cancelDownload(context, id)
    }

    fun notifyLicenseExpired(context: Context, id: String, title: String) {
        val body = if (title.isNotEmpty()) "\"$title\" $licenseExpiredBody" else licenseExpiredBody
        sendNotification(context, id, licenseExpiredTitle, body)
    }

    fun requestNotificationPermission(activity: android.app.Activity?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && activity != null) {
            val hasPermission = androidx.core.content.ContextCompat.checkSelfPermission(
                activity,
                android.Manifest.permission.POST_NOTIFICATIONS
            ) == android.content.pm.PackageManager.PERMISSION_GRANTED
            if (!hasPermission) {
                androidx.core.ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                    102
                )
            }
        }
    }

    fun sendNotification(context: Context, id: String, title: String, message: String) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "senzu_alerts_channel",
                "Senzu Alerts",
                NotificationManager.IMPORTANCE_HIGH
            )
            notificationManager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(context, "senzu_alerts_channel")
            .setSmallIcon(R.drawable.ic_download_notification)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(id.hashCode(), notification)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
