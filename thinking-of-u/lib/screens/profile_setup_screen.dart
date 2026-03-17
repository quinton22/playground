import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../theme/app_colors.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context
        .read<AuthBloc>()
        .add(AuthProfileSetupSubmitted(_nameController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error),
          );
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 60),

                    Center(
                      child: Column(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                AppColors.heartGradient.createShader(bounds),
                            child: const Icon(
                              Icons.favorite_rounded,
                              size: 72,
                              color: Colors.white,
                            ),
                          )
                              .animate()
                              .scale(
                                  duration: 600.ms,
                                  curve: Curves.elasticOut)
                              .fadeIn(),

                          const SizedBox(height: 24),

                          Text(
                            'Almost there! 🎉',
                            style:
                                Theme.of(context).textTheme.displaySmall?.copyWith(
                                      color: AppColors.primary,
                                    ),
                          ).animate().fadeIn(delay: 200.ms),
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),

                    Text(
                      'What\'s your first name?',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ).animate().fadeIn(delay: 300.ms),

                    const SizedBox(height: 8),

                    Text(
                      'This will appear in notifications when someone is thinking of you.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.onBackground.withOpacity(0.6),
                          ),
                    ).animate().fadeIn(delay: 400.ms),

                    const SizedBox(height: 28),

                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      keyboardType: TextInputType.name,
                      decoration: const InputDecoration(
                        hintText: 'First name',
                        prefixIcon: Icon(
                          Icons.person_outline_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your first name';
                        }
                        if (value.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        if (value.trim().length > 30) {
                          return 'Name must be 30 characters or less';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ).animate().fadeIn(delay: 500.ms),

                    const SizedBox(height: 32),

                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        return ElevatedButton(
                          onPressed: state is AuthLoading ? null : _submit,
                          child: state is AuthLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text('Let\'s go! 💌'),
                        ).animate().fadeIn(delay: 600.ms);
                      },
                    ),

                    const Spacer(),

                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Text(
                          'Only your first name is shown. Never your number.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ).animate().fadeIn(delay: 700.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
