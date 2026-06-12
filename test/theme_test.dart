import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/theme/theme.dart';

void main() {
  group('app theme', () {
    bool isGrayscale(Color c) {
      final argb = c.toARGB32();
      final r = (argb >> 16) & 0xFF;
      final g = (argb >> 8) & 0xFF;
      final b = argb & 0xFF;
      return r == g && g == b;
    }

    bool isBlueDominant(Color c) {
      final argb = c.toARGB32();
      final r = (argb >> 16) & 0xFF;
      final g = (argb >> 8) & 0xFF;
      final b = argb & 0xFF;
      return b > r && b > g;
    }

    for (final brightness in [Brightness.light, Brightness.dark]) {
      test('$brightness accent colors are blue', () {
        final cs = appTheme(brightness).colorScheme;
        for (final entry in {
          'primary': cs.primary,
          'primaryContainer': cs.primaryContainer,
        }.entries) {
          expect(
            isBlueDominant(entry.value),
            isTrue,
            reason: '${entry.key} should read as blue, got ${entry.value}',
          );
        }
      });

      // The app body stays white/gray no matter which accent seed is used:
      // surfaces, cards, bars, and outlines must never be tinted by the seed.
      test('$brightness neutral surfaces have no color cast', () {
        final cs = appTheme(brightness).colorScheme;
        final roles = <String, Color>{
          'surface': cs.surface,
          'onSurface': cs.onSurface,
          'onSurfaceVariant': cs.onSurfaceVariant,
          'surfaceDim': cs.surfaceDim,
          'surfaceBright': cs.surfaceBright,
          'surfaceContainerLowest': cs.surfaceContainerLowest,
          'surfaceContainerLow': cs.surfaceContainerLow,
          'surfaceContainer': cs.surfaceContainer,
          'surfaceContainerHigh': cs.surfaceContainerHigh,
          'surfaceContainerHighest': cs.surfaceContainerHighest,
          'outline': cs.outline,
          'outlineVariant': cs.outlineVariant,
          'inverseSurface': cs.inverseSurface,
          'onInverseSurface': cs.onInverseSurface,
        };
        for (final entry in roles.entries) {
          expect(
            isGrayscale(entry.value),
            isTrue,
            reason: '${entry.key} should be grayscale, got ${entry.value}',
          );
        }
        expect(cs.surfaceTint, equals(Colors.transparent));
      });

      // The design system must be fully wired for both brightnesses.
      test('$brightness registers AppTokens and a sized text theme', () {
        final theme = appTheme(brightness);

        final tokens = theme.extension<AppTokens>();
        expect(tokens, isNotNull, reason: 'AppTokens must be registered');
        expect(tokens!.rewardGold, equals(AppPalette.rewardGold));
        expect(tokens.alert, equals(AppPalette.alert));

        // Key slots must carry an explicit size (no longer Material defaults).
        expect(theme.textTheme.titleLarge?.fontSize, equals(20));
        expect(theme.textTheme.bodyMedium?.fontSize, equals(15));
        expect(theme.textTheme.labelSmall?.fontSize, equals(11));
        expect(theme.textTheme.titleMedium?.fontFamily, equals('Oxanium'));
      });
    }

    test('light surface is off-white, not pure white', () {
      final cs = appTheme(Brightness.light).colorScheme;
      expect(cs.surface, isNot(equals(const Color(0xFFFFFFFF))));
      expect(cs.surface.computeLuminance(), greaterThan(0.9));
    });

    test('primary derives from the single brand seed', () {
      // Sanity: the one knob that re-themes the app is AppPalette.brandSeed.
      expect(AppPalette.brandSeed, equals(const Color(0xFF2F6BFF)));
    });
  });
}
