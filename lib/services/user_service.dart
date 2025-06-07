import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/user_profile.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  // Upload profile picture from bytes (for web)
  Future<String> uploadProfilePictureBytes(Uint8List imageBytes) async {
    try {
      // Convert bytes to base64
      String base64Image = base64Encode(imageBytes);
      
      // Store as data URL (you can also just store the base64 string)
      String dataUrl = 'data:image/jpeg;base64,$base64Image';
      
      return dataUrl;
    } catch (e) {
      throw Exception('Failed to process image: $e');
    }
  }

  // Upload profile picture from file (for mobile)
  Future<String> uploadProfilePicture(File imageFile) async {
    try {
      // Read file as bytes
      Uint8List imageBytes = await imageFile.readAsBytes();
      
      // Use the same method as bytes upload
      return await uploadProfilePictureBytes(imageBytes);
    } catch (e) {
      throw Exception('Failed to upload profile picture: $e');
    }
  }

  // Update profile picture URL in Firestore
  Future<void> updateProfilePictureUrl(String profilePictureUrl) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .set({
            'profilePictureUrl': profilePictureUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update profile picture URL: $e');
    }
  }

  // Remove profile picture URL from Firestore
  Future<void> removeProfilePictureUrl() async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .set({
            'profilePictureUrl': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to remove profile picture URL: $e');
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