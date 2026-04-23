# senzu_player

A powerful, feature-rich Flutter video player plugin built on top of **AVPlayer** (iOS) and **ExoPlayer / Media3** (Android).

[![pub version](https://img.shields.io/pub/v/senzu_player.svg)](https://pub.dev/packages/senzu_player)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android-blue)](https://pub.dev/packages/senzu_player)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Features

| Feature | iOS | Android |
|---|---|---|
| HLS / DASH / MP4 | ✅ | ✅ |
| FairPlay DRM | ✅ | — |
| Widevine DRM | — | ✅ |
| Picture-in-Picture | ✅ | ✅ (API 26+) |
| Now Playing / Lock Screen | ✅ | ✅ |
| Google Cast (Chromecast) | ✅ | ✅ |
| HDR playback | ✅ | ✅ |
| Low-latency live | ✅ | ✅ |
| Adaptive Bitrate (ABR) | ✅ | ✅ |
| Audio track selection | ✅ | ✅ |
| Subtitles (WebVTT / SRT) | ✅ | ✅ |
| Encrypted subtitles (AES-128-CBC) | ✅ | ✅ |
| Chapters & skip OP/ED | ✅ | ✅ |
| Annotations overlay | ✅ | ✅ |
| Watermark overlay | ✅ | ✅ |
| Sleep timer | ✅ | ✅ |
| Token / signed URL refresh | ✅ | ✅ |
| Cellular data warning | ✅ | ✅ |
| Thumbnail sprite preview | ✅ | ✅ |
| Fullscreen overlay | ✅ | ✅ |
| Secure mode (screenshot block) | ✅ | ✅ |
| Volume / brightness gesture | ✅ | ✅ |
| Long-press 2× speed | ✅ | ✅ |
| IMA / VAST ads | ✅ | ✅ |

---

## Installation

```yaml
dependencies:
  senzu_player: ^1.1.0
```

### iOS

Minimum iOS version: **15.0**

Add the following to your `Info.plist`:

```xml
<!-- Background audio -->
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
  <string>airplay</string>
</array>

<!-- Allow HTTP (if needed) -->
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>

<!-- Google Cast -->
<key>NSBonjourServices</key>
<array>
	<string>_CC1AD845._googlecast._tcp</string>
	<string>_googlecast._tcp</string>
</array>
```

Add to `Podfile`:

```ruby
platform :ios, '15.0'
```

### Android

Minimum SDK: **21**

Add to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />

<!-- Inside <application> — required for Google Cast -->
<meta-data
    android:name="com.google.android.gms.cast.framework.OPTIONS_PROVIDER_CLASS_NAME"
    android:value="dev.senzu.senzu_player.SenzuCastOptionsProvider" />
```

Add to `android/app/build.gradle`:

```groovy
android {
    compileOptions {
        coreLibraryDesugaringEnabled true
    }
}

dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.5'
}
```

---

## Basic Usage

```dart
import 'package:senzu_player/senzu_player.dart';

// 1. Create a bundle (hold it in your State or controller)
final bundle = SenzuPlayerBundle.create();

// 2. Pass it to SenzuPlayer
SenzuPlayer(
  bundle: bundle,
  source: {
    'Auto': VideoSource.fromUrl('https://example.com/stream.m3u8'),
  },
)

// 3. Dispose when done
@override
void dispose() {
  bundle.dispose();
  super.dispose();
}
```

> **Important:** `SenzuPlayer` requires an explicit `bundle` parameter. Create it with
> `SenzuPlayerBundle.create()` and call `bundle.dispose()` yourself when the widget is
> removed from the tree.

### Multiple quality sources

```dart
SenzuPlayer(
  bundle: bundle,
  source: {
    '1080p': VideoSource.fromUrl('https://example.com/1080p.m3u8'),
    '720p':  VideoSource.fromUrl('https://example.com/720p.m3u8'),
    '480p':  VideoSource.fromUrl('https://example.com/480p.m3u8'),
  },
  defaultAspectRatio: 16 / 9,
)
```

### Auto-parse quality from M3U8 playlist

```dart
final sources = await VideoSource.fromM3u8PlaylistUrl(
  'https://example.com/master.m3u8',
  autoSubtitle: true,       // automatically parse subtitle tracks from the playlist
  initialSubtitleLang: 'en',
);

SenzuPlayer(bundle: bundle, source: sources)
```

---

## Advanced Usage

### DRM

**FairPlay (iOS)**

```dart
VideoSource.fromUrl(
  'https://example.com/stream.m3u8',
  drm: SenzuDrmConfig.fairPlay(
    licenseUrl:     'https://license.example.com/fps',
    certificateUrl: 'https://license.example.com/cert',
    headers: {'Authorization': 'Bearer token'},
  ),
)
```

**Widevine (Android)**

```dart
VideoSource.fromDashUrl(
  'https://example.com/stream.mpd',
  drm: SenzuDrmConfig.widevine(
    licenseUrl: 'https://license.example.com/widevine',
    headers: {'Authorization': 'Bearer token'},
  ),
)
```

---

### Subtitles

```dart
VideoSource.fromUrl(
  'https://example.com/stream.m3u8',
  subtitle: {
    'English':   SenzuPlayerSubtitle.network('https://example.com/en.vtt'),
    'Mongolian': SenzuPlayerSubtitle.network('https://example.com/mn.vtt'),
  },
  initialSubtitle: 'English',
)
```

**Encrypted subtitles (AES-128-CBC)**

```dart
SenzuPlayerSubtitle.decrypt(
  'https://example.com/encrypted.vtt',
  keyHex: 'aabbccddeeff00112233445566778899',
  ivHex:  '00112233445566778899aabbccddeeff',
)
```

---

### Chapters (Skip OP / ED)

```dart
SenzuPlayer(
  bundle: bundle,
  source: sources,
  chapters: SenzuChapter.fromSkipRanges(
    opStart: const Duration(seconds: 5),
    opEnd:   const Duration(seconds: 95),
    edStart: const Duration(minutes: 22),
    edEnd:   const Duration(minutes: 23, seconds: 30),
  ),
)
```

Or define chapters manually:

```dart
chapters: [
  SenzuChapter(startMs: 0,       title: 'Intro'),
  SenzuChapter(startMs: 5000,    title: 'OP',      isSkippable: true, skipToMs: 95000),
  SenzuChapter(startMs: 95000,   title: 'Episode'),
  SenzuChapter(startMs: 1320000, title: 'ED',      isSkippable: true, skipToMs: 1410000),
]
```

`SenzuChapter` fields:

| Field | Type | Description |
|---|---|---|
| `startMs` | `int` | Chapter start time in milliseconds |
| `title` | `String` | Label shown on progress bar and panels. Empty string = marker only, no label |
| `showOnProgressBar` | `bool` | Whether to draw a marker on the progress bar (default `true`) |
| `isSkippable` | `bool` | Whether to show a Skip button while playback is inside this chapter |
| `skipToMs` | `int?` | Target position when Skip is tapped. Defaults to next chapter's `startMs` |

---

### Ads

**Custom inline ads**

```dart
VideoSource.fromUrl(
  'https://example.com/stream.m3u8',
  ads: [
    SenzuPlayerAd(
      child: MyAdWidget(),
      durationToSkip: const Duration(seconds: 5),
      deepLink: 'https://advertiser.example.com',
      durationToStart: const Duration(seconds: 0), // pre-roll
    ),
    SenzuPlayerAd(
      child: MyMidrollAdWidget(),
      durationToSkip: const Duration(seconds: 5),
      deepLink: 'https://advertiser.example.com',
      fractionToStart: 0.5, // mid-roll at 50%
    ),
  ],
)
```

> Exactly one of `durationToStart` or `fractionToStart` must be set.

**Google IMA / VAST**

```dart
SenzuPlayer(
  bundle: bundle,
  source: sources,
  imaAdTagUrl: 'https://pubads.g.doubleclick.net/gampad/ads?...',
)
```

---

### Google Cast (Chromecast)

```dart
// 1. Create controller

// Use the default Cast application ID or your custom one
final castController = SenzuCastController(appId: SenzuCastController.kDefaultApplicationId);

// 2. Pass to SenzuPlayer
SenzuPlayer(
  bundle: bundle,
  source: sources,
  castController: castController,
  meta: SenzuMetaData(
    title:       'My Video',
    description: 'Episode 1',
    posterUrl:   'https://example.com/poster.jpg',
  ),
)
```

The cast button appears automatically in the top controls. Tapping it opens a device picker
panel. Once connected, playback transfers seamlessly to the Chromecast receiver and returns to
local playback when disconnected.

**Custom cast media with subtitles and quality switching**

```dart
await castController.switchToCast(
  media: SenzuCastMedia(
    url:         'https://example.com/stream.m3u8',
    title:       'My Video',
    description: 'Episode 1',
    posterUrl:   'https://example.com/poster.jpg',
    isLive:      false,
    positionMs:  30000,
    availableSubtitles: [
      CastSubtitleTrack(id: 1001, language: 'en', name: 'English',   url: 'https://example.com/en.vtt'),
      CastSubtitleTrack(id: 1002, language: 'mn', name: 'Mongolian', url: 'https://example.com/mn.vtt'),
    ],
    availableAudioTracks: [
      CastAudioTrack(id: 2001, language: 'en', name: 'English'),
      CastAudioTrack(id: 2002, language: 'ja', name: 'Japanese'),
    ],
    availableQualities: [
      CastQualityOption(label: '1080p', url: 'https://example.com/1080p.m3u8'),
      CastQualityOption(label: '720p',  url: 'https://example.com/720p.m3u8'),
    ],
    selectedSubtitleId: 1001,
  ),
  currentPosition: Duration(seconds: 30),
);
```

---

### Watermark

```dart
SenzuPlayer(
  bundle: bundle,
  source: sources,
  // Passed through SenzuPlayerBundle.create()
)

// In SenzuPlayerBundle.create():
final bundle = SenzuPlayerBundle.create(
  watermark: SenzuWatermark(
    userId:        'user_123',
    customText:    'CONFIDENTIAL',
    showTimestamp: true,
    showUserId:    true,
    opacity:       0.18,
    fontSize:      13.0,
    position:      WatermarkPosition.random,
    moveDuration:  Duration(seconds: 30),
  ),
);
```

`WatermarkPosition` values: `topLeft`, `topRight`, `bottomLeft`, `bottomRight`, `center`, `random`

---

### Annotations

```dart
final bundle = SenzuPlayerBundle.create(
  annotations: [
    SenzuAnnotation(
      id:          'promo_1',
      text:        '🎁 Special offer!',
      appearAt:    Duration(seconds: 30),
      disappearAt: Duration(seconds: 40),
      alignment:   Alignment.topRight,
      onTap:       () => launchUrl(Uri.parse('https://example.com')),
    ),
  ],
);
```

---

### Token / Signed URL Refresh

```dart
final bundle = SenzuPlayerBundle.create(
  tokenConfig: SenzuTokenConfig(
    refreshBeforeExpirySec: 60,
    tokenExpiryHeader:      'x-token-expiry',
    onRefresh: (sourceName, headers) async {
      final newUrl = await myApi.refreshSignedUrl(sourceName);
      return {
        'url':           newUrl,
        'Authorization': 'Bearer newtoken',
      };
    },
  ),
);
```

The manager reads the `exp`, `Expires`, or `expires` query parameter from the source URL and
schedules a refresh `refreshBeforeExpirySec` seconds before expiry.

---

### Thumbnail Sprite Preview

```dart
VideoSource.fromUrl(
  'https://example.com/stream.m3u8',
  thumbnailSprite: SenzuThumbnailSprite(
    url:         'https://example.com/thumbnails.jpg',
    columns:     10,
    rows:        10,
    intervalSec: 10,
  ),
)
```

While the user scrubs the progress bar, the corresponding frame from the sprite sheet is shown
above the progress bar. If no sprite is configured a simple time tooltip is shown instead.

---

### Cellular Data Policy

```dart
final bundle = SenzuPlayerBundle.create(
  dataPolicy: SenzuDataPolicy(
    warnOnCellular:      true,   // show warning dialog on cellular
    dataSaverOnCellular: true,   // auto-switch to lowest quality on cellular
    dataSaverQualityKey: '480p', // key in your sources map (null = last key)
  ),
);
```

---

### Controlling playback externally

```dart
final bundle = SenzuPlayerBundle.create();

SenzuPlayer(bundle: bundle, source: sources)

// Playback control
bundle.core.play();
bundle.core.pause();
bundle.core.playOrPause();
bundle.core.seekTo(const Duration(minutes: 5));
bundle.core.setPlaybackSpeed(1.5);
bundle.core.retrySource();
bundle.core.goToLiveEdge();

// Observe state
Obx(() => Text(
  bundle.playback.isPlaying.value ? 'Playing' : 'Paused',
));

// Change source programmatically
bundle.core.changeSource(
  name:   '720p',
  source: VideoSource.fromUrl('https://example.com/720p.m3u8'),
  inheritPosition: true,
);
```

---

### Fullscreen

Fullscreen is managed internally via a Flutter `Overlay`. When the user taps the fullscreen
button, the player renders into a full-screen overlay and applies landscape orientation +
immersive sticky UI mode automatically. The overlay is removed when the user exits fullscreen.

```dart
// Toggle programmatically
bundle.core.openOrCloseFullscreen();

// Close and pop (e.g. from the back button in the top bar)
bundle.core.closeFullscreen(context);

// Observe
Obx(() => Text(bundle.core.isFullScreen.value ? 'Fullscreen' : 'Inline'));
```

---

### Localization

```dart
SenzuPlayer(
  bundle: bundle,
  source: sources,
  style: SenzuPlayerStyle(
    senzuLanguage: SenzuLanguage(
      live:                 'LIVE',
      quality:              'Quality',
      subtitles:            'Subtitles',
      audio:                'Audio',
      playbackSpeed:        'Playback speed',
      etc ...
    ),
  ),
)
```

---

### Custom UI style

```dart
SenzuPlayerStyle(
  progressBarStyle: SenzuProgressBarStyle(
    height:          4.0,
    dotSize:         6.0,
    color:           Colors.red,
    bufferedColor:   Colors.white38,
    backgroundColor: Colors.white24,
    dotColor:        Colors.white,
    tooltipBgColor:  Colors.black87,
  ),
  subtitleStyle: SenzuSubtitleStyle(
    textStyle: const TextStyle(
      color:           Colors.white,
      fontSize:        16,
      backgroundColor: Colors.black54,
    ),
    alignment: Alignment.bottomCenter,
    padding:   const EdgeInsets.only(bottom: 8),
  ),
  centerButtonStyle: SenzuCenterButtonStyle(
    circleSize:  60.0,
    circleColor: const Color(0x4D000000),
  ),
  thumbnail:     MyThumbnailWidget(),
  bottomExtra:   MyCustomBottomWidget(),
  episodeWidget: MyEpisodeListWidget(),
  onPrevEpisode: () => loadPrevEpisode(),
  onNextEpisode: () => loadNextEpisode(),
  hasPrevEpisode: currentIndex > 0,
  hasNextEpisode: currentIndex < totalEpisodes - 1,
)
```

---

## SenzuPlayer Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `bundle` | `SenzuPlayerBundle` | **required** | Controller bundle created with `SenzuPlayerBundle.create()` |
| `source` | `Map<String, VideoSource>` | **required** | Video sources keyed by quality label |
| `seekTo` | `Duration` | `Duration.zero` | Initial seek position |
| `autoPlay` | `bool` | `false` | Auto-start playback after initialization |
| `isLive` | `bool?` | `null` | Force live stream mode (overrides native duration heuristic) |
| `style` | `SenzuPlayerStyle?` | default | UI style configuration |
| `meta` | `SenzuMetaData?` | default | Title/description/poster metadata shown in top bar and cast |
| `chapters` | `List<SenzuChapter>` | `[]` | Chapter markers on progress bar |
| `defaultAspectRatio` | `double` | `16/9` | Player aspect ratio |
| `enableFullscreen` | `bool` | `true` | Show fullscreen button |
| `enableCaption` | `bool` | `true` | Show subtitle panel button |
| `enableQuality` | `bool` | `true` | Show quality panel button |
| `enableAudio` | `bool` | `false` | Show audio track panel button |
| `enableSpeed` | `bool` | `true` | Show playback speed panel button |
| `enableAspect` | `bool` | `true` | Show aspect ratio panel button |
| `enableLock` | `bool` | `true` | Show screen lock button |
| `enablePip` | `bool` | `true` | Enable Picture-in-Picture button |
| `enableSleep` | `bool` | `true` | Show sleep timer panel button |
| `enableEpisode` | `bool` | `true` | Show episode panel button (requires `style.episodeWidget`) |
| `imaAdTagUrl` | `String?` | `null` | Google IMA VAST ad tag URL |
| `castController` | `SenzuCastController?` | `null` | Google Cast controller |

## SenzuPlayerBundle.create() Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `looping` | `bool` | `false` | Loop playback |
| `adaptiveBitrate` | `bool` | `false` | Auto quality switching based on buffer health |
| `minBufferSec` | `int` | `0` | Minimum buffer threshold for ABR downgrade |
| `maxBufferSec` | `int` | `30` | Maximum buffer threshold for ABR upgrade |
| `secureMode` | `bool` | `false` | Block screenshots and screen recording |
| `notification` | `bool` | `true` | Show Now Playing / lock screen controls |
| `watermark` | `SenzuWatermark?` | `null` | Floating watermark overlay |
| `onQualityChanged` | `void Function(String)?` | `null` | Callback when ABR switches quality |
| `dataPolicy` | `SenzuDataPolicy` | default | Cellular data warning / data-saver behavior |
| `tokenConfig` | `SenzuTokenConfig?` | `null` | Signed URL / token auto-refresh |
| `annotations` | `List<SenzuAnnotation>` | `[]` | Tappable overlay annotations |

---

## VideoSource constructors

| Constructor | Description |
|---|---|
| `VideoSource.fromUrl(url)` | HLS stream (default) |
| `VideoSource.fromDashUrl(url)` | MPEG-DASH stream |
| `VideoSource.fromFile(path)` | Local MP4 file |
| `VideoSource.fromNetworkVideoSources(map)` | Build a quality map from URL strings |
| `VideoSource.fromM3u8PlaylistUrl(url)` | Parse quality variants from a master playlist |

---

## Requirements

| Platform | Minimum version |
|---|---|
| iOS | 15.0 |
| Android | API 21 (Android 5.0) |
| Flutter | 3.41.0 |
| Dart | 3.8.0 |

---

## License

MIT License — see [LICENSE](LICENSE) for details.