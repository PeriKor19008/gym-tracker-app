import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// The callback function must be a top-level or static function marked with vm:entry-point
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(WorkoutTaskHandler());
}

class WorkoutTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Service started background routine
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Optional periodic background event
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Cleanup when service stops
  }

  @override
  void onNotificationButtonPressed(String id) {
    // Handle notification button actions if configured
  }

  @override
  void onNotificationPressed() {
    // Brings the app back to the foreground when tapping the notification banner
    FlutterForegroundTask.launchApp();
  }
}