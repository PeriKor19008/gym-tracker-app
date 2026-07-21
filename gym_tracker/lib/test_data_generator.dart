import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class TestDataGenerator {
  // --- MASTER TEST RUNNER ---
  static Future<List<String>> runAllTests() async {
    List<String> executionLog = [];
    print("Starting test data injection suite...");

    // 1. Clear the old history first
    String clearResult = await clearHistoryData();
    executionLog.add(clearResult);

    // 2. Inject fresh dummy data and clean duplicates
    String injectResult = await injectDummyData();
    executionLog.add(injectResult);

    print("All test scripts executed successfully!");
    return executionLog;
  }

  // --- WIPE OLD HISTORY ---
  static Future<String> clearHistoryData() async {
    Database db = await DatabaseHelper.instance.database;

    // Delete in reverse order of creation to respect foreign keys
    await db.delete('Sets');
    await db.delete('Session_Exercises');
    await db.delete('Sessions');

    return "• Cleared all previous workout history for a clean slate.";
  }

  // --- INJECT DUMMY DATA ---
  static Future<String> injectDummyData() async {
    Database db = await DatabaseHelper.instance.database;

    // 1. Find existing 'Test Bench Press' to prevent ghost duplicates!
    List<Map<String, dynamic>> existing = await db.query(
        'Exercises',
        where: 'name = ?',
        whereArgs: ['Test Bench Press']
    );

    int exerciseId;

    if (existing.isNotEmpty) {
      // Use the FIRST one ever created (this is the one you see in your UI)
      exerciseId = int.parse(existing.first['id'].toString());

      // CLEANUP: Destroy any accidental duplicates created from previous clicks
      if (existing.length > 1) {
        for (int j = 1; j < existing.length; j++) {
          await db.delete('Exercises', where: 'id = ?', whereArgs: [existing[j]['id']]);
        }
      }
    } else {
      // Create it ONLY if it genuinely doesn't exist
      exerciseId = await db.insert('Exercises', {'name': 'Test Bench Press', 'implement': 'Barbell'});
    }

    // 2. Define historical weights (The plateau sequence)
    List<double> historicalWeights = [50, 55, 60, 65, 70, 75, 80, 80, 80, 75];

    for (int i = 0; i < historicalWeights.length; i++) {
      // Generate backdated timestamps
      DateTime startTime = DateTime.now().subtract(Duration(days: 10 - i));
      DateTime endTime = startTime.add(const Duration(hours: 1));

      int sessionId = await db.insert('Sessions', {
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
      });

      int sessionExerciseId = await db.insert('Session_Exercises', {
        'session_id': sessionId,
        'exercise_id': exerciseId,
        'order_number': 1,
      });

      for (int setNum = 1; setNum <= 3; setNum++) {
        await db.insert('Sets', {
          'session_exercise_id': sessionExerciseId,
          'set_number': setNum,
          'weight': historicalWeights[i],
          'reps': 10,
        });
      }
    }

    return "• Cleaned duplicate exercises & injected 10 new sessions.";
  }
}