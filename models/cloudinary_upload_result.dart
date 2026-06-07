class CloudinaryUploadResult {
  final String url;
  final String resourceType; // "image" or "video"

  CloudinaryUploadResult({required this.url, required this.resourceType});

  Null get secureUrl => null;
}
