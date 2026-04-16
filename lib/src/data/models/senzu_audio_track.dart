class SenzuAudioTrack {
  const SenzuAudioTrack({
    required this.id,
    required this.name,
    required this.language,
    this.isDefault = false,
  });
  final String id, name, language;
  final bool isDefault;
}
