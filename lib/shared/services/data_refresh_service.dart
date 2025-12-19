import 'package:flutter/foundation.dart';

class DataRefreshService {
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void notifyDataRestored() {
    revision.value++;
  }
}
