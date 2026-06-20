import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/dialogs/basic_dialog.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/widgets/3d_model_preview.dart';

/// Swipeable device carousel shown at the top of the home body.
///
/// One page per paired device plus a trailing "add device" page. The current
/// (preferred) device renders the live [Model3DPreview]; the others render a
/// cheap static image to save performance. Swiping onto a different device asks
/// for confirmation before switching; releasing on the "+" page snaps back to
/// the last device (the add flow isn't built yet). Transparent — no background.
class DeviceCarousel extends ConsumerStatefulWidget {
  const DeviceCarousel({super.key, this.heightFactor = 0.3});

  /// Fraction of the screen height the carousel occupies.
  final double heightFactor;

  @override
  ConsumerState<DeviceCarousel> createState() => _DeviceCarouselState();
}

class _DeviceCarouselState extends ConsumerState<DeviceCarousel> {
  late final PageController _controller;

  // True while we drive the PageView ourselves (snap-backs / cancel), so the
  // resulting onPageChanged callbacks don't re-trigger the switch flow.
  bool _programmatic = false;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = _preferredIndex(
      ref.read(settingsProvider).pairedDevicesList,
    );
    _controller = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _preferredIndex(List<BlePairedDevice> devices) {
    final i = devices.indexWhere((d) => d.isPreferred);
    return i < 0 ? 0 : i;
  }

  Future<void> _animateTo(int index) async {
    _programmatic = true;
    await _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    _programmatic = false;
  }

  Future<void> _onPageChanged(int index) async {
    if (!mounted) return;
    setState(() => _currentPage = index);
    if (_programmatic) return;

    final devices = ref.read(settingsProvider).pairedDevicesList;
    final addIndex = devices.length;
    final preferredIdx = _preferredIndex(devices);

    // Released on the trailing "+" page: snap back to the last device.
    if (index == addIndex) {
      await _animateTo(addIndex - 1);
      return;
    }

    // Same device as the current one: nothing to do.
    if (index == preferredIdx) return;

    // A different device: confirm before switching, revert on cancel.
    final target = devices[index];
    await showConfirmLeaveDialog(
      context,
      icon: const Icon(LucideIcons.refreshCw),
      title: 'switch_device_title'.tr(),
      text: 'switch_device_body'.tr(args: [target.name]),
      onConfirm: () =>
          ref.read(settingsProvider.notifier).setPreferredDevice(target),
      onDismiss: () => _animateTo(preferredIdx),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(
      settingsProvider.select((s) => s.pairedDevicesList),
    );
    final preferredIdx = _preferredIndex(devices);
    final pageCount = devices.length + 1; // devices + the "add device" page
    final height = MediaQuery.sizeOf(context).height * widget.heightFactor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: _onPageChanged,
            itemCount: pageCount,
            itemBuilder: (context, index) {
              if (index == devices.length) return const _AddDevicePage();
              // Only the current device gets the (eventually live) 3D model;
              // the rest stay a cheap static image to save performance.
              return index == preferredIdx
                  ? Model3DPreview(heightFactor: widget.heightFactor)
                  : const _StaticModelImage();
            },
          ),
        ),
        _DotsIndicator(count: pageCount, active: _currentPage),
      ],
    );
  }
}

/// Lightweight static product image for non-active devices.
class _StaticModelImage extends StatelessWidget {
  const _StaticModelImage();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Image.asset(
        'assets/images/silversole_full.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

/// Trailing "add device" affordance. No add flow yet — releasing here snaps
/// back to the last device.
class _AddDevicePage extends StatelessWidget {
  const _AddDevicePage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.md,
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: context.colorScheme.outlineVariant,
                width: 2,
              ),
            ),
            child: Icon(
              LucideIcons.plus,
              size: 40,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            'add_device'.tr(),
            style: context.textTheme.labelLarge?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Classic bottom dots; the active page's dot is filled with the brand color.
class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: AppSpacing.sm,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == active
                  ? context.colorScheme.primary
                  : context.colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
      ],
    );
  }
}
