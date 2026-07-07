import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/iptv_account.dart';
import '../models/series_item.dart';
import '../models/vod_item.dart';
import '../presentation/screens/accounts_screen.dart';
import '../presentation/screens/home_screen.dart';
import '../presentation/screens/live_player_screen.dart';
import '../presentation/screens/login_screen.dart';
import '../presentation/screens/mac_activation_screen.dart';
import '../presentation/screens/movie_details_screen.dart';
import '../presentation/screens/parental_screen.dart';
import '../presentation/screens/profiles_screen.dart';
import '../presentation/screens/statistics_screen.dart';
import '../presentation/screens/player_screen.dart';
import '../presentation/screens/series_details_screen.dart';
import '../presentation/screens/splash_screen.dart';

/// Transition premium : fondu + léger glissement vertical + zoom subtil.
CustomTransitionPage<void> _premiumPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Configuration GoRouter avec transitions animées.
final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      pageBuilder: (context, state) =>
          _premiumPage(state, const SplashScreen()),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) =>
          _premiumPage(state, const LoginScreen()),
    ),
    GoRoute(
      path: '/accounts',
      pageBuilder: (context, state) =>
          _premiumPage(state, const AccountsScreen()),
    ),
    GoRoute(
      path: '/mac-activation',
      pageBuilder: (context, state) => _premiumPage(
        state,
        MacActivationScreen(account: state.extra as IptvAccount?),
      ),
    ),
    GoRoute(
      path: '/home',
      pageBuilder: (context, state) => _premiumPage(state, const HomeScreen()),
    ),
    GoRoute(
      path: '/live-player',
      pageBuilder: (context, state) => _premiumPage(
          state, LivePlayerScreen(args: state.extra! as LivePlayerArgs)),
    ),
    GoRoute(
      path: '/player',
      pageBuilder: (context, state) =>
          _premiumPage(state, PlayerScreen(args: state.extra! as PlayerArgs)),
    ),
    GoRoute(
      path: '/profiles',
      pageBuilder: (context, state) =>
          _premiumPage(state, const ProfilesScreen()),
    ),
    GoRoute(
      path: '/parental',
      pageBuilder: (context, state) =>
          _premiumPage(state, const ParentalScreen()),
    ),
    GoRoute(
      path: '/stats',
      pageBuilder: (context, state) =>
          _premiumPage(state, const StatisticsScreen()),
    ),
    GoRoute(
      path: '/movie/:id',
      pageBuilder: (context, state) => _premiumPage(
          state, MovieDetailsScreen(movie: state.extra! as VodItem)),
    ),
    GoRoute(
      path: '/series/:id',
      pageBuilder: (context, state) => _premiumPage(
          state, SeriesDetailsScreen(series: state.extra! as SeriesItem)),
    ),
  ],
);
