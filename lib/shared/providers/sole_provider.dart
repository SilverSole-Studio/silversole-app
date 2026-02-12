import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/data/sole_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final soleProvider = Provider<SilverSoleService>((_) => SilverSoleService(supabase: Supabase.instance.client));