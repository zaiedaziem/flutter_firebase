import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/file_model.dart';

const String FILES_COLLECTION_REF = "files";

class FileService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _imagePicker = ImagePicker();

  late final CollectionReference _filesRef;

  FileService() {
    _filesRef = _firestore.collection(FILES_COLLECTION_REF).withConverter<FileModel>(
          fromFirestore: (snapshot, _) => FileModel.fromJson(snapshot.data()!),
          toFirestore: (fileModel, _) => fileModel.toJson(),
        );
  }

  // Get current user's ID
  String? get _currentUserId => _auth.currentUser?.uid;

  // Option A: Simple query without orderBy (then sort in memory)
  Stream<QuerySnapshot> getFiles() {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    return _filesRef
        .where('userId', isEqualTo: _currentUserId)
        .snapshots();
  }

  // Option B: Get files and sort them manually
  Stream<List<DocumentSnapshot>> getFilesSorted() {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    return _filesRef
        .where('userId', isEqualTo: _currentUserId)
        .snapshots()
        .map((snapshot) {
      // Sort documents by uploadedAt in descending order
      var docs = snapshot.docs.toList();
      docs.sort((a, b) {
        var aData = a.data() as FileModel;
        var bData = b.data() as FileModel;
        return bData.uploadedAt.compareTo(aData.uploadedAt);
      });
      return docs;
    });
  }

  // Option C: Use a different collection structure (user-specific subcollection)
  Stream<QuerySnapshot> getUserFiles() {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // This approach uses a subcollection under each user
    return _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('files')
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }

  // Add file using subcollection approach
  Future<void> addFileToUserCollection(FileModel fileModel) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    await _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('files')
        .add(fileModel.toJson());
  }

  // Add a new file for the current user (original method)
  Future<void> addFile(FileModel fileModel) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Add userId to the file before saving
    Map<String, dynamic> fileData = fileModel.toJson();
    fileData['userId'] = _currentUserId;

    await _firestore.collection(FILES_COLLECTION_REF).add({
      ...fileData,
      'userId': _currentUserId,
    });
  }

  // Delete a file (only if it belongs to current user)
  Future<void> deleteFile(String fileId) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Verify ownership
    final docRef = _firestore.collection(FILES_COLLECTION_REF).doc(fileId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.data() as Map<String, dynamic>;
    if (data['userId'] != _currentUserId) {
      throw Exception(
        'Unauthorized: Cannot delete file that belongs to another user'
      );
    }

    // Perform delete
    await docRef.delete();
  }

  // Update file description or tags (only if it belongs to current user)
  Future<void> updateFile(String fileId, FileModel fileModel) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Verify ownership
    final docRef = _firestore.collection(FILES_COLLECTION_REF).doc(fileId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.data() as Map<String, dynamic>;
    if (data['userId'] != _currentUserId) {
      throw Exception(
        'Unauthorized: Cannot update file that belongs to another user'
      );
    }

    // Prepare new data
    final updated = {
      ...fileModel.toJson(),
      'userId': _currentUserId,
    };

    // Write raw map
    await docRef.update(updated);
  }

  // Delete all files for the current user (useful for account deletion)
  Future<void> deleteAllUserFiles() async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    QuerySnapshot files =
        await _filesRef.where('userId', isEqualTo: _currentUserId).get();

    WriteBatch batch = _firestore.batch();
    for (DocumentSnapshot doc in files.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
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