import 'package:cloud_firestore/cloud_firestore.dart';

class FileModel {
  String fileName;
  String fileType;
  int fileSize;
  String base64Data;
  Timestamp uploadedAt;
  String uploadedBy;
  String description;
  List<String> tags;
  String? userId; // Optional for backward compatibility

  FileModel({
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.base64Data,
    required this.uploadedAt,
    required this.uploadedBy,
    required this.description,
    required this.tags,
    this.userId,
  });

  FileModel.fromJson(Map<String, Object?> json)
      : fileName = json['fileName'] as String,
        fileType = json['fileType'] as String,
        fileSize = json['fileSize'] as int,
        base64Data = json['base64Data'] as String,
        uploadedAt = json['uploadedAt'] as Timestamp,
        uploadedBy = json['uploadedBy'] as String? ?? '',
        description = json['description'] as String? ?? '',
        tags = List<String>.from(json['tags'] as List? ?? []),
        userId = json['userId'] as String?;

  FileModel copyWith({
    String? fileName,
    String? fileType,
    int? fileSize,
    String? base64Data,
    Timestamp? uploadedAt,
    String? uploadedBy,
    String? description,
    List<String>? tags,
    String? userId,
  }) {
    return FileModel(
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      base64Data: base64Data ?? this.base64Data,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      userId: userId ?? this.userId,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'fileName': fileName,
      'fileType': fileType,
      'fileSize': fileSize,
      'base64Data': base64Data,
      'uploadedAt': uploadedAt,
      'uploadedBy': uploadedBy,
      'description': description,
      'tags': tags,
      'userId': userId,
    };
  }

  // Helper method to get file size in human readable format
  String get fileSizeFormatted {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  // Helper method to check if file is an image
  bool get isImage {
    return fileType.startsWith('image/');
  }
}