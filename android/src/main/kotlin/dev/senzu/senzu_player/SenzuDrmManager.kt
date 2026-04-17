package dev.senzu.senzu_player

import android.content.Context
import android.net.Uri
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.drm.DefaultDrmSessionManager
import androidx.media3.exoplayer.drm.DrmSessionManager
import androidx.media3.exoplayer.drm.FrameworkMediaDrm
import androidx.media3.exoplayer.drm.HttpMediaDrmCallback
import java.util.UUID

// ─────────────────────────────────────────────────────────────────────────────
// SenzuWidevineConfig  —  Dart-аас дамжуулах DRM тохиргоо
// ─────────────────────────────────────────────────────────────────────────────

data class SenzuWidevineConfig(
    val licenseUrl: String,
    val headers: Map<String, String> = emptyMap()
) {
    companion object {
        fun from(args: Map<*, *>?): SenzuWidevineConfig? {
            val drm = args?.get("drm") as? Map<*, *> ?: return null
            val licenseUrl = drm["licenseUrl"] as? String ?: return null
            @Suppress("UNCHECKED_CAST")
            val headers = (drm["headers"] as? Map<String, String>) ?: emptyMap()
            return SenzuWidevineConfig(licenseUrl = licenseUrl, headers = headers)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// SenzuDrmManager  —  Widevine DrmSessionManager builder
// ─────────────────────────────────────────────────────────────────────────────

@UnstableApi
object SenzuDrmManager {

    private val WIDEVINE_UUID: UUID = UUID.fromString("edef8ba9-79d6-4ace-a3c8-27dcd51d21ed")

    /**
     * Widevine DRM тохиргооноос DrmSessionManager үүсгэнэ.
     * ExoPlayer.Builder-д шууд дамжуулна.
     *
     * @param config  Dart-аас ирсэн DRM тохиргоо
     * @return        DrmSessionManager эсвэл DrmSessionManager.DRM_UNSUPPORTED
     */
    fun build(config: SenzuWidevineConfig): DrmSessionManager {
        val dataSourceFactory = DefaultHttpDataSource.Factory()
            .setDefaultRequestProperties(config.headers)
            .setConnectTimeoutMs(15_000)
            .setReadTimeoutMs(15_000)

        val drmCallback = HttpMediaDrmCallback(
            config.licenseUrl,
            dataSourceFactory
        )

        // Custom header-уудыг DRM request-д нэмнэ
        config.headers.forEach { (key, value) ->
            drmCallback.setKeyRequestProperty(key, value)
        }

        return DefaultDrmSessionManager.Builder()
            .setUuidAndExoMediaDrmProvider(WIDEVINE_UUID, FrameworkMediaDrm.DEFAULT_PROVIDER)
            .setMultiSession(false)
            .build(drmCallback)
    }

    /**
     * Widevine DRM-тэй MediaItem үүсгэнэ.
     */
    fun buildMediaItem(url: String, config: SenzuWidevineConfig): MediaItem {
        return MediaItem.Builder()
            .setUri(Uri.parse(url))
            .setDrmConfiguration(
                MediaItem.DrmConfiguration.Builder(WIDEVINE_UUID)
                    .setLicenseUri(config.licenseUrl)
                    .setLicenseRequestHeaders(config.headers)
                    .build()
            )
            .build()
    }

    /**
     * Widevine-г энэ төхөөрөмж дэмжиж байгаа эсэхийг шалгана.
     */
    fun isWidevineSupported(): Boolean {
        return try {
            FrameworkMediaDrm.DEFAULT_PROVIDER.acquireExoMediaDrm(WIDEVINE_UUID) != null
        } catch (e: Exception) {
            false
        }
    }
}