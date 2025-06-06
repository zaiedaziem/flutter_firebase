import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/file_model.dart';

const String FILES_COLLECTION_REF = "files";

class FileService {
  final _firestore = FirebaseFirestore.instance;
  final _imagePicker = ImagePicker();

  late final CollectionReference _filesRef;

  FileService() {
    _filesRef = _firestore.collection(FILES_COLLECTION_REF).withConverter<FileModel>(
          fromFirestore: (snapshot, _) => FileModel.fromJson(snapshot.data()!),
          toFirestore: (fileModel, _) => fileModel.toJson(),
        );
  }

  // Get all files
  Stream<QuerySnapshot> getFiles() {
    return _filesRef.orderBy('uploadedAt', descending: true).snapshots();
  }

  // Add a new file
  Future<void> addFile(FileModel fileModel) async {
    await _filesRef.add(fileModel);
  }

  // Delete a file
  Future<void> deleteFile(String fileId) async {
    await _filesRef.doc(fileId).delete();
  }

  // Update file description or tags
  Future<void> updateFile(String fileId, FileModel fileModel) async {
    await _filesRef.doc(fileId).update(fileModel.toJson());
  }

  // Pick image from gallery
  Future<XFile?> pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Compress to reduce size
      );
      return image;
    } catch (e) {
      print('Error picking image from gallery: $e');
      return null;
    }
  }

  // Pick image from camera
  Future<XFile?> pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80, // Compress to reduce size
      );
      return image;
    } catch (e) {
      print('Error picking image from camera: $e');
      return null;
    }
  }

  // Convert XFile to FileModel
  Future<FileModel?> convertXFileToFileModel({
    required XFile xFile,
    String uploadedBy = 'Anonymous',
    String description = '',
    List<String> tags = const [],
  }) async {
    try {
      // Read file as bytes
      Uint8List fileBytes = await xFile.readAsBytes();
      
      // Convert to base64
      String base64String = base64Encode(fileBytes);
      
      // Get file info
      String fileName = xFile.name;
      String fileType = xFile.mimeType ?? 'image/jpeg';
      int fileSize = fileBytes.length;

      // Check file size (limit to 1MB for Firestore)
      if (fileSize > 1024 * 1024) {
        throw Exception('File size too large. Maximum size is 1MB.');
      }

      return FileModel(
        fileName: fileName,
        fileType: fileType,
        fileSize: fileSize,
        base64Data: base64String,
        uploadedAt: Timestamp.now(),
        uploadedBy: uploadedBy,
        description: description,
        tags: tags,
      );
    } catch (e) {
      print('Error converting XFile to FileModel: $e');
      return null;
    }
  }

  // Convert base64 back to Uint8List for display
  Uint8List base64ToUint8List(String base64String) {
    return base64Decode(base64String);
  }
}