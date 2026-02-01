import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

Widget statusCard(
  BuildContext context, {
  required String title,
  required String subtitle,
  required IconData icon,
  bool? active,
  VoidCallback? onTap,
}) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  final splashColor = cs.primary.withValues(alpha: 0.04);
  final hoverColor = cs.primary.withValues(alpha: 0.02);

  return Card(
    child: InkWell(
      onTap: onTap,
      splashColor: splashColor,
      hoverColor: hoverColor,
      focusColor: hoverColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          spacing: 16,
          children: [
            Icon(icon),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  spacing: 4,
                  children: [
                    Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    if (active != null) ...[
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 70,
                        height: 32,
                        child: Card(
                          color: active ? Colors.green[800] : Colors.red,
                          child: Center(
                            child: Text(
                              active ? 'online'.tr() : 'offline'.tr(),
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  subtitle,
                  style: tt.labelSmall?.copyWith(
                    fontFamily: 'Oxanium',
                    color: Colors.grey,
                    fontVariations: [const FontVariation('wght', 500)],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
