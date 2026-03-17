import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Heart icon with animation
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 64,
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .scaleXY(
                    begin: 1.0,
                    end: 1.12,
                    duration: 800.ms,
                    curve: Curves.easeInOut,
                  )
                  .then()
                  .scaleXY(
                    begin: 1.12,
                    end: 1.0,
                    duration: 800.ms,
                    curve: Curves.easeInOut,
                  ),

              const SizedBox(height: 32),

              Text(
                'thinking of u',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.primary,
                    ),
              )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 600.ms)
                  .slideY(begin: 0.2, end: 0),

              const SizedBox(height: 12),

              Text(
                'let them know 💌',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.onBackground.withOpacity(0.6),
                    ),
              )
                  .animate()
                  .fadeIn(delay: 600.ms, duration: 600.ms)
                  .slideY(begin: 0.2, end: 0),

              const SizedBox(height: 64),

              const CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ).animate().fadeIn(delay: 900.ms),
            ],
          ),
        ),
      ),
    );
  }
}
