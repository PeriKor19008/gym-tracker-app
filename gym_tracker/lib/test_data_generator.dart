import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class TestDataGenerator {
  // --- MASTER TEST RUNNER ---
  static Future<List<String>> runAllTests() async {
    List<String> executionLog = [];
    print("Starting realistic test data injection suite...");

    // 1. Clear the old history first
    String clearResult = await clearHistoryData();
    executionLog.add(clearResult);

    // 2. Inject realistic multi-week progressive training history
    String realisticResult = await injectRealisticHistoryData();
    executionLog.add(realisticResult);

    print("All realistic test scripts executed successfully!");
    return executionLog;
  }

  // --- WIPE OLD HISTORY ---
  static Future<String> clearHistoryData() async {
    Database db = await DatabaseHelper.instance.database;

    // Delete in reverse order of creation to respect foreign keys
    await db.delete('Sets');
    await db.delete('Session_Exercises');
    await db.delete('Sessions');

    return "🧹 Cleared all previous workout history for a clean slate.";
  }

  // --- INJECT REALISTIC MULTI-WEEK HISTORY ---
  static Future<String> injectRealisticHistoryData() async {
    Database db = await DatabaseHelper.instance.database;

    // 1. Fetch available exercises from the database to use real movements
    List<Map<String, dynamic>> allExercises = await db.query('Exercises');
    if (allExercises.isEmpty) {
      return "⚠️ No exercises found in database. Please seed or create exercises first.";
    }

    // Helper to find an exercise ID by keyword match, with a safe fallback index
    int getExerciseId(String keyword, int fallbackIndex) {
      for (var ex in allExercises) {
        String name = ex['name'].toString().toLowerCase();
        if (name.contains(keyword.toLowerCase())) {
          return int.parse(ex['id'].toString());
        }
      }
      return int.parse(allExercises[fallbackIndex % allExercises.length]['id'].toString());
    }

    // Map standard key movements from your library
    int benchId = getExerciseId('bench', 0);
    int squatId = getExerciseId('squat', 1);
    int rowId = getExerciseId('row', 2);
    int ohpId = getExerciseId('press', 3);
    int curlId = getExerciseId('curl', 4);

    // Define a 4-week training timeline (Backdated days from today: 28 days ago down to today)
    // Split cycle: 0 = Push Day, 1 = Pull Day, 2 = Leg Day
    List<int> workoutScheduleDays = [28, 26, 24, 21, 19, 17, 14, 12, 10, 7, 5, 3, 0];
    int sessionsCreated = 0;

    for (int i = 0; i < workoutScheduleDays.length; i++) {
      int daysAgo = workoutScheduleDays[i];
      int splitType = i % 3;

      DateTime startTime = DateTime.now().subtract(Duration(days: daysAgo));
      DateTime endTime = startTime.add(const Duration(minutes: 70));

      int sessionId = await db.insert('Sessions', {
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
      });

      // Progressive overload math: Lighter 28 days ago, heavier and peaking at 0 days ago (today)
      double overloadFactor = 0.80 + ((28 - daysAgo) * 0.008);

      if (splitType == 0) {
        // --- PUSH DAY ---
        await _insertSessionExercise(db, sessionId, benchId, 1, 3, 70.0 * overloadFactor, 8);
        await _insertSessionExercise(db, sessionId, ohpId, 2, 3, 40.0 * overloadFactor, 10);
      } else if (splitType == 1) {
        // --- PULL DAY ---
        await _insertSessionExercise(db, sessionId, rowId, 1, 3, 60.0 * overloadFactor, 8);
        await _insertSessionExercise(db, sessionId, curlId, 2, 3, 25.0 * overloadFactor, 12);
      } else {
        // --- LEG DAY ---
        await _insertSessionExercise(db, sessionId, squatId, 1, 3, 90.0 * overloadFactor, 8);
      }

      sessionsCreated++;
    }

    return "🚀 Injected $sessionsCreated realistic sessions with progressive overload & PR history.";
  }

  // Helper to insert an exercise and its working sets into a session
  static Future<void> _insertSessionExercise(
      Database db,
      int sessionId,
      int exerciseId,
      int orderNumber,
      int totalSets,
      double baseWeight,
      int reps
      ) async {
    int sessionExerciseId = await db.insert('Session_Exercises', {
      'session_id': sessionId,
      'exercise_id': exerciseId,
      'order_number': orderNumber,
    });

    for (int setNum = 1; setNum <= totalSets; setNum++) {
      // Round weights to standard 2.5kg plate increments for realism
      double roundedWeight = (baseWeight / 2.5).round() * 2.5;
      if (roundedWeight < 5.0) roundedWeight = 5.0;

      await db.insert('Sets', {
        'session_exercise_id': sessionExerciseId,
        'set_number': setNum,
        'weight': roundedWeight,
        'reps': reps,
      });
    }
  }
}