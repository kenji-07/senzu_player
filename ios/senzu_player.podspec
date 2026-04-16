Pod::Spec.new do |s|
  s.name             = 'senzu_player'
  s.version          = '1.0.0'
  s.summary          = 'Senzu Video Player — native iOS plugin'
  s.description      = <<-DESC
    Native AVPlayer-based video player with:
    - Picture-in-Picture (PiP)
    - Now Playing / Lock Screen controls
    - Background audio playback
    - Volume, brightness, battery, wakelock, secure mode
  DESC
  s.homepage         = 'https://github.com/kenji-07/senzu_player'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Kenji' => 'b684489@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.swift'
  s.dependency         'Flutter'
  s.dependency         'ScreenProtectorKit'
  s.platform           = :ios, '14.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version      = '5.0'
  s.frameworks         = 'AVFoundation', 'AVKit', 'MediaPlayer', 'UIKit',
                         'Network', 'VideoToolbox'

  # ── Required for Background playback + PiP ──────────────────────────────────
  # In your app's Info.plist add:
  #   <key>UIBackgroundModes</key>
  #   <array>
  #     <string>audio</string>
  #   </array>
  #
  # In your Xcode project Signing & Capabilities:
  #   • Add "Background Modes" → check "Audio, AirPlay, and Picture in Picture"
  #   • Add "Audio, AirPlay, and Picture in Picture" capability
  #
  # For PiP to work the app must be linked against AVKit and the
  # com.apple.developer.avfoundation.pip.video-player entitlement is NOT
  # required on iOS 14+ for standard PiP.
end
