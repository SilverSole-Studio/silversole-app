import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/models/device_location_model.dart';
import 'package:silversole/shared/models/device_status_detail_model.dart';
import 'package:silversole/shared/models/sole_record_data_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TelemetryQueryService {
  SupabaseClient supabase;

  TelemetryQueryService({required this.supabase});

  Result<T> _notSignIn<T>() => Result<T>.error(Exception('not_signed_in'.tr()));

  Result<T> _notBinding<T>() => Result<T>.error(Exception('not_binding'.tr()));

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

  Future<Result<DeviceStatusDetailModel>> getDeviceStatusDetail({required String deviceId}) async {
    try {
      if (supabase.auth.currentUser == null) return _notSignIn();
      if (deviceId.isEmpty) return _notBinding();
      final result = await supabase
          .from('devices')
          .select('last_heartbeat_at,last_battery_percent,last_battery_at,is_charging')
          .eq('device_id', deviceId)
          .maybeSingle();
      if (result == null) return Result.error(Exception('device_not_found'.tr()));
      return Result.ok(DeviceStatusDetailModel.fromJson(result));
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

  Future<Result<List<DeviceLocationModel>>> getRecentDeviceLocation({required String deviceId}) async {
    try {
      if (supabase.auth.currentUser == null) return _notSignIn();
      if (deviceId.isEmpty) return _notBinding();
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
}