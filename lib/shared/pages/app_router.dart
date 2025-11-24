import 'package:flutter/material.dart';
import '../../shared/models/app_entry.dart';
import '../../shared/services/app_switcher_service.dart';
import '../../fourth_step/pages/fourth_step_home.dart';
import '../../eighth_step/pages/eighth_step_home.dart';
import '../../evening_ritual/pages/evening_ritual_home.dart';
import '../../gratitude/pages/gratitude_home.dart';
import '../../agnosticism/pages/agnosticism_home.dart';

/// Global app router that determines which app to display based on AppSwitcherService
class AppRouter extends StatefulWidget {
  final VoidCallback? onAppSwitched;

  const AppRouter({super.key, this.onAppSwitched});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  void _onAppSwitched() {
    setState(() {}); // Trigger rebuild when app is switched
    widget.onAppSwitched?.call();
  }

  @override
  Widget build(BuildContext context) {
    final currentAppId = AppSwitcherService.getSelectedAppId();

    // Route to the appropriate app based on selected ID
    switch (currentAppId) {
      case AvailableApps.fourthStepInventory:
        return ModularInventoryHome(
          key: ValueKey(currentAppId),
          onAppSwitched: _onAppSwitched,
        );

      case AvailableApps.eighthStepAmends:
        return EighthStepHome(
          key: ValueKey(currentAppId),
          onAppSwitched: _onAppSwitched,
        );

      case AvailableApps.eveningRitual:
        return EveningRitualHome(
          key: ValueKey(currentAppId),
          onAppSwitched: _onAppSwitched,
        );

      case AvailableApps.gratitude:
        return GratitudeHome(
          key: ValueKey(currentAppId),
          onAppSwitched: _onAppSwitched,
        );

      case AvailableApps.agnosticism:
        return AgnosticismHome(
          key: ValueKey(currentAppId),
          onAppSwitched: _onAppSwitched,
        );

      default:
        // Fallback to 4th step if unknown app ID
        return ModularInventoryHome(
          key: ValueKey(currentAppId),
        );
    }
  }
}
