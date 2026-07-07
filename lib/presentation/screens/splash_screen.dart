import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../themes/app_colors.dart';
import '../../widgets/premium_background.dart';

/// Splash premium : orbes animés, logo avec halo pulsant,
/// titre en dégradé, restauration de session en arrière-plan.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final results = await Future.wait([
      ref.read(authProvider.notifier).tryRestore(),
      Future.delayed(const Duration(milliseconds: 2000)),
    ]);
    if (!mounted) return;
    final restored = results.first as bool;

    if (restored) {
      context.go('/home');
      return;
    }

    // Restauration échouée : diriger vers l'écran le plus pertinent.
    final state = ref.read(authProvider);
    if (state is AuthError && state.activationPending) {
      // Compte MAC toujours en attente d'activation.
      context.go('/mac-activation');
      return;
    }
    final accounts = await ref.read(authProvider.notifier).accounts();
    if (!mounted) return;
    context.go(accounts.isNotEmpty ? '/accounts' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo avec halo pulsant
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 150,
                    height: 150,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0x557C3AED), Colors.transparent],
                      ),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        begin: const Offset(0.85, 0.85),
                        end: const Offset(1.15, 1.15),
                        duration: 1400.ms,
                        curve: Curves.easeInOut,
                      ),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                      boxShadow: AppColors.glow(AppColors.seed, blur: 32),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        size: 58, color: Colors.white),
                  )
                      .animate()
                      .scale(
                        duration: 600.ms,
                        curve: Curves.easeOutBack,
                        begin: const Offset(0.4, 0.4),
                      )
                      .then()
                      .shimmer(duration: 1100.ms, color: Colors.white38),
                ],
              ),
              const SizedBox(height: 32),
              // Titre en dégradé
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppColors.brandGradient.createShader(bounds),
                child: const Text(
                  'PREMIUM IPTV',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                ),
              ).animate().fadeIn(delay: 350.ms, duration: 600.ms).slideY(
                    begin: 0.3,
                    end: 0,
                    curve: Curves.easeOutCubic,
                  ),
              const SizedBox(height: 6),
              const Text(
                'PLAYER',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  letterSpacing: 10,
                  fontWeight: FontWeight.w500,
                ),
              ).animate().fadeIn(delay: 550.ms, duration: 600.ms),
              const SizedBox(height: 48),
              const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: Colors.white70,
                ),
              ).animate().fadeIn(delay: 800.ms),
            ],
          ),
        ),
      ),
    );
  }
}
