import 'package:flutter/material.dart';
import '../localizations.dart';
import '../models/app_entry.dart';

/// Service providing context-sensitive help content for each app
class AppHelpService {
  /// Get help content for a specific app
  static AppHelpContent getHelpContent(BuildContext context, String appId) {
    switch (appId) {
      case AvailableApps.fourthStepInventory:
        return AppHelpContent(
          title: t(context, 'help_4th_step_title'),
          sections: [
            HelpSection(
              title: t(context, 'help_4th_step_purpose_title'),
              content: t(context, 'help_4th_step_purpose'),
            ),
            HelpSection(
              title: t(context, 'help_4th_step_fields_title'),
              content: t(context, 'help_4th_step_fields'),
            ),
            HelpSection(
              title: t(context, 'help_4th_step_i_am_title'),
              content: t(context, 'help_4th_step_i_am'),
            ),
          ],
        );

      case AvailableApps.eighthStepAmends:
        return AppHelpContent(
          title: t(context, 'help_8th_step_title'),
          sections: [
            HelpSection(
              title: t(context, 'help_8th_step_purpose_title'),
              content: t(context, 'help_8th_step_purpose'),
            ),
            HelpSection(
              title: t(context, 'help_8th_step_fields_title'),
              content: t(context, 'help_8th_step_fields'),
            ),
          ],
        );

      case AvailableApps.eveningRitual:
        return AppHelpContent(
          title: t(context, 'help_evening_ritual_title'),
          sections: [
            HelpSection(
              title: t(context, 'help_evening_ritual_purpose_title'),
              content: t(context, 'help_evening_ritual_purpose'),
            ),
            HelpSection(
              title: t(context, 'help_evening_ritual_reflection_types_title'),
              content: t(context, 'help_evening_ritual_reflection_types'),
            ),
            HelpSection(
              title: t(context, 'help_evening_ritual_focus_title'),
              content: t(context, 'help_evening_ritual_focus'),
            ),
          ],
        );

      case AvailableApps.gratitude:
        return AppHelpContent(
          title: t(context, 'help_gratitude_title'),
          sections: [
            HelpSection(
              title: t(context, 'help_gratitude_purpose_title'),
              content: t(context, 'help_gratitude_purpose'),
            ),
            HelpSection(
              title: t(context, 'help_gratitude_practice_title'),
              content: t(context, 'help_gratitude_practice'),
            ),
          ],
        );

      case AvailableApps.agnosticism:
        return AppHelpContent(
          title: t(context, 'help_agnosticism_title'),
          sections: [
            HelpSection(
              title: t(context, 'help_agnosticism_purpose_title'),
              content: t(context, 'help_agnosticism_purpose'),
            ),
            HelpSection(
              title: t(context, 'help_agnosticism_side_a_title'),
              content: t(context, 'help_agnosticism_side_a'),
            ),
            HelpSection(
              title: t(context, 'help_agnosticism_side_b_title'),
              content: t(context, 'help_agnosticism_side_b'),
            ),
            HelpSection(
              title: t(context, 'help_agnosticism_process_title'),
              content: t(context, 'help_agnosticism_process'),
            ),
          ],
        );

      default:
        return AppHelpContent(
          title: 'Help',
          sections: [
            HelpSection(
              title: 'Information',
              content: 'Help content not available for this app.',
            ),
          ],
        );
    }
  }

  /// Show help dialog for current app
  static void showHelpDialog(BuildContext context, String appId) {
    final helpContent = getHelpContent(context, appId);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.help_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(helpContent.title)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: helpContent.sections.map((section) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      section.content,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t(context, 'close')),
          ),
        ],
      ),
    );
  }
}

/// Data class for help content
class AppHelpContent {
  final String title;
  final List<HelpSection> sections;

  AppHelpContent({
    required this.title,
    required this.sections,
  });
}

/// Data class for help section
class HelpSection {
  final String title;
  final String content;

  HelpSection({
    required this.title,
    required this.content,
  });
}
