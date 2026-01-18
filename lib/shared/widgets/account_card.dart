import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

Widget statusCard(
  BuildContext context, {
  required String title,
  required String subtitle,
  required IconData icon,
  bool? active,
}) {
  final tt = Theme.of(context).textTheme;

  return Card.outlined(
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
                    Text(
                      '•',
                      style: TextStyle(
                        color: active ? Colors.green : Colors.red,
                        fontSize: tt.titleMedium?.fontSize ?? 20,
                      ),
                    ),
                    Text(active ? 'online'.tr() : 'offline'.tr(), style: TextStyle(color: Colors.grey)),
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
  );
}
