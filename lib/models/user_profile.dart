import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String? name;
  final String? contact;
  final String? profilePictureUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile({
    this.name,
    this.contact,
    this.profilePictureUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String?,
      contact: json['contact'] as String?,
      profilePictureUrl: json['profilePictureUrl'] as String?,
      createdAt: json['createdAt'] != null 
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: json['updatedAt'] != null 
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'contact': contact,
      'profilePictureUrl': profilePictureUrl,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  UserProfile copyWith({
    String? name,
    String? contact,
    String? profilePictureUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      name: name ?? this.name,
      contact: contact ?? this.contact,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}