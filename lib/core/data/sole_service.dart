import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/models/sole_record_data_model.dart';
import 'package:silversole/shared/models/user_device_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum BindingResult { success, alreadyBound }

class SilverSoleService {
  SupabaseClient client;

  Future<Result<BindingResult>> bindingDevice(String userId, String deviceId) async {
    try {
      if (client.auth.currentUser == null) return Result.error(Exception('not_signed_in'.tr()));
      final deviceTable = await client.from('devices').select().eq('device_id', deviceId);
      if (deviceTable.isEmpty) {
        return Result.error(Exception('device_not_found'.tr()));
      }
      debugPrint(UserDeviceModel(userId: userId, deviceId: deviceId).toJson().toString());
      await client.from('user_devices').insert(UserDeviceModel(userId: userId, deviceId: deviceId).toJson());
      return const Result.ok(BindingResult.success);
    } on PostgrestException catch (e) {
      debugPrint('${e.code} : ${e.message}');
      final error = switch (e.code) {
        '42501' => 'rls_denied'.tr(),
        '22P02' => 'invalid_device_id_format'.tr(),
        '23505' => null,
        _ => 'binding_failed'.tr(),
      };
      if (error == null) {
        return const Result.ok(BindingResult.alreadyBound);
      }
      return Result.error(Exception(error));
    } catch (e) {
      return Result.error(Exception(e.toString()));
    }
  }

  Future<Result<List<SilverSoleRecordModel>>> getRecentDeviceData({required String deviceId, int limit = 10}) async {
    try {
      if (client.auth.currentUser == null) return Result.error(Exception('not_signed_in'.tr()));
      final result = await client.from('silversole_test_data').select().eq('device_id', deviceId).limit(limit);
      return Result.ok(result.map((e) => SilverSoleRecordModel.fromJson(e)).toList());
    } catch (e) {
      return Result.error(Exception(e.toString()));
    }
  }

  SilverSoleService({required this.client});
}
