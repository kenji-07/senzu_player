Pod::Spec.new do |s|
  s.name             = 'senzu_player'
  s.version          = '1.1.2'
  s.summary          = 'Senzu Video Player — native iOS plugin'
  s.description      = <<-DESC
    Native AVPlayer-based video player plugin for Flutter with:
      - FairPlay Streaming (FPS) DRM
      - Picture-in-Picture (PiP)
      - Now Playing / Lock Screen controls
      - Background audio playback
      - Google Cast (Chromecast) support
      - Volume, brightness, battery, wakelock, secure mode
  DESC

  s.homepage         = 'https://github.com/kenji-07/senzu_player'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Kenji' => 'b684489@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.swift'

  s.dependency 'Flutter'
  s.dependency 'ScreenProtectorKit'
  s.dependency 'google-cast-sdk', '~> 4.8.4'

  s.platform               = :ios, '15.0'
  s.pod_target_xcconfig    = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version          = '5.0'
  s.frameworks             = 'AVFoundation', 'AVKit', 'MediaPlayer', 'UIKit',
                             'Network', 'VideoToolbox'
end
