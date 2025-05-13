import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String _selectedGender = 'Prefer not to say';
  File? _imageFile;
  String? _currentPhotoUrl;
  bool _isLoading = false;
  bool _dataLoaded = false;
  final List<String> _genderOptions = ['Male', 'Female', 'Non-binary', 'Prefer not to say'];
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserData() async {
    if (_dataLoaded) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Get user document from Firestore
        final docSnapshot = await _firestore.collection('users').doc(user.uid).get();
        
        if (docSnapshot.exists) {
          final userData = docSnapshot.data();
          
          // Load user data
          setState(() {
            _firstNameController.text = userData?['firstName'] ?? '';
            _lastNameController.text = userData?['lastName'] ?? '';
            _selectedGender = userData?['gender'] ?? 'Prefer not to say';
            _currentPhotoUrl = user.photoURL;
            _dataLoaded = true;
          });
        } else if (user.displayName != null && user.displayName!.isNotEmpty) {
          // If no Firestore document but displayName exists, try to parse it
          final nameParts = user.displayName!.split(' ');
          if (nameParts.isNotEmpty) {
            setState(() {
              _firstNameController.text = nameParts[0];
              if (nameParts.length > 1) {
                _lastNameController.text = nameParts.sublist(1).join(' ');
              }
              _currentPhotoUrl = user.photoURL;
              _dataLoaded = true;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
      );
      
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }
  
  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _currentPhotoUrl;
    
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      
      final storageRef = _storage.ref().child('profile_pictures/${user.uid}');
      final uploadTask = await storageRef.putFile(_imageFile!);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
      return null;
    }
  }
  
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not signed in');
      
      // Upload new image if one was selected
      final photoUrl = await _uploadImage();
      
      // Create display name from first and last name
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final displayName = '$firstName ${lastName.isNotEmpty ? lastName : ""}';
      
      // Update Firebase Auth profile
      await user.updateDisplayName(displayName);
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }
      
      // Update Firestore document
      await _firestore.collection('users').doc(user.uid).set({
        'firstName': firstName,
        'lastName': lastName,
        'gender': _selectedGender,
        'updatedAt': FieldValue.serverTimestamp(),
        // Don't overwrite these fields if they already exist
        'email': user.email ?? FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.pop(context, true); // Return true to indicate successful update
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: _isLoading && !_dataLoaded
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    
                    // Profile picture
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _imageFile != null
                                  ? Image.file(
                                      _imageFile!,
                                      fit: BoxFit.cover,
                                    )
                                  : _currentPhotoUrl != null
                                      ? Image.network(
                                          _currentPhotoUrl!,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return const Center(
                                              child: CircularProgressIndicator(),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) => Icon(
                                            Icons.person,
                                            size: 50,
                                            color: AppColors.primaryBlue,
                                          ),
                                        )
                                      : Container(
                                          color: Colors.grey.shade100,
                                          child: Icon(
                                            Icons.person,
                                            size: 50,
                                            color: AppColors.primaryBlue,
                                          ),
                                        ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // First name
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your first name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Last name
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Gender dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                      ),
                      items: _genderOptions.map((gender) {
                        return DropdownMenuItem<String>(
                          value: gender,
                          child: Text(gender),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedGender = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
} 