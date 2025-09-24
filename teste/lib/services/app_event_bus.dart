// lib/services/app_event_bus.dart
import 'package:flutter/foundation.dart';


class AppEventBus {
  AppEventBus._();
  static final AppEventBus I = AppEventBus._();

  
  final ValueNotifier<int> medicamentosChanged = ValueNotifier<int>(0);

  void bumpMedChange() {
    medicamentosChanged.value++;
  }
}
