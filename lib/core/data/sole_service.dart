import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/models/sole_record_data_model.dart';
import 'package:silversole/shared/models/user_device_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum BindingResult { success, alreadyBound }

class SilverSoleService {
  SupabaseClient client;

  Result<T> _notSignIn<T>() => Result<T>.error(Exception('not_signed_in'.tr()));

  Future<Result<BindingResult>> bindingDevice(String userId, String deviceId) async {
    try {
      if (client.auth.currentUser == null) return _notSignIn();
      final deviceTable = await client.from('devices').select().eq('device_id', deviceId);
      if (deviceTable.isEmpty) {
        return Result.error(Exception('device_not_found'.tr()));
      }
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
      if (client.auth.currentUser == null) return _notSignIn();
      final result = await client
          .from('silversole_test_data')
          .select()
          .eq('device_id', deviceId)
          .order('created_at', ascending: false)
          .limit(limit);
      return Result.ok(result.map((e) => SilverSoleRecordModel.fromJson(e)).toList());
    } on PostgrestException catch (e) {
      debugPrint('${e.code} : ${e.message}');
      final error = switch (e.code) {
        '42501' => 'rls_denied'.tr(),
        _ => 'binding_failed'.tr(),
      };
      return Result.error(Exception(error));
    } catch (e) {
      return Result.error(Exception(e.toString()));
    }
  }

  Future<Result<DateTime?>> getDeviceLastUpdateTime({required String deviceId}) async {
    try {
      if (client.auth.currentUser == null) return _notSignIn();
      final result = await client.from('devices').select('last_heartbeat_at').eq('device_id', deviceId).maybeSingle();
      final raw = result?['last_heartbeat_at'] as String?;
      if (raw == null) return Result.ok(null);
      final lastUpdateTime = DateTime.parse(raw);
      return Result.ok(lastUpdateTime);
    } on PostgrestException catch (e) {
      debugPrint('${e.code} : ${e.message}');
      final error = switch (e.code) {
        '42501' => 'rls_denied'.tr(),
        _ => 'get_last_update_time_failed'.tr(),
      };
      return Result.error(Exception(error));
    } catch (e) {
      return Result.error(Exception(e.toString()));
    }
  }

  bool checkDeviceOnline(DateTime? time) {
    if (time == null) return false;
    final now = DateTime.now();
    final diff = now.difference(time);
    return diff.inSeconds < 35;
  }

  SilverSoleService({required this.client});
}
