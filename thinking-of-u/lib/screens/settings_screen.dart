import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../blocs/auth/auth_bloc.dart';
import '../router.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.primary,
                      onPressed: () => context.pop(),
                    ),
                    Text(
                      'Settings',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    // Profile section
                    _buildSectionHeader(context, 'Profile'),
                    _buildProfileCard(context, user?.displayName ?? 'Friend')
                        .animate()
                        .fadeIn(delay: 100.ms),

                    const SizedBox(height: 20),

                    // Stats section
                    if (user != null) ...[
                      _buildSectionHeader(context, 'Your Stats'),
                      _buildStatsCard(context, user)
                          .animate()
                          .fadeIn(delay: 200.ms),
                      const SizedBox(height: 20),
                    ],

                    // About section
                    _buildSectionHeader(context, 'App'),
                    _buildSettingsTile(
                      context,
                      icon: Icons.info_outline_rounded,
                      title: 'About Thinking of U',
                      onTap: () => _showAboutDialog(context),
                    ).animate().fadeIn(delay: 300.ms),

                    _buildSettingsTile(
                      context,
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      onTap: () {},
                    ).animate().fadeIn(delay: 350.ms),

                    _buildSettingsTile(
                      context,
                      icon: Icons.help_outline_rounded,
                      title: 'How it works',
                      onTap: () => _showHowItWorksSheet(context),
                    ).animate().fadeIn(delay: 400.ms),

                    const SizedBox(height: 20),

                    // Sign out
                    OutlinedButton.icon(
                      onPressed: () {
                        context.read<AuthBloc>().add(AuthSignOutRequested());
                        context.go(AppRoutes.phoneAuth);
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                    ).animate().fadeIn(delay: 500.ms),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.onBackground.withOpacity(0.5),
              fontSize: 13,
              letterSpacing: 1.2,
            ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, String name) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, dynamic user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(context, '${user.totalMatches}', 'Total\nMatches',
                Icons.favorite_rounded),
            _buildStatDivider(),
            _buildStatItem(context, '${user.currentStreak}', 'Day\nStreak',
                Icons.local_fire_department_rounded),
            _buildStatDivider(),
            _buildStatItem(context, '${user.longestStreak}', 'Best\nStreak',
                Icons.emoji_events_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      BuildContext context, String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: AppColors.primary,
              ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 60,
      color: AppColors.divider,
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: const Icon(Icons.chevron_right_rounded,
            color: AppColors.primary),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('thinking of u 💕'),
        content: const Text(
          'Thinking of U is a fun way to let people know you\'re '
          'thinking about them — without the pressure.\n\n'
          'When both of you think of each other on the same day, '
          'you both get a notification. It\'s like telepathy! ✨',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Sweet!'),
          ),
        ],
      ),
    );
  }

  void _showHowItWorksSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('How it works 💡',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 20),
            const _HowItWorksStep(
              icon: '1️⃣',
              title: 'Add up to 3 people',
              desc: 'Enter the phone number of someone you\'re thinking of.',
            ),
            const _HowItWorksStep(
              icon: '2️⃣',
              title: 'Wait for the match',
              desc:
                  'At midnight, if they also added YOUR number, it\'s a match!',
            ),
            const _HowItWorksStep(
              icon: '3️⃣',
              title: 'Both get notified',
              desc:
                  'You both receive a notification saying the other was thinking of you.',
            ),
            const _HowItWorksStep(
              icon: '🔒',
              title: 'Private & secure',
              desc:
                  'Phone numbers are never stored in plaintext. Only you see who you submit.',
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorksStep extends StatelessWidget {
  final String icon;
  final String title;
  final String desc;
  final bool isLast;

  const _HowItWorksStep({
    required this.icon,
    required this.title,
    required this.desc,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.titleLarge),
                Text(desc,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
