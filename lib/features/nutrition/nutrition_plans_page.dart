// lib/features/nutrition/nutrition_plans_page.dart

import 'package:flutter/material.dart';
import 'package:edoras_member_app/core/api/api_client.dart';
import 'package:edoras_member_app/features/nutrition/nutrition_plan_page.dart';

class NutritionPlansPage extends StatefulWidget {
  final ApiClient apiClient;

  const NutritionPlansPage({
    super.key,
    required this.apiClient,
  });

  @override
  State<NutritionPlansPage> createState() => NutritionPlansPageState();
}

class NutritionPlansPageState extends State<NutritionPlansPage> {
  final _planKey = GlobalKey<NutritionPlanPageState>();

  Future<void> reload() async {
    await _planKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return NutritionPlanPage(
      key: _planKey,
      apiClient: widget.apiClient,
    );
  }
}