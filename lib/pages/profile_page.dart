// pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../models/user_profile.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  
  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  
  // For web compatibility
  Uint8List? _selectedImageBytes;
  File? _selectedImageFile;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _userService.getUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _nameController.text = profile?.name ?? '';
          _contactController.text = profile?.contact ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      
      if (image != null) {
        // Read image as bytes for web compatibility
        final Uint8List imageBytes = await image.readAsBytes();
        
        setState(() {
          _selectedImageBytes = imageBytes;
          // Only set file for non-web platforms
          if (!kIsWeb) {
            _selectedImageFile = File(image.path);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      String? profilePictureUrl = _userProfile?.profilePictureUrl;
      
      // Upload new image if selected
      if (_selectedImageBytes != null) {
        if (kIsWeb) {
          // For web, we need to upload the bytes directly
          profilePictureUrl = await _userService.uploadProfilePictureBytes(_selectedImageBytes!);
        } else if (_selectedImageFile != null) {
          // For mobile, use the file
          profilePictureUrl = await _userService.uploadProfilePicture(_selectedImageFile!);
        }
      }

      final updatedProfile = UserProfile(
        name: _nameController.text.trim(),
        contact: _contactController.text.trim(),
        profilePictureUrl: profilePictureUrl,
        createdAt: _userProfile?.createdAt,
        updatedAt: DateTime.now(),
      );

      await _userService.updateUserProfile(updatedProfile);

      if (mounted) {
        setState(() {
          _userProfile = updatedProfile;
          _isEditing = false;
          _selectedImageBytes = null;
          _selectedImageFile = null;
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _selectedImageBytes = null;
      _selectedImageFile = null;
      _nameController.text = _userProfile?.name ?? '';
      _contactController.text = _userProfile?.contact ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isEditing && !_isLoading)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
          if (_isEditing)
            TextButton(
              onPressed: _isSaving ? null : _cancelEdit,
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // Profile Picture Section
                    _buildProfilePictureSection(),
                    
                    const SizedBox(height: 32),
                    
                    // User Info Card
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Personal Information',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Email (Read-only)
                            _buildInfoField(
                              label: 'Email',
                              value: _authService.currentUser?.email ?? 'N/A',
                              icon: Icons.email,
                              isReadOnly: true,
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Name Field
                            _isEditing
                                ? TextFormField(
                                    controller: _nameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Name',
                                      prefixIcon: Icon(Icons.person),
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please enter your name';
                                      }
                                      return null;
                                    },
                                  )
                                : _buildInfoField(
                                    label: 'Name',
                                    value: _userProfile?.name ?? 'Not set',
                                    icon: Icons.person,
                                  ),
                            
                            const SizedBox(height: 16),
                            
                            // Contact Field
                            _isEditing
                                ? TextFormField(
                                    controller: _contactController,
                                    decoration: const InputDecoration(
                                      labelText: 'Contact',
                                      prefixIcon: Icon(Icons.phone),
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.phone,
                                    validator: (value) {
                                      if (value != null && value.trim().isNotEmpty) {
                                        if (!RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(value)) {
                                          return 'Please enter a valid contact number';
                                        }
                                      }
                                      return null;
                                    },
                                  )
                                : _buildInfoField(
                                    label: 'Contact',
                                    value: _userProfile?.contact ?? 'Not set',
                                    icon: Icons.phone,
                                  ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Save Button (only show when editing)
                    if (_isEditing)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    
                    const SizedBox(height: 32),
                    
                    // Sign Out Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _showSignOutDialog,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Sign Out',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfilePictureSection() {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 3,
              ),
            ),
            child: ClipOval(
              child: _selectedImageBytes != null
                  ? Image.memory(
                      _selectedImageBytes!,
                      fit: BoxFit.cover,
                    )
                  : _userProfile?.profilePictureUrl != null
                      ? Image.network(
                          _userProfile!.profilePictureUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultAvatar();
                          },
                        )
                      : _buildDefaultAvatar(),
            ),
          ),
          if (_isEditing)
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey[300],
      child: Icon(
        Icons.person,
        size: 60,
        color: Colors.grey[600],
      ),
    );
  }

  Widget _buildInfoField({
    required String label,
    required String value,
    required IconData icon,
    bool isReadOnly = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isReadOnly ? Colors.grey[100] : Colors.transparent,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _authService.signOut();
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to sign out: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }
}