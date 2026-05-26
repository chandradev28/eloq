import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/conversation/screens/conversation_screen.dart';
import '../../features/handsfree/screens/handsfree_screen.dart';
import '../../features/history/screens/history_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/live_voice/screens/live_voice_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/progress/screens/progress_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../../features/topics/screens/topics_screen.dart';
import '../../features/vocabulary/screens/vocabulary_screen.dart';
import '../../models/conversation_session.dart';
import '../theme/app_colors.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final onboarding = ref.watch(
    settingsProvider.select(
      (settings) => (
        isLoaded: settings.isLoaded,
        hasCompleted: settings.hasCompletedOnboarding,
      ),
    ),
  );

  return GoRouter(
    initialLocation: '/onboarding',
    redirect: (context, state) {
      if (!onboarding.isLoaded) return null;
      final path = state.uri.path;
      final isOnboarding = path == '/onboarding';
      if (!onboarding.hasCompleted && !isOnboarding) {
        return '/onboarding';
      }
      if (onboarding.hasCompleted && isOnboarding) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/topics',
            builder: (context, state) => const TopicsScreen(),
          ),
          GoRoute(
            path: '/progress',
            builder: (context, state) => const ProgressScreen(),
          ),
          GoRoute(
            path: '/vocabulary',
            builder: (context, state) => const VocabularyScreen(),
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/conversation/:topicId',
        builder: (context, state) {
          final session = state.extra is ConversationSession
              ? state.extra as ConversationSession
              : null;
          return ConversationScreen(
            topicId: state.pathParameters['topicId'] ?? 'restaurant',
            session: session,
          );
        },
      ),
      GoRoute(
        path: '/handsfree',
        builder: (context, state) {
          final session = state.extra is ConversationSession
              ? state.extra as ConversationSession
              : null;
          return HandsfreeScreen(session: session);
        },
      ),
      GoRoute(
        path: '/live-voice',
        builder: (context, state) {
          final session = state.extra is ConversationSession
              ? state.extra as ConversationSession
              : null;
          return LiveVoiceScreen(session: session);
        },
      ),
    ],
  );
});

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final index = switch (path) {
      String p when p.startsWith('/topics') => 1,
      String p when p.startsWith('/progress') => 2,
      String p when p.startsWith('/vocabulary') => 3,
      String p when p.startsWith('/history') => 3,
      String p when p.startsWith('/settings') => 4,
      _ => 0,
    };

    return Scaffold(
      backgroundColor: AppColors.page(context),
      body: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            left: 24,
            right: 24,
            bottom: 12,
            child: SafeArea(
              child: _FloatingDock(
                selectedIndex: index,
                onSelected: (selected) {
                  final routes = [
                    '/home',
                    '/topics',
                    '/progress',
                    '/vocabulary',
                    '/settings',
                  ];
                  context.go(routes[selected]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingDock extends StatelessWidget {
  const _FloatingDock({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const icons = [
      Icons.headphones_rounded,
      Icons.search_rounded,
      Icons.insert_chart_outlined_rounded,
      Icons.rate_review_rounded,
      Icons.settings_rounded,
    ];
    const labels = ['Home', 'Topics', 'Progress', 'Review', 'Settings'];

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 390),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.dock,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.24),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < icons.length; i++)
              _DockButton(
                icon: icons[i],
                label: labels[i],
                selected: selectedIndex == i,
                onTap: () => onSelected(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppColors.accentPurple : AppColors.dockItem,
          ),
          child: Icon(
            icon,
            color: selected ? Colors.white : Colors.white.withOpacity(0.62),
            size: 23,
          ),
        ),
      ),
    );
  }
}
