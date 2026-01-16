import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/core/utils/field_validator.dart';
import 'package:silversole/shared/providers/auth_provider.dart';
import 'package:silversole/shared/providers/sole_provider.dart';

import '../models/auth_model.dart';

class DeviceBindingField extends ConsumerStatefulWidget {
  const DeviceBindingField({super.key});

  @override
  ConsumerState<DeviceBindingField> createState() => _DeviceBindingFieldState();
}

class _DeviceBindingFieldState extends ConsumerState<DeviceBindingField> {
  final formKey = GlobalKey<FormState>();
  bool autoValidate = false;
  bool isBinding = false;
  String deviceId = '';

  void setDeviceId(String value) => deviceId = value;

  Future<void> bindingDevice() async {
    if (!formKey.currentState!.validate()) {
      setState(() => autoValidate = true);
      return;
    }
    setState(() => isBinding = true);
    try {
      final userProvider = ref.read(authUserProvider);
      if (userProvider == null) throw Exception('not_signed_in'.tr());
      final soleService = ref.read(soleProvider);
      final result = await soleService.bindingDevice(userProvider.uuid, deviceId);
      switch (result) {
        case Ok():
          await saveDeviceId(deviceId);
          ref.read(authUserProvider.notifier).setUser(
                UserData(
                  email: userProvider.email,
                  uuid: userProvider.uuid,
                  localDeviceId: deviceId,
                ),
              );
          showMessage('binding_success'.tr());
        case Error():
          showErrorSnakeBar(result.error.toString());
      }
    } catch (e) {
      showErrorSnakeBar(e.toString());
    } finally {
      if (mounted) {
        setState(() => isBinding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Form(
        key: formKey,
        autovalidateMode: autoValidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
        child: Row(
          spacing: 12,
          children: [
            Expanded(
              child: TextFormField(
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'silversole_device_id'.tr(),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(LucideIcons.key),
                ),
                validator: (val) => fieldEmptyValidator(val),
                onChanged: (value) => setDeviceId(value),
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isBinding ? null : bindingDevice,
              child: Text('binding'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
