import 'package:flutter/material.dart';
import '../main.dart';

class OnboardingProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const OnboardingProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: currentStep / totalSteps,
          backgroundColor: AppColors.lightBlue,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
          minHeight: 4,
        ),
      ),
    );
  }
} 