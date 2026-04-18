package dev.senzu.senzu_player

import android.content.Context
import com.google.android.gms.cast.framework.CastOptions
import com.google.android.gms.cast.framework.OptionsProvider
import com.google.android.gms.cast.framework.SessionProvider

class SenzuCastOptionsProvider : OptionsProvider {
    override fun getCastOptions(context: Context): CastOptions {
        return CastOptions.Builder()
            // Default Media Receiver App ID — өөрийн Receiver бол солих
            // Google Cast Developer Console-с авна: https://cast.google.com/u/0/publish
            .setReceiverApplicationId("CC1AD845")
            .build()
    }

    override fun getAdditionalSessionProviders(context: Context):
        List<SessionProvider>? = null
}