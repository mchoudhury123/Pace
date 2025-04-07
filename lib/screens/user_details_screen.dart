import 'package:flutter/material.dart';
import '../main.dart';
import 'home_screen.dart';
import 'gender_selection_screen.dart';
import 'onboarding_screen.dart';
import 'package:intl/intl.dart';
import 'package:flutter_calendar_carousel/flutter_calendar_carousel.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserDetailsScreen extends StatefulWidget {
  const UserDetailsScreen({super.key});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  DateTime? _selectedDate;
  final _dateController = TextEditingController();

  bool _isOver16(DateTime birthDate) {
    final today = DateTime.now();
    final age = today.year - birthDate.year - 
      (today.month < birthDate.month || 
      (today.month == birthDate.month && today.day < birthDate.day) ? 1 : 0);
    return age >= 16;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        DateTime? selectedDate = _selectedDate ?? DateTime.now().subtract(const Duration(days: 16 * 365));
        
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Birth Date',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 400,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            DropdownButton<int>(
                              value: selectedDate?.year ?? DateTime.now().year,
                              items: List.generate(
                                DateTime.now().year - 1900 + 1,
                                (index) => DropdownMenuItem(
                                  value: DateTime.now().year - index,
                                  child: Text(
                                    (DateTime.now().year - index).toString(),
                                    style: TextStyle(
                                      color: AppColors.textBlack,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              onChanged: (int? year) {
                                if (year != null) {
                                  setState(() {
                                    selectedDate = DateTime(
                                      year,
                                      selectedDate?.month ?? DateTime.now().month,
                                      selectedDate?.day ?? 1,
                                    );
                                  });
                                }
                              },
                              dropdownColor: Colors.white,
                              icon: Icon(Icons.arrow_drop_down, color: AppColors.primaryBlue),
                              underline: Container(height: 2, color: AppColors.primaryBlue),
                            ),
                            const SizedBox(width: 20),
                            DropdownButton<int>(
                              value: selectedDate?.month ?? DateTime.now().month,
                              items: List.generate(
                                12,
                                (index) => DropdownMenuItem(
                                  value: index + 1,
                                  child: Text(
                                    DateFormat('MMMM').format(DateTime(2024, index + 1)),
                                    style: TextStyle(
                                      color: AppColors.textBlack,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              onChanged: (int? month) {
                                if (month != null) {
                                  setState(() {
                                    selectedDate = DateTime(
                                      selectedDate?.year ?? DateTime.now().year,
                                      month,
                                      selectedDate?.day ?? 1,
                                    );
                                  });
                                }
                              },
                              dropdownColor: Colors.white,
                              icon: Icon(Icons.arrow_drop_down, color: AppColors.primaryBlue),
                              underline: Container(height: 2, color: AppColors.primaryBlue),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: CalendarCarousel(
                          onDayPressed: (DateTime date, _) {
                            selectedDate = date;
                            Navigator.of(context).pop(date);
                          },
                          thisMonthDayBorderColor: Colors.grey,
                          weekFormat: false,
                          height: 340,
                          selectedDateTime: selectedDate,
                          targetDateTime: selectedDate,
                          customGridViewPhysics: const NeverScrollableScrollPhysics(),
                          markedDateCustomShapeBorder: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          markedDateCustomTextStyle: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          selectedDayButtonColor: AppColors.primaryBlue,
                          selectedDayTextStyle: const TextStyle(color: Colors.white),
                          todayButtonColor: Colors.transparent,
                          todayTextStyle: TextStyle(color: AppColors.primaryBlue),
                          minSelectedDate: DateTime(1900),
                          maxSelectedDate: DateTime.now(),
                          headerTextStyle: TextStyle(
                            color: AppColors.deepBlue,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          iconColor: AppColors.primaryBlue,
                          weekdayTextStyle: TextStyle(
                            color: AppColors.textGrey,
                            fontWeight: FontWeight.w600,
                          ),
                          daysTextStyle: TextStyle(
                            color: AppColors.textBlack,
                          ),
                          weekendTextStyle: TextStyle(
                            color: AppColors.primaryBlue.withOpacity(0.7),
                          ),
                          showHeaderButton: false, // Hide default header
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(selectedDate),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          'Select',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('MMMM d, y').format(picked);
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _handleContinue() async {
    if (_formKey.currentState!.validate() && _selectedDate != null) {
      if (!_isOver16(_selectedDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('You must be at least 16 years old to use this app'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }

      try {
        // Get current user
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Update display name
          await user.updateDisplayName('${_firstNameController.text} ${_lastNameController.text}');
        }

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GenderSelectionScreen()),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to save user details. Please try again.'),
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
  }

  InputDecoration _getInputDecoration(String label, IconData? icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: AppColors.textGrey,
        fontSize: 16,
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
      ),
      suffixIcon: icon != null ? Icon(icon, color: AppColors.primaryBlue) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: AppColors.textBlack,
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const OnboardingScreen()),
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
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
                      'Tell us about yourself',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepBlue,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We\'ll use this information to personalize your experience',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textGrey,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.lightBlue,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _firstNameController,
                      decoration: _getInputDecoration('First Name', Icons.person_outline),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your first name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: _getInputDecoration('Last Name', Icons.person_outline),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your last name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _dateController,
                      readOnly: true,
                      decoration: _getInputDecoration('Date of Birth', Icons.calendar_today),
                      onTap: () => _selectDate(context),
                      validator: (value) {
                        if (_selectedDate == null) {
                          return 'Please select your date of birth';
                        }
                        if (!_isOver16(_selectedDate!)) {
                          return 'You must be at least 16 years old';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                height: 56,
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
                  onPressed: _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 