class PageRef {
  final String filePath;
  // 1-based page number
  final int pageNumber;

  const PageRef({
    required this.filePath,
    required this.pageNumber,
  });
}
