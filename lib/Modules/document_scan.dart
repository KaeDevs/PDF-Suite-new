class DocumentScan {
  final List<String> imagePaths;
  final String name;
  final DateTime createdAt;

  const DocumentScan({
    required this.imagePaths,
    required this.name,
    required this.createdAt,
  });

  bool get isEmpty => imagePaths.isEmpty;
  int get imageCount => imagePaths.length;
}