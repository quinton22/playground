import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../blocs/auth/auth_bloc.dart';
import '../models/match_model.dart';
import '../services/submission_service.dart';
import '../theme/app_colors.dart';
import '../widgets/match_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<MatchModel>? _matches;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final matches = await context.read<SubmissionService>().getMatchHistory(
          authState.user.phoneHash,
        );
    if (mounted) {
      setState(() {
        _matches = matches;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      'Match History',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ),

              if (_loading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_matches == null || _matches!.isEmpty)
                _buildEmpty(context)
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    itemCount: _matches!.length,
                    itemBuilder: (context, i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: MatchCard(
                          match: _matches![i],
                          myHash: user?.phoneHash ?? '',
                          showDate: true,
                        )
                            .animate()
                            .fadeIn(delay: (i * 50).ms)
                            .slideY(begin: 0.2, end: 0),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.primaryGradient.createShader(bounds),
              child: const Icon(
                Icons.favorite_border_rounded,
                size: 80,
                color: Colors.white,
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text(
              'No matches yet',
              style: Theme.of(context).textTheme.headlineMedium,
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 8),
            Text(
              'Start thinking of people and\nwatch the magic happen! ✨',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onBackground.withOpacity(0.6),
                  ),
            ).animate().fadeIn(delay: 300.ms),
          ],
        ),
      ),
    );
  }
}
