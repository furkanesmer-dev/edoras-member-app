// lib/features/nutrition/ui/nutrition_hub_page.dart

import 'package:flutter/material.dart';
import 'package:edoras_member_app/core/api/api_client.dart';
import 'package:edoras_member_app/features/nutrition/nutrition_plans_page.dart';

class NutritionHubPage extends StatefulWidget {
  final ApiClient apiClient;

  const NutritionHubPage({
    super.key,
    required this.apiClient,
  });

  @override
  State<NutritionHubPage> createState() => NutritionHubPageState();
}

class NutritionHubPageState extends State<NutritionHubPage> {
  final _plansKey = GlobalKey<NutritionPlansPageState>();

  /// MainShell gibi yerlerden çağrılabilsin
  Future<void> reloadPlans() async {
    await _plansKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: NutritionPlansPage(
            key: _plansKey,
            apiClient: widget.apiClient,
          ),
        ),
      ),
    );
  }
}