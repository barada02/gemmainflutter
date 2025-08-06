/// Represents an AI model that can be downloaded and used
class AIModel {
  final String id;
  final String name;
  final String url;
  final String fileName;
  final int sizeInBytes;
  final String description;
  final bool isDownloaded;
  final double downloadProgress;

  const AIModel({
    required this.id,
    required this.name,
    required this.url,
    required this.fileName,
    required this.sizeInBytes,
    required this.description,
    this.isDownloaded = false,
    this.downloadProgress = 0.0,
  });

  AIModel copyWith({
    String? id,
    String? name,
    String? url,
    String? fileName,
    int? sizeInBytes,
    String? description,
    bool? isDownloaded,
    double? downloadProgress,
  }) {
    return AIModel(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      fileName: fileName ?? this.fileName,
      sizeInBytes: sizeInBytes ?? this.sizeInBytes,
      description: description ?? this.description,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      downloadProgress: downloadProgress ?? this.downloadProgress,
    );
  }

  String get sizeInMB => (sizeInBytes / (1024 * 1024)).toStringAsFixed(1);
  String get sizeInGB => (sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(2);
}

/// Download progress information
class DownloadProgress {
  final DownloadStatus status;
  final double progress;
  final int downloadedBytes;
  final int totalBytes;
  final String modelName;
  final String? error;

  const DownloadProgress({
    required this.status,
    required this.progress,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.modelName,
    this.error,
  });

  String get downloadedMB => (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
  String get totalMB => (totalBytes / (1024 * 1024)).toStringAsFixed(1);
  String get progressPercentage => (progress * 100).toStringAsFixed(1);
}

enum DownloadStatus {
  idle,
  starting,
  downloading,
  paused,
  completed,
  failed,
  cancelled
}
