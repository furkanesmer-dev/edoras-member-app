import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:edoras_member_app/core/api/api_client.dart';
import 'package:edoras_member_app/core/storage/token_storage.dart';
import 'package:edoras_member_app/core/theme/app_colors.dart';
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

  final _homeKey      = GlobalKey<HomeScreenState>();
  final _sessionsKey  = GlobalKey<MySessionsPageState>();
  final _workoutKey   = GlobalKey<WorkoutPlanPageState>();
  final _nutritionHubKey = GlobalKey<NutritionHubPageState>();

  Future<void> _reloadCurrent() async {
    if (_index == 0)      await _homeKey.currentState?.reload();
    else if (_index == 1) await _sessionsKey.currentState?.reload();
    else if (_index == 2) await _workoutKey.currentState?.reloadPlans();
    else if (_index == 3) await _nutritionHubKey.currentState?.reloadPlans();
  }

  void _onTabChange(int i) {
    if (_index == i) {
      Future.microtask(_reloadCurrent);
      return;
    }
    setState(() => _index = i);
    Future.microtask(_reloadCurrent);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        key: _homeKey,
        apiClient: widget.apiClient,
        tokenStorage: widget.tokenStorage,
        onOpenSessions:  () => _onTabChange(1),
        onOpenWorkouts:  () => _onTabChange(2),
        onOpenNutrition: () => _onTabChange(3),
        onOpenProfile:   () => _onTabChange(4),
      ),
      MySessionsPage(key: _sessionsKey, apiClient: widget.apiClient),
      WorkoutPlanPage(key: _workoutKey, apiClient: widget.apiClient),
      NutritionHubPage(key: _nutritionHubKey, apiClient: widget.apiClient),
      ProfileScreen(apiClient: widget.apiClient, tokenStorage: widget.tokenStorage),
    ];

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: _BottomBar(
        currentIndex: _index,
        onTap: _onTabChange,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomBar({required this.currentIndex, required this.onTap});

  static const _items = [
    _NavItem(label: 'Ana Sayfa', icon: Icons.grid_view_rounded),
    _NavItem(label: 'Seanslar',  icon: Icons.calendar_month_rounded),
    _NavItem(label: 'Antrenman', icon: Icons.local_fire_department_rounded),
    _NavItem(label: 'Beslenme',  icon: Icons.restaurant_rounded),
    _NavItem(label: 'Profil',    icon: Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface2.withOpacity(0.95)
                    : Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? AppColors.primary.withOpacity(0.20)
                      : AppColors.lightBorder,
                  width: 1,
                ),
                boxShadow: [
                  if (isDark)
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 0),
                    ),
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.55)
                        : Colors.black.withOpacity(0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: List.generate(
                    _items.length,
                    (i) => Expanded(
                      child: _BarItem(
                        item: _items[i],
                        selected: currentIndex == i,
                        onTap: () => onTap(i),
                        isDark: isDark,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  const _BarItem({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor   = isDark ? AppColors.primaryLight : AppColors.primary;
    final inactiveColor = isDark ? AppColors.darkTextSub  : AppColors.lightTextSub;
    final fg = selected ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [
                    activeColor.withOpacity(0.18),
                    activeColor.withOpacity(0.07),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Icon(item.icon, size: 22, color: fg),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                height: 1,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: fg,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem({required this.label, required this.icon});
}