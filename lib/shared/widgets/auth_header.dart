import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';

/// The top of the sign-in page: who this app is. The mascot theme shows the
/// mascot, the classic theme the app logo; both then say the name and one line
/// about what the app does, so the first screen is not an empty page with a
/// word on it.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        context.isMascot
            ? Image.asset(
                'assets/mascot-assets/happy.webp',
                height: 140,
                fit: BoxFit.contain,
              )
            : ClipRRect(
                borderRadius: AppRadius.cardR,
                child: Image.asset(
                  'assets/images/silversole_app_logo.png',
                  height: 96,
                  width: 96,
                  fit: BoxFit.cover,
                ),
              ),
        const SizedBox(height: AppSpacing.base),
        // Shrinks rather than wraps: at a 1.3 system text scale on a narrow
        // iPhone the name split as "SilverSol / e".
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'silversole'.tr(),
            maxLines: 1,
            style: context.textTheme.displayLarge,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'auth_tagline'.tr(),
          textAlign: TextAlign.center,
          style: context.textTheme.bodyLarge?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
