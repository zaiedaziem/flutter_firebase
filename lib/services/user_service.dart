import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_profile.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  // Get user profile
  Future<UserProfile?> getUserProfile() async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .get();

      if (doc.exists) {
        return UserProfile.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }

  // Update user profile
  Future<void> updateUserProfile(UserProfile profile) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .set(profile.toJson(), SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  // Upload profile picture
  Future<String> uploadProfilePicture(File imageFile) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final ref = _storage
          .ref()
          .child('profile_pictures')
          .child('$_currentUserId.jpg');

      final uploadTask = await ref.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload profile picture: $e');
    }
  }

  // Delete profile picture
  Future<void> deleteProfilePicture() async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final ref = _storage
          .ref()
          .child('profile_pictures')
          .child('$_currentUserId.jpg');

      await ref.delete();
    } catch (e) {
      // It's okay if the file doesn't exist
      print('Profile picture deletion error: $e');
    }
  }

  // Create initial user profile (call this after successful registration)
  Future<void> createUserProfile({
    required String name,
    String? contact,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final profile = UserProfile(
      name: name,
      contact: contact,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await updateUserProfile(profile);
  }
}