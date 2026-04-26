class SenzuLanguage {
  const SenzuLanguage({
    // ── Cellular warning ─────────────────────────
    this.dataSaver = 'Data Saver',
    this.cellularWarningTitle = 'Using Mobile Data',
    this.cellularWarningBody = 'Streaming will use your mobile data.',
    this.cellularContinue = 'Continue',
    this.cellularUseSaver = 'Use Data Saver',

    // ── General / Panels ─────────────────────────
    this.sleepModeActivated = 'Sleep mode activated',
    this.continueWatching = 'Continue watching',
    this.aspectRatio = 'Aspect ratio',
    this.audio = 'Audio',
    this.subtitles = 'Subtitles',
    this.episodes = 'Episodes',
    this.quality = 'Quality',
    this.settings = 'Settings',
    this.playbackSpeed = 'Playback speed',
    this.sleepTimer = 'Sleep timer',
    this.untilVideoEnds = 'Until video ends',
    this.minutesShort = 'min',
    this.minutes = 'Min',
    this.cancel = 'Cancel',
    this.loading = 'Loading...',
    this.backToPlayer = 'Back to player',
    this.cast = 'Cast',

    // ── Controls ─────────────────────────────────
    this.next = 'Next',
    this.lockScreen = 'Lock',

    // ── Ad ───────────────────────────────────────
    this.adLoading = 'Ad loading...',
    this.skipAd = 'Skip Ad',
    this.learnMore = 'Learn more',

    // ── Player settings ───────────────────────────
    this.speed = 'Speed',
    this.subtitle = 'Subtitle',
    this.aspect = 'Aspect',
    this.none = 'None',
    this.normal = 'Normal',

    // ── Subtitle / Fit ────────────────────────────
    this.subtitleSize = 'Size',
    this.contain = 'Contain',
    this.cover = 'Cover',
    this.fill = 'Fill',
    this.fitWidth = 'Fit width',
    this.fitHeight = 'Fit height',

    // ── Buffer ────────────────────────────────────
    this.preparing = 'Preparing...',
    this.buffered = 'Buffered',

    // ── Error ─────────────────────────────────────
    this.failedToLoad = 'Failed to load video',
    this.retry = 'Retry',

    // ── Live ──────────────────────────────────────
    this.live = 'LIVE',
    this.goToLive = 'Go live',

    // ── HDR ───────────────────────────────────────
    this.hdr = 'HDR',

    // ── Cast panel ────────────────────────────────
    this.castSearching = 'Searching...',
    this.castNoDevices = 'No devices found',
    this.castConnecting = 'Connecting...',
    this.castSearch = 'Search devices',
    this.castConnected = 'Cast',

    // ── Speed toast ───────────────────────────────
    this.speedToast = '2× speed',

    // ── Ad counter ────────────────────────────────
    this.adOf = 'Ad {current} of {total}',

    // ── Buffering / loading overlay ───────────────
    this.preparingPrefix = 'Preparing',
  });

  // Cellular
  final String dataSaver;
  final String cellularWarningTitle;
  final String cellularWarningBody;
  final String cellularContinue;
  final String cellularUseSaver;

  // General / Panels
  final String sleepModeActivated;
  final String continueWatching;
  final String aspectRatio;
  final String audio;
  final String subtitles;
  final String episodes;
  final String quality;
  final String settings;
  final String playbackSpeed;
  final String sleepTimer;
  final String untilVideoEnds;
  final String minutesShort;
  final String minutes;
  final String cancel;
  final String loading;
  final String backToPlayer;
  final String cast;

  // Controls
  final String next;
  final String lockScreen;

  // Ad
  final String adLoading;
  final String skipAd;
  final String learnMore;

  // Player settings
  final String speed;
  final String subtitle;
  final String aspect;
  final String none;
  final String normal;

  // Subtitle / Fit
  final String subtitleSize;
  final String contain;
  final String cover;
  final String fill;
  final String fitWidth;
  final String fitHeight;

  // Buffer
  final String preparing;
  final String buffered;

  // Error
  final String failedToLoad;
  final String retry;

  // Live
  final String live;
  final String goToLive;

  // HDR
  final String hdr;

  // Cast panel
  final String castSearching;
  final String castNoDevices;
  final String castConnecting;
  final String castSearch;
  final String castConnected;

  // Speed toast
  final String speedToast;

  // Ad counter — use adCounter(current, total) helper
  final String adOf;

  // Buffer overlay prefix
  final String preparingPrefix;

  /// Formats the ad counter string, e.g. "Ad 1 of 3".
  String adCounter(int current, int total) =>
      adOf.replaceAll('{current}', '$current').replaceAll('{total}', '$total');
}
