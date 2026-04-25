# senzu_player

A powerful, feature-rich Flutter video player plugin built on top of **AVPlayer** (iOS) and **ExoPlayer / Media3** (Android). Supports both **mobile** and **Android TV / Apple TV** platforms.

[![pub version](https://img.shields.io/pub/v/senzu_player.svg)](https://pub.dev/packages/senzu_player)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android%20%7C%20TV-blue)](https://pub.dev/packages/senzu_player)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Features

| Feature | iOS | Android | TV |
|---|---|---|---|
| HLS / DASH / MP4 | ✅ | ✅ | ✅ |
| FairPlay DRM | ✅ | — | ✅ |
| Widevine DRM | — | ✅ | ✅ |
| Picture-in-Picture | ✅ | ✅ (API 26+) | — |
| Now Playing / Lock Screen | ✅ | ✅ | ✅ |
| Google Cast (Chromecast) | ✅ | ✅ | — |
| HDR playback | ✅ | ✅ | ✅ |
| Low-latency live | ✅ | ✅ | ✅ |
| Adaptive Bitrate (ABR) | ✅ | ✅ | ✅ |
| Audio track selection | ✅ | ✅ | ✅ |
| Subtitles (WebVTT / SRT) | ✅ | ✅ | ✅ |
| Encrypted subtitles (AES-128-CBC) | ✅ | ✅ | ✅ |
| Chapters & skip OP/ED | ✅ | ✅ | - |
| Annotations overlay | ✅ | ✅ | — |
| Watermark overlay | ✅ | ✅ | ✅ |
| Sleep timer | ✅ | ✅ | — |
| Token / signed URL refresh | ✅ | ✅ | ✅ |
| Cellular data warning | ✅ | ✅ | — |
| Thumbnail sprite preview | ✅ | ✅ | ✅ |
| Fullscreen overlay | ✅ | ✅ | ✅ |
| Secure mode (screenshot block) | ✅ | ✅ | ✅ |
| Volume / brightness gesture | ✅ | ✅ | — |
| Long-press 2× speed | ✅ | ✅ | — |
| IMA / VAST ads | ✅ | ✅ | — |
| D-pad / remote navigation | — | — | ✅ |
| TV focus ring & zoom animation | — | — | ✅ |

---

## Installation

```yaml
dependencies:
  senzu_player: ^1.1.1
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

### Android TV

For Android TV support, add the Leanback launcher category to your `AndroidManifest.xml`:

```xml
<uses-feature android:name="android.software.leanback" android:required="false" />
<uses-feature android:name="android.hardware.touchscreen" android:required="false" />

<activity
    android:name=".MainActivity"
    android:screenOrientation="landscape"
    android:supportsPictureInPicture="true">
    <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
        <category android:name="android.intent.category.LEANBACK_LAUNCHER" />
    </intent-filter>
</activity>
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

---

## Platform-specific Setup

### Mobile (iOS & Android)

Mobile mode is the default. It provides touch-based controls, gesture volume/brightness,
long-press 2× speed, fullscreen overlay, lock screen, PiP, sleep timer, cellular warning,
annotations, and ad support.

```dart
SenzuPlayer(
  bundle: bundle,
  source: sources,
  // Mobile-specific options
  enableFullscreen: true,   // fullscreen overlay with orientation lock
  enableLock: true,         // screen lock button
  enablePip: true,          // picture-in-picture button
  enableSleep: true,        // sleep timer panel
  defaultAspectRatio: 16 / 9,
)
```

**Gesture controls (mobile only)**

In fullscreen mode, swiping up/down on the left half of the screen controls brightness,
and swiping up/down on the right half controls volume. Long-pressing the center area
activates 2× speed playback.

---

### TV (Android TV / Apple TV)

Pass `isTv: true` to switch to the TV-optimized layout. The player automatically enters
fullscreen and locks orientation to landscape. All controls are navigable with a D-pad or
remote control.

```dart
SenzuPlayer(
  bundle: SenzuPlayerBundle.create(
    looping: true,
    notification: true,
  ),
  source: sources,
  isTv: true,             // ← enables TV mode
  autoPlay: true,
  enableFullscreen: false, // TV mode is always fullscreen, disable the toggle button
  enableLock: false,       // no touch lock needed on TV
  enablePip: false,        // PiP not applicable on TV
  enableSleep: false,      // sleep timer not needed on TV
  enableCaption: true,
  enableQuality: true,
  enableSpeed: true,
  enableAspect: true,
  enableEpisode: true,
  enableAudio: true,
)
```

**TV remote / D-pad key mapping**

| Key | Overlay hidden | Overlay visible |
|---|---|---|
| **Select / Enter** | Play / Pause | Activate focused button |
| **←** | Seek −10 s | Move focus left |
| **→** | Seek +10 s | Move focus right |
| **↑** | Show overlay → bottom bar | Move focus zone up (bottom → center → top) |
| **↓** | Show overlay → bottom bar | Move focus zone down (top → center → bottom) |
| **Back / Escape** | Pop screen | Close panel or hide overlay |
| **Media Play** | Play | — |
| **Media Pause** | Pause | — |

**TV focus zones**

The TV UI is divided into three vertical focus zones. Focus moves between them with ↑/↓.

- **Top zone** — title, aspect ratio, speed, caption, quality, audio buttons
- **Center zone** — play/pause circle button
- **Bottom zone** — episode button, seek progress bar

The progress bar in the bottom zone accepts ←/→ for 10-second seek with optimistic UI
(the bar moves immediately before the native player seeks).


---

## Multiple Quality Sources

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
  autoSubtitle: true,
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

On TV, chapter haptic feedback is replaced by a visual highlight on the progress bar dot.
Skip buttons are shown as overlay buttons above the progress bar on both mobile and TV.

---

### Ads (Mobile only)

**Custom inline ads**

```dart
VideoSource.fromUrl(
  'https://example.com/stream.m3u8',
  ads: [
    SenzuPlayerAd(
      child: MyAdWidget(),
      durationToSkip: const Duration(seconds: 5),
      deepLink: 'https://advertiser.example.com',
      durationToStart: const Duration(seconds: 0),
    ),
    SenzuPlayerAd(
      child: MyMidrollAdWidget(),
      durationToSkip: const Duration(seconds: 5),
      deepLink: 'https://advertiser.example.com',
      fractionToStart: 0.5,
    ),
  ],
)
```

> Exactly one of `durationToStart` or `fractionToStart` must be set.

**Google IMA / VAST (Mobile only)**

```dart
SenzuPlayer(
  bundle: bundle,
  source: sources,
  imaAdTagUrl: 'https://pubads.g.doubleclick.net/gampad/ads?...',
)
```

---

### Google Cast (Chromecast) — Mobile only

```dart
final castController = SenzuCastController(
  appId: SenzuCastController.kDefaultApplicationId,
);

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

### Annotations (Mobile only)

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

On mobile, the sprite is shown above the progress bar while scrubbing.
On TV, the sprite appears above the seek dot while navigating with ←/→.

---

### Cellular Data Policy (Mobile only)

```dart
final bundle = SenzuPlayerBundle.create(
  dataPolicy: SenzuDataPolicy(
    warnOnCellular:      true,
    dataSaverOnCellular: true,
    dataSaverQualityKey: '480p',
  ),
);
```

---

### Controlling Playback Externally

```dart
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

// Skip OP / ED (works on both mobile and TV)
bundle.ui.skipOp();
bundle.ui.skipEd();
```

---

### Fullscreen

Fullscreen is managed internally via a Flutter `Overlay`. When the user taps the fullscreen
button, the player renders into a full-screen overlay and applies landscape orientation +
immersive sticky UI mode automatically.

```dart
bundle.core.openOrCloseFullscreen();
bundle.core.closeFullscreen(context);
bundle.core.openFullscreen();

Obx(() => Text(bundle.core.isFullScreen.value ? 'Fullscreen' : 'Inline'));
```

On TV, fullscreen is entered automatically — no button is needed.

---

### Localization

```dart
SenzuPlayer(
  bundle: bundle,
  source: sources,
  style: SenzuPlayerStyle(
    senzuLanguage: SenzuLanguage(
      live:          'LIVE',
      quality:       'Quality',
      subtitles:     'Subtitles',
      audio:         'Audio',
      playbackSpeed: 'Playback speed',
    ),
  ),
)
```

---

### Custom UI Style

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
| `bundle` | `SenzuPlayerBundle` | **required** | Controller bundle |
| `source` | `Map<String, VideoSource>` | **required** | Video sources keyed by quality label |
| `seekTo` | `Duration` | `Duration.zero` | Initial seek position |
| `autoPlay` | `bool` | `false` | Auto-start playback |
| `isTv` | `bool` | `false` | Enable TV / D-pad mode |
| `isLive` | `bool?` | `null` | Force live stream mode |
| `style` | `SenzuPlayerStyle?` | default | UI style configuration |
| `meta` | `SenzuMetaData?` | default | Title / description / poster |
| `chapters` | `List<SenzuChapter>` | `[]` | Chapter markers |
| `defaultAspectRatio` | `double` | `16/9` | Player aspect ratio |
| `enableFullscreen` | `bool` | `true` | Show fullscreen button (mobile) |
| `enableCaption` | `bool` | `true` | Show subtitle panel button |
| `enableQuality` | `bool` | `true` | Show quality panel button |
| `enableAudio` | `bool` | `false` | Show audio track panel button |
| `enableSpeed` | `bool` | `true` | Show playback speed panel button |
| `enableAspect` | `bool` | `true` | Show aspect ratio panel button |
| `enableLock` | `bool` | `true` | Show screen lock button (mobile) |
| `enablePip` | `bool` | `true` | Enable PiP button (mobile) |
| `enableSleep` | `bool` | `true` | Show sleep timer button (mobile) |
| `enableEpisode` | `bool` | `true` | Show episode panel button |
| `imaAdTagUrl` | `String?` | `null` | Google IMA VAST ad tag URL (mobile) |
| `castController` | `SenzuCastController?` | `null` | Google Cast controller (mobile) |

## SenzuPlayerBundle.create() Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `looping` | `bool` | `false` | Loop playback |
| `adaptiveBitrate` | `bool` | `false` | Auto quality switching based on buffer health |
| `minBufferSec` | `int` | `0` | Minimum buffer threshold for ABR downgrade |
| `maxBufferSec` | `int` | `30` | Maximum buffer threshold for ABR upgrade |
| `secureMode` | `bool` | `false` | Block screenshots (mobile) |
| `notification` | `bool` | `true` | Show Now Playing / lock screen controls |
| `watermark` | `SenzuWatermark?` | `null` | Floating watermark overlay |
| `onQualityChanged` | `void Function(String)?` | `null` | Callback when ABR switches quality |
| `dataPolicy` | `SenzuDataPolicy` | default | Cellular data warning / data-saver (mobile) |
| `tokenConfig` | `SenzuTokenConfig?` | `null` | Signed URL / token auto-refresh |
| `annotations` | `List<SenzuAnnotation>` | `[]` | Tappable overlay annotations (mobile) |

---

## VideoSource Constructors

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
| iOS / tvOS | 15.0 |
| Android / Android TV | API 21 (Android 5.0) |
| Flutter | 3.16.0 |
| Dart | 3.0.0 |

---

## License

MIT License — see [LICENSE](LICENSE) for details.