import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/home/home_bloc.dart';
import '../config/feature_flags.dart';
import '../router.dart';
import '../services/submission_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../utils/phone_utils.dart';
import '../widgets/heart_button.dart';
import '../widgets/match_card.dart';
import '../widgets/thinking_slot.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    if (user == null) return const SizedBox.shrink();

    return BlocProvider(
      create: (context) => HomeBloc(
        submissionService: context.read<SubmissionService>(),
        userService: context.read<UserService>(),
      )..add(HomeLoadRequested(user)),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeBloc, HomeState>(
      listener: (context, state) {
        if (state is HomeLoaded) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AppColors.error,
              ),
            );
          }
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      },
      builder: (context, state) {
        if (state is HomeLoading || state is HomeInitial) {
          return const Scaffold(
            body: Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        if (state is HomeError) {
          return Scaffold(
            body: Center(child: Text(state.message)),
          );
        }

        final loaded = state as HomeLoaded;
        return _buildLoaded(context, loaded);
      },
    );
  }

  Widget _buildLoaded(BuildContext context, HomeLoaded state) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              _buildAppBar(context, state),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8),
                    _buildGreeting(context, state),
                    const SizedBox(height: 24),
                    _buildCounterRow(context, state),
                    const SizedBox(height: 28),
                    _buildThinkingSlots(context, state),
                    const SizedBox(height: 32),
                    if (state.todaysMatches.isNotEmpty) ...[
                      _buildMatchesSection(context, state),
                      const SizedBox(height: 32),
                    ],
                    _buildAddButton(context, state),
                    const SizedBox(height: 16),
                    if (FeatureFlags.enableInAppPurchases)
                      _buildUpgradeHint(context, state),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildAppBar(BuildContext context, HomeLoaded state) {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        'thinking of u',
        style: Theme.of(context)
            .textTheme
            .displaySmall
            ?.copyWith(color: AppColors.primary),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          color: AppColors.primary,
          onPressed: () => context.push(AppRoutes.settings),
        ),
      ],
    );
  }

  Widget _buildGreeting(BuildContext context, HomeLoaded state) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, ${state.user.displayName}! 💕',
          style: Theme.of(context).textTheme.headlineMedium,
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 4),
        Text(
          'Who are you thinking of today?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onBackground.withOpacity(0.6),
              ),
        ).animate().fadeIn(delay: 100.ms),
      ],
    );
  }

  Widget _buildCounterRow(BuildContext context, HomeLoaded state) {
    final remaining = state.remainingSends;
    final total = state.user.dailyLimit;
    final used = total - remaining;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s sends',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '$used / $total',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: Colors.white,
                            fontSize: 30,
                          ),
                    ),
                    const SizedBox(width: 8),
                    ...List.generate(
                      total,
                      (i) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          i < used
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (state.user.extensionDaysRemaining > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '+${state.user.extensionDaysRemaining}d',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3, end: 0);
  }

  Widget _buildThinkingSlots(BuildContext context, HomeLoaded state) {
    final targets = state.submission?.targetHashes ?? [];
    final limit = state.user.dailyLimit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thinking of...',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ...List.generate(limit, (i) {
          final hasTarget = i < targets.length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ThinkingSlot(
              index: i,
              targetHash: hasTarget ? targets[i] : null,
              onRemove: hasTarget
                  ? () => context
                      .read<HomeBloc>()
                      .add(HomeTargetRemoved(targets[i]))
                  : null,
            ),
          );
        }),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildMatchesSection(BuildContext context, HomeLoaded state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.favorite_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Today\'s Matches! 🎉',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...state.todaysMatches.map((match) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MatchCard(
                match: match,
                myHash: state.user.phoneHash,
              ),
            )),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildAddButton(BuildContext context, HomeLoaded state) {
    final canAdd = state.remainingSends > 0;

    return HeartButton(
      onPressed: canAdd
          ? () => _showAddPhoneDialog(context, state)
          : null,
      label: canAdd
          ? 'Add someone you\'re thinking of'
          : 'No more sends today',
      icon: canAdd ? Icons.add_rounded : Icons.lock_outline_rounded,
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildUpgradeHint(BuildContext context, HomeLoaded state) {
    if (state.user.dailyLimit >= FeatureFlags.maxDailyLimit) return const SizedBox();
    return Center(
      child: TextButton.icon(
        onPressed: () => context.push(AppRoutes.store),
        icon: const Icon(Icons.stars_rounded, color: AppColors.accent),
        label: Text(
          'Get more sends in the store ✨',
          style: TextStyle(
              color: AppColors.secondary, fontWeight: FontWeight.w700),
        ),
      ),
    ).animate().fadeIn(delay: 600.ms);
  }

  Widget _buildBottomNav(BuildContext context) {
    return NavigationBar(
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        if (FeatureFlags.enableHistoryScreen)
          const NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
        if (FeatureFlags.enableInAppPurchases)
          const NavigationDestination(
            icon: Icon(Icons.stars_outlined),
            selectedIcon: Icon(Icons.stars_rounded),
            label: 'Store',
          ),
      ],
      onDestinationSelected: (index) {
        if (index == 1 && FeatureFlags.enableHistoryScreen) {
          context.push(AppRoutes.history);
        } else if (index == 2 ||
            (index == 1 && !FeatureFlags.enableHistoryScreen)) {
          context.push(AppRoutes.store);
        }
      },
    );
  }

  void _showAddPhoneDialog(BuildContext context, HomeLoaded state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => BlocProvider.value(
        value: context.read<HomeBloc>(),
        child: _AddPhoneSheet(maxTargets: state.user.dailyLimit),
      ),
    );
  }
}

class _AddPhoneSheet extends StatefulWidget {
  final int maxTargets;
  const _AddPhoneSheet({required this.maxTargets});

  @override
  State<_AddPhoneSheet> createState() => _AddPhoneSheetState();
}

class _AddPhoneSheetState extends State<_AddPhoneSheet> {
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
    final phone =
        '$_countryCode${_phoneController.text.replaceAll(RegExp(r'\D'), '')}';
    context.read<HomeBloc>().add(HomePhoneAdded(phone));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Form(
          key: _formKey,
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
              Text(
                'Who are you thinking of? 💭',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter their phone number below.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onBackground.withOpacity(0.6),
                    ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  // Country code
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.divider, width: 1.5),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _countryCode,
                        isDense: true,
                        items: const [
                          DropdownMenuItem(value: '+1', child: Text('🇺🇸 +1')),
                          DropdownMenuItem(value: '+44', child: Text('🇬🇧 +44')),
                          DropdownMenuItem(value: '+61', child: Text('🇦🇺 +61')),
                          DropdownMenuItem(value: '+91', child: Text('🇮🇳 +91')),
                          DropdownMenuItem(value: '+49', child: Text('🇩🇪 +49')),
                          DropdownMenuItem(value: '+33', child: Text('🇫🇷 +33')),
                        ],
                        onChanged: (v) =>
                            setState(() => _countryCode = v!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      autofocus: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(12),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'Their number',
                        prefixIcon: Icon(Icons.phone_outlined,
                            color: AppColors.primary),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a number';
                        }
                        final full =
                            '$_countryCode${value.replaceAll(RegExp(r'\D'), '')}';
                        if (!PhoneUtils.isValidPhoneNumber(full)) {
                          return 'Invalid phone number';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.favorite_rounded, size: 20),
                label: const Text('Send thinking of u 💌'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
