import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

Widget accountCard(BuildContext context, String email, String uuid) {
  final tt = Theme.of(context).textTheme;

  return Card.outlined(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        spacing: 16,
        children: [
          const Icon(LucideIcons.user),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(email, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text(
                uuid,
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
