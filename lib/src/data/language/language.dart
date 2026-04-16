class SenzuLanguage {
  const SenzuLanguage({
    // Cellular warning
    this.dataSaver = 'Data Saver',
    this.cellularWarningTitle = 'Using Mobile Data',
    this.cellularWarningBody = 'Streaming will use your mobile data.',
    this.cellularContinue = 'Continue',
    this.cellularUseSaver = 'Use Data Saver',

    // Controls
    this.next = 'Next',
    this.skipOp = 'Skip OP',
    this.skipEd = 'Skip END',
    this.lockScreen = 'Lock',

    // Ad
    this.adLoading = 'Ad loading...',
    this.skipAd = 'Skip Ad',
    this.learnMore = 'Learn more',

    // Quality / Speed / panels
    this.quality = 'Quality',
    this.speed = 'Speed',
    this.subtitle = 'Subtitle',
    this.audio = 'Audio',
    this.aspect = 'Aspect',
    this.none = 'None',
    this.normal = 'Normal',

    // Subtitle size / screen fit
    this.subtitleSize = 'Size',
    this.contain = 'Contain',
    this.cover = 'Cover',
    this.fill = 'Fill',
    this.fitWidth = 'Fit Width',
    this.fitHeight = 'Fit Height',

    // Buffer / loading
    this.preparing = 'Preparing...',
    this.buffered = 'Buffered',

    // Error
    this.failedToLoad = 'Failed to load video',
    this.retry = 'Retry',

    // Live
    this.live = 'LIVE',
    this.goToLive = 'Go Live',
  });

  final String dataSaver;
  final String cellularWarningTitle;
  final String cellularWarningBody;
  final String cellularContinue;
  final String cellularUseSaver;

  final String next;
  final String skipOp;
  final String skipEd;
  final String lockScreen;

  final String adLoading;
  final String skipAd;
  final String learnMore;

  final String quality;
  final String speed;
  final String subtitle;
  final String audio;
  final String aspect;
  final String none;
  final String normal;

  final String subtitleSize;
  final String contain;
  final String cover;
  final String fill;
  final String fitWidth;
  final String fitHeight;

  final String preparing;
  final String buffered;

  final String failedToLoad;
  final String retry;

  final String live;
  final String goToLive;
}
