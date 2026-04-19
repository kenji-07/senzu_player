package dev.senzu.senzu_player

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
// SenzuWidevineConfig — DRM configuration passed from Dart layer
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Holds Widevine DRM configuration received from the Dart side.
 *
 * @property licenseUrl  URL of the Widevine license server.
 * @property headers     Optional HTTP headers to include in license requests.
 */
data class SenzuWidevineConfig(
    val licenseUrl: String,
    val headers: Map<String, String> = emptyMap()
) {
    companion object {
        /**
         * Parses a [SenzuWidevineConfig] from a raw method-channel argument map.
         * Returns null if the required fields are absent.
         */
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
// SenzuDrmManager — Widevine DrmSessionManager builder
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Singleton that builds Widevine [DrmSessionManager] instances and
 * constructs DRM-aware [MediaItem] objects for ExoPlayer.
 */
@UnstableApi
object SenzuDrmManager {

    private val WIDEVINE_UUID: UUID = UUID.fromString("edef8ba9-79d6-4ace-a3c8-27dcd51d21ed")

    /**
     * Builds a [DrmSessionManager] from the given Widevine config.
     * Pass the result directly to [ExoPlayer.Builder].
     *
     * @param config  Widevine configuration received from Dart.
     * @return        A configured [DefaultDrmSessionManager].
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

        // Attach custom headers to every DRM key request
        config.headers.forEach { (key, value) ->
            drmCallback.setKeyRequestProperty(key, value)
        }

        return DefaultDrmSessionManager.Builder()
            .setUuidAndExoMediaDrmProvider(WIDEVINE_UUID, FrameworkMediaDrm.DEFAULT_PROVIDER)
            .setMultiSession(false)
            .build(drmCallback)
    }

    /**
     * Builds a DRM-configured [MediaItem] for the given URL and Widevine config.
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
     * Returns true if Widevine DRM is supported on this device.
     */
    fun isWidevineSupported(): Boolean {
        return try {
            FrameworkMediaDrm.DEFAULT_PROVIDER.acquireExoMediaDrm(WIDEVINE_UUID) != null
        } catch (e: Exception) {
            false
        }
    }
}