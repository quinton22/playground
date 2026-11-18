import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../blocs/auth/auth_bloc.dart';
import '../services/purchase_service.dart';
import '../theme/app_colors.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  @override
  void initState() {
    super.initState();
    _initPurchases();
  }

  Future<void> _initPurchases() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final service = context.read<PurchaseService>();
    await service.initialize(authState.user.phoneHash);
  }

  @override
  Widget build(BuildContext context) {
    final purchaseService = context.read<PurchaseService>();

    return StreamBuilder<PurchaseResult>(
      stream: purchaseService.purchaseResults,
      builder: (context, snapshot) {
        // Show result snackbars
        if (snapshot.hasData) {
          final result = snapshot.data!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (result.status == PurchaseResultStatus.success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Purchase successful! 🎉'),
                  backgroundColor: AppColors.success,
                ),
              );
            } else if (result.status == PurchaseResultStatus.error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result.message ?? 'Purchase failed'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          });
        }

        return Scaffold(
          body: Container(
            decoration:
                const BoxDecoration(gradient: AppColors.backgroundGradient),
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
                          '✨ Store',
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
                        _buildHeader(context),
                        const SizedBox(height: 24),
                        _buildSectionTitle(context, '💌 More Sends'),
                        const SizedBox(height: 12),
                        _buildProductCard(
                          context,
                          purchaseService,
                          ProductIds.extraSend1,
                          title: '+1 Extra Send',
                          subtitle: 'Think of one more person today',
                          icon: Icons.favorite_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE91E8C), Color(0xFFFF6B6B)],
                          ),
                          delay: 0,
                        ),
                        const SizedBox(height: 10),
                        _buildProductCard(
                          context,
                          purchaseService,
                          ProductIds.extraSend3,
                          title: '+3 Extra Sends',
                          subtitle: 'Best value! Think of 3 more people',
                          icon: Icons.favorite_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF9C27B0), Color(0xFFE91E8C)],
                          ),
                          badge: 'BEST VALUE',
                          delay: 100,
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle(context, '⏳ Extensions'),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Give unreciprocated sends more time before they reset.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.onBackground
                                          .withOpacity(0.6),
                                    ),
                          ),
                        ),
                        _buildProductCard(
                          context,
                          purchaseService,
                          ProductIds.extension1Day,
                          title: '+1 Day Extension',
                          subtitle: 'Extend reset window by 24 hours',
                          icon: Icons.timer_outlined,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF43A047), Color(0xFF00BCD4)],
                          ),
                          delay: 200,
                        ),
                        const SizedBox(height: 10),
                        _buildProductCard(
                          context,
                          purchaseService,
                          ProductIds.extension3Days,
                          title: '+3 Day Extension',
                          subtitle: 'Extend reset window by 3 days',
                          icon: Icons.timer_outlined,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00BCD4), Color(0xFF3F51B5)],
                          ),
                          badge: 'BEST VALUE',
                          delay: 300,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          const Icon(Icons.stars_rounded, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spread more love! 💕',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Purchase extra sends or extensions to keep the warmth going.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.85),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall,
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    PurchaseService service,
    String productId, {
    required String title,
    required String subtitle,
    required IconData icon,
    required LinearGradient gradient,
    String? badge,
    int delay = 0,
  }) {
    final product = service.products.where((p) => p.id == productId).firstOrNull;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: product != null
                  ? () => service.purchase(product)
                  : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              child: Text(product?.price ?? '...'),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: delay.ms, duration: 400.ms)
        .slideY(begin: 0.2, end: 0);
  }
}
