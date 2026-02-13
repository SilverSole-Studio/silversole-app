import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/models/device_location_model.dart';
import 'package:silversole/shared/models/device_status_detail_model.dart';
import 'package:silversole/shared/models/sole_record_data_model.dart';
import 'package:silversole/shared/models/user_device_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum BindingResult { success, alreadyBound }

class SilverSoleService {
  SupabaseClient supabase;

  Result<T> _notSignIn<T>() => Result<T>.error(Exception('not_signed_in'.tr()));

  Result<T> _notBinding<T>() => Result<T>.error(Exception('not_binding'.tr()));

  Future<Result<BindingResult>> bindingDevice(String userId, String deviceId) async {
    try {
      if (supabase.auth.currentUser == null) return _notSignIn();
      final deviceTable = await supabase.from('devices').select().eq('device_id', deviceId);
      if (deviceTable.isEmpty) {
        return Result.error(Exception('device_not_found'.tr()));
      }
      await supabase.from('user_devices').insert(UserDeviceModel(userId: userId, deviceId: deviceId).toJson());
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
      if (supabase.auth.currentUser == null) return _notSignIn();
      if (deviceId.isEmpty) return _notBinding();
      final result = await supabase
          .from('silversole_record_data')
          .select()
          .eq('device_id', deviceId)
          .order('client_ts', ascending: false)
          .limit(limit);
      return Result.ok(result.map((e) => SilverSoleRecordModel.fromJson(e)).toList());
    } on PostgrestException catch (e) {
      debugPrint('${e.code} : ${e.message}');
      final error = switch (e.code) {
        '42501' => 'rls_denied'.tr(),
        _ => 'get_recent_data_failed'.tr(),
      };
      return Result.error(Exception(error));
    } catch (e) {
      debugPrint('[getRecentDeviceDataError]: ${e.toString()}');
      return Result.error(Exception(e.toString()));
    }
  }

  Future<Result<DeviceStatusDetailModel>> getDeviceStatusDetail({required String? deviceId}) async {
    try {
      if (supabase.auth.currentUser == null) return _notSignIn();
      if (deviceId == null || deviceId.isEmpty) return _notBinding();
      final result = await supabase
          .from('devices')
          .select('last_heartbeat_at,last_battery_percent,last_battery_at,is_charging')
          .eq('device_id', deviceId)
          .maybeSingle();
      if (result == null) return Result.error(Exception('device_not_found'.tr()));
      return Result.ok(DeviceStatusDetailModel.fromJson(result));
      // final raw = result?['last_heartbeat_at'] as String?;
      // if (raw == null) return Result.ok(null);
      // final lastUpdateTime = DateTime.parse(raw);
      // return Result.ok(lastUpdateTime);
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

  Future<Result<DateTime?>> getDeviceLastUpdateTime({required String? deviceId}) async {
    try {
      if (supabase.auth.currentUser == null) return _notSignIn();
      if (deviceId == null || deviceId.isEmpty) return _notBinding();
      final result = await supabase.from('devices').select('last_heartbeat_at').eq('device_id', deviceId).maybeSingle();
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

  Future<Result<List<DeviceLocationModel>>> getRecentDeviceLocation({required String? deviceId}) async {
    try {
      if (supabase.auth.currentUser == null) return _notSignIn();
      if (deviceId == null || deviceId.isEmpty) return _notBinding();
      final result = await supabase
          .from('device_locations')
          .select()
          .eq('device_id', deviceId)
          .order('received_at', ascending: false)
          .limit(5);
      final locations = result.map((json) => DeviceLocationModel.fromJson(json)).toList();
      return Result.ok(locations);
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

  SilverSoleService({required this.supabase});
}
