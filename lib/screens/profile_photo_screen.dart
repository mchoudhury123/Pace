import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'completion_screen.dart';
import '../main.dart';

class ProfilePhotoScreen extends StatefulWidget {
  const ProfilePhotoScreen({super.key});

  @override
  State<ProfilePhotoScreen> createState() => _ProfilePhotoScreenState();
}

class _ProfilePhotoScreenState extends State<ProfilePhotoScreen> {
  File? _image;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800, // Limit image size
        maxHeight: 800,
        imageQuality: 85, // Compress image
      );

      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
        // Automatically upload the image when selected
        await _uploadImageToFirebase();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _uploadImageToFirebase() async {
    if (_image == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      // Create a reference to the user's profile picture
      final storageRef = _storage.ref().child('profile_pictures/${user.uid}');

      // Upload the file with metadata
      final uploadTask = storageRef.putFile(
        _image!,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': user.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Get download URL after upload completes
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update user profile with new photo URL
      await user.updatePhotoURL(downloadUrl);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile picture updated successfully!'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        
        // Navigate to completion screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const CompletionScreen(),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose Photo',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepBlue,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildOptionButton(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _getImage(ImageSource.camera);
                    },
                  ),
                  _buildOptionButton(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _getImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.primaryBlue,
              size: 32,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: AppColors.deepBlue,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget mainContent = Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: AppColors.textBlack,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.lightBlue,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade100.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Your\nProfile Photo',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.deepBlue,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Put a face to your impact! Add a profile photo to personalize your charitable journey',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textGrey,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _isLoading ? null : _showImageSourceDialog,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primaryBlue.withOpacity(0.3),
                            width: 3,
                          ),
                          image: _image != null
                              ? DecorationImage(
                                  image: FileImage(_image!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _isLoading
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primaryBlue,
                                ),
                              )
                            : _image == null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        size: 80,
                                        color: AppColors.primaryBlue,
                                      ),
                                      const SizedBox(height: 8),
                                      Icon(
                                        Icons.add_circle,
                                        size: 28,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ],
                                  )
                                : null,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _image == null ? 'Tap to add a photo' : 'Looking good!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryBlue,
                            AppColors.primaryBlue.withBlue(255),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _showImageSourceDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                          disabledBackgroundColor: Colors.transparent,
                        ),
                        child: Text(
                          _image == null ? 'Choose Photo' : 'Change Photo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _isLoading ? Colors.white.withOpacity(0.7) : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CompletionScreen(),
                                ),
                              );
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textGrey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        'Skip for Now',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _isLoading ? AppColors.textGrey.withOpacity(0.5) : AppColors.textGrey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (kIsWeb) {
      const phoneWidth = 393.0;
      const phoneHeight = 852.0;

      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Container(
            width: phoneWidth,
            height: phoneHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: mainContent,
            ),
          ),
        ),
      );
    }

    return mainContent;
  }
} 