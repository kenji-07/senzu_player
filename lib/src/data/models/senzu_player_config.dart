class SenzuDataPolicy {
  const SenzuDataPolicy({
    this.warnOnCellular = true,
    this.dataSaverOnCellular = false,
    this.dataSaverQualityKey,
  });

  /// Cellular сүлжээнд анхааруулга харуулах эсэх
  final bool warnOnCellular;

  /// Cellular дээр автоматаар бага чанарт шилжих эсэх
  final bool dataSaverOnCellular;

  /// Data saver горимд ашиглах чанарын түлхүүр (жишээ: '480p')
  /// null бол sources map-ийн сүүлийн key ашиглана
  final String? dataSaverQualityKey;

  static const SenzuDataPolicy none = SenzuDataPolicy(
    warnOnCellular: false,
    dataSaverOnCellular: false,
  );
}
