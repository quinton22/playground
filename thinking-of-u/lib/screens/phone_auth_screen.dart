import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../blocs/auth/auth_bloc.dart';
import '../router.dart';
import '../theme/app_colors.dart';
import '../utils/phone_utils.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  String _countryCode = '+1';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final phone = '$_countryCode${_phoneController.text.replaceAll(RegExp(r'\D'), '')}';
    context.read<AuthBloc>().add(AuthPhoneSubmitted(phone));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthCodeSent) {
          context.go(AppRoutes.otp, extra: {
            'phone': state.phoneNumber,
            'verificationId': state.verificationId,
          });
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 60),

                    // Logo & title
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.35),
                                  blurRadius: 20,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

                          const SizedBox(height: 20),

                          Text(
                            'thinking of u',
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(color: AppColors.primary),
                          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3, end: 0),
                        ],
                      ),
                    ),

                    const SizedBox(height: 52),

                    Text(
                      'Enter your phone number',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ).animate().fadeIn(delay: 300.ms),

                    const SizedBox(height: 8),

                    Text(
                      'We\'ll send you a code to verify your number.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.onBackground.withOpacity(0.6),
                          ),
                    ).animate().fadeIn(delay: 400.ms),

                    const SizedBox(height: 28),

                    // Phone input row
                    Row(
                      children: [
                        // Country code dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.divider, width: 1.5),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _countryCode,
                              isDense: true,
                              items: const [
                                DropdownMenuItem(
                                    value: '+1', child: Text('🇺🇸 +1')),
                                DropdownMenuItem(
                                    value: '+44', child: Text('🇬🇧 +44')),
                                DropdownMenuItem(
                                    value: '+61', child: Text('🇦🇺 +61')),
                                DropdownMenuItem(
                                    value: '+91', child: Text('🇮🇳 +91')),
                                DropdownMenuItem(
                                    value: '+49', child: Text('🇩🇪 +49')),
                                DropdownMenuItem(
                                    value: '+33', child: Text('🇫🇷 +33')),
                                DropdownMenuItem(
                                    value: '+55', child: Text('🇧🇷 +55')),
                                DropdownMenuItem(
                                    value: '+52', child: Text('🇲🇽 +52')),
                              ],
                              onChanged: (value) =>
                                  setState(() => _countryCode = value!),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Phone number input
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(12),
                            ],
                            decoration: const InputDecoration(
                              hintText: 'Phone number',
                              prefixIcon: Icon(
                                Icons.phone_outlined,
                                color: AppColors.primary,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your phone number';
                              }
                              final full =
                                  '$_countryCode${value.replaceAll(RegExp(r'\D'), '')}';
                              if (!PhoneUtils.isValidPhoneNumber(full)) {
                                return 'Please enter a valid phone number';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _submit(),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 500.ms),

                    const SizedBox(height: 32),

                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        final isLoading = state is AuthLoading;
                        return ElevatedButton(
                          onPressed: isLoading ? null : _submit,
                          child: isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text('Send Code'),
                        ).animate().fadeIn(delay: 600.ms);
                      },
                    ),

                    const Spacer(),

                    // Privacy note
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Center(
                        child: Text(
                          '🔒 Your number is never shared or stored in plaintext.',
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
