import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:edoras_member_app/core/api/api_client.dart';
import 'package:edoras_member_app/core/storage/token_storage.dart';
import 'package:edoras_member_app/features/home/home_screen.dart';
import 'package:edoras_member_app/features/profile/profile_screen.dart';
import 'package:edoras_member_app/features/sessions/my_sessions_page.dart';
import 'package:edoras_member_app/features/workout/workout_plan_page.dart';
import 'package:edoras_member_app/features/nutrition/nutrition_hub_page.dart';

class MainShell extends StatefulWidget {
  final ApiClient apiClient;
  final TokenStorage tokenStorage;

  const MainShell({
    super.key,
    required this.apiClient,
    required this.tokenStorage,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _homeKey = GlobalKey<HomeScreenState>();
  final _sessionsKey = GlobalKey<MySessionsPageState>();
  final _workoutKey = GlobalKey<WorkoutPlanPageState>();
  final _nutritionHubKey = GlobalKey<NutritionHubPageState>();

  Future<void> _reloadCurrent() async {
    if (_index == 0) {
      await _homeKey.currentState?.reload();
    } else if (_index == 1) {
      await _sessionsKey.currentState?.reload();
    } else if (_index == 2) {
      await _workoutKey.currentState?.reloadPlans();
    } else if (_index == 3) {
      await _nutritionHubKey.currentState?.reloadPlans();
    }
  }

  void _onTabChange(int i) {
    if (_index == i) {
      Future.microtask(() => _reloadCurrent());
      return;
    }

    setState(() => _index = i);
    Future.microtask(() => _reloadCurrent());
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        key: _homeKey,
        apiClient: widget.apiClient,
        tokenStorage: widget.tokenStorage,
        onOpenSessions: () => _onTabChange(1),
        onOpenWorkouts: () => _onTabChange(2),
        onOpenNutrition: () => _onTabChange(3),
        onOpenProfile: () => _onTabChange(4),
      ),
      MySessionsPage(
        key: _sessionsKey,
        apiClient: widget.apiClient,
      ),
      WorkoutPlanPage(
        key: _workoutKey,
        apiClient: widget.apiClient,
      ),
      NutritionHubPage(
        key: _nutritionHubKey,
        apiClient: widget.apiClient,
      ),
      ProfileScreen(
        apiClient: widget.apiClient,
        tokenStorage: widget.tokenStorage,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: pages,
        ),
      ),
      bottomNavigationBar: _PremiumBottomBar(
        currentIndex: _index,
        onTap: _onTabChange,
      ),
    );
  }
}

class _PremiumBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _PremiumBottomBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavItemData(
        label: 'Ana Sayfa',
        icon: Icons.space_dashboard_rounded,
        accent: Color(0xFF4F7CFF),
      ),
      _NavItemData(
        label: 'Seanslar',
        icon: Icons.event_available_rounded,
        accent: Color(0xFF14B86A),
      ),
      _NavItemData(
        label: 'Antrenman',
        icon: Icons.local_fire_department_rounded,
        accent: Color(0xFFFF7A18),
      ),
      _NavItemData(
        label: 'Beslenme',
        icon: Icons.restaurant_menu_rounded,
        accent: Color(0xFF00A86B),
      ),
      _NavItemData(
        label: 'Profil',
        icon: Icons.account_circle_rounded,
        accent: Color(0xFF8B5CF6),
      ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: 62,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFE6EDF7),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8DAEF5).withOpacity(0.16),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(items.length, (i) {
                  final item = items[i];
                  final selected = currentIndex == i;

                  return Expanded(
                    child: _PremiumBottomBarItem(
                      label: item.label,
                      icon: item.icon,
                      accent: item.accent,
                      selected: selected,
                      onTap: () => onTap(i),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumBottomBarItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _PremiumBottomBarItem({
    required this.label,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? accent : const Color(0xFF7A879A);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accent.withOpacity(0.16),
                      accent.withOpacity(0.08),
                    ],
                  )
                : null,
            border: selected
                ? Border.all(
                    color: accent.withOpacity(0.14),
                    width: 1,
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: selected ? 20 : 0,
                height: 2.5,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: selected ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Icon(
                icon,
                size: 20,
                color: fg,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 9.6,
                      height: 1,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: fg,
                      letterSpacing: 0.05,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final String label;
  final IconData icon;
  final Color accent;

  const _NavItemData({
    required this.label,
    required this.icon,
    required this.accent,
  });
}