class ScanSettings {
  final bool compressionEnabled;
  final String? documentName;

  const ScanSettings({
    this.compressionEnabled = false,
    this.documentName,
  });

  ScanSettings copyWith({
    bool? compressionEnabled,
    String? documentName,
  }) {
    return ScanSettings(
      compressionEnabled: compressionEnabled ?? this.compressionEnabled,
      documentName: documentName ?? this.documentName,
    );
  }
}