import 'package:flutter/material.dart';
import '../../shared/models/app_entry.dart';
import '../../shared/services/app_switcher_service.dart';
import '../../fourth_step/pages/fourth_step_home.dart';
import '../../eighth_step/pages/eighth_step_home.dart';
import '../../evening_ritual/pages/evening_ritual_home.dart';
import '../../morning_ritual/pages/morning_ritual_home.dart';
import '../../gratitude/pages/gratitude_home.dart';
import '../../agnosticism/pages/agnosticism_home.dart';
import '../../notifications/pages/notifications_home.dart';

/// Global app router that determines which app to display based on AppSwitcherService.
/// 
/// Uses [ValueListenableBuilder] to automatically rebuild when the selected app
/// changes, eliminating the need for manual setState calls or callback propagation.
class AppRouter extends StatelessWidget {
  /// Optional callback for additional side effects when app changes.
  /// Note: UI rebuilds happen automatically via ValueListenableBuilder.
  final VoidCallback? onAppSwitched;

  const AppRouter({super.key, this.onAppSwitched});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppSwitcherService.selectedAppNotifier,
      builder: (context, currentAppId, _) {
        // Notify parent after frame completes (for any additional side effects)
        if (onAppSwitched != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onAppSwitched!();
          });
        }

        return _buildAppForId(currentAppId);
      },
    );
  }

  /// Build the appropriate app widget for the given app ID
  Widget _buildAppForId(String currentAppId) {
    switch (currentAppId) {
      case AvailableApps.fourthStepInventory:
        return ModularInventoryHome(key: ValueKey(currentAppId));

      case AvailableApps.eighthStepAmends:
        return EighthStepHome(key: ValueKey(currentAppId));

      case AvailableApps.eveningRitual:
        return EveningRitualHome(key: ValueKey(currentAppId));

      case AvailableApps.morningRitual:
        return MorningRitualHome(key: ValueKey(currentAppId));

      case AvailableApps.gratitude:
        return GratitudeHome(key: ValueKey(currentAppId));

      case AvailableApps.agnosticism:
        return AgnosticismHome(key: ValueKey(currentAppId));

      case AvailableApps.notifications:
        return NotificationsHome(key: ValueKey(currentAppId));

      default:
        // Fallback to 4th step if unknown app ID
        return ModularInventoryHome(key: ValueKey(currentAppId));
    }
  }
}
