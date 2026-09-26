import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String dbPath = join(documentsDirectory.path, 'gym_tracker.db');

    bool dbExists = await File(dbPath).exists();

    if (!dbExists) {
      print("Creating a new copy from assets...");
      ByteData data = await rootBundle.load(join('assets', 'gym_tracker.db'));
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(dbPath).writeAsBytes(bytes, flush: true);
    } else {
      print("Opening existing database...");
    }

    return await openDatabase(dbPath, version: 2,);
  }

  // A simple test query
  Future<List<Map<String, dynamic>>> getTestExercises() async {
    Database db = await database;
    return await db.rawQuery('SELECT name, implement FROM Exercises LIMIT 5');
  }

  // Search exercises by name, implement, and muscle using advanced SQL joins
  Future<List<Map<String, dynamic>>> searchExercises({
    String query = '',
    String? implementFilter,
    String? muscleFilter,
  }) async {
    Database db = await database;

    String sql = '''
      SELECT 
        e.id, 
        e.name, 
        e.implement, 
        (SELECT GROUP_CONCAT(m2.name, ', ') 
         FROM Exercise_Muscles em2 
         JOIN Muscle_Groups m2 ON em2.muscle_id = m2.id 
         WHERE em2.exercise_id = e.id) AS muscle
      FROM Exercises e
      WHERE e.name LIKE ?
    ''';
    List<dynamic> args = ['%$query%'];

    if (implementFilter != null && implementFilter != 'All') {
      sql += ' AND e.implement = ?';
      args.add(implementFilter);
    }

    if (muscleFilter != null && muscleFilter != 'All') {
      sql += ''' 
        AND e.id IN (
          SELECT em3.exercise_id 
          FROM Exercise_Muscles em3 
          JOIN Muscle_Groups m3 ON em3.muscle_id = m3.id 
          WHERE m3.name = ?
        )
      ''';
      args.add(muscleFilter);
    }

    sql += ' ORDER BY e.name ASC';
    return await db.rawQuery(sql, args);
  }

  // Create a custom exercise and link it to a muscle group
  Future<void> createCustomExercise(String name, String implement, String muscle) async {
    Database db = await database;

    await db.transaction((txn) async {
      int exerciseId = await txn.insert(
        'Exercises',
        {'name': name, 'implement': implement},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      List<Map<String, dynamic>> muscleRow = await txn.query(
        'Muscle_Groups',
        where: 'name = ?',
        whereArgs: [muscle],
      );

      if (muscleRow.isNotEmpty) {
        int muscleId = muscleRow.first['id'];
        await txn.insert(
          'Exercise_Muscles',
          {
            'exercise_id': exerciseId,
            'muscle_id': muscleId,
            'is_primary': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  // Save a completed workout session to history
  Future<void> saveWorkoutSession(List<Map<String, dynamic>> sessionData) async {
    Database db = await database;

    await db.transaction((txn) async {
      // 1. Create the main Session entry
      int sessionId = await txn.insert('Sessions', {
        'start_time': DateTime.now().toIso8601String(),
        'end_time': DateTime.now().toIso8601String(),
        'notes': 'Ad-Hoc Workout'
      });

      // 2. Loop through each exercise
      for (int i = 0; i < sessionData.length; i++) {
        var exData = sessionData[i];

        int sessionExId = await txn.insert('Session_Exercises', {
          'session_id': sessionId,
          'exercise_id': exData['exercise_id'],
          'order_number': i + 1,
        });

        // 3. Loop through and save the completed sets
        List<Map<String, dynamic>> sets = exData['sets'];
        for (int j = 0; j < sets.length; j++) {
          await txn.insert('Sets', {
            'session_exercise_id': sessionExId,
            'set_number': j + 1,
            'weight': sets[j]['weight'],
            'reps': sets[j]['reps'],
          });
        }
      }
    });
  }

  // --- FETCH WEEKLY CONSISTENCY ---
  Future<List<Map<String, dynamic>>> getWeeklyConsistency() async {
    Database db = await database;

    // Groups by the Year-Week number, and grabs the date of the first workout that week for labeling
    return await db.rawQuery('''
      SELECT 
        strftime('%Y-%W', start_time) as week_group, 
        MIN(start_time) as week_label_date,
        COUNT(*) as workout_count
      FROM Sessions
      GROUP BY week_group
      ORDER BY week_label_date ASC
      LIMIT 12 
    ''');
  }


  // Fetch historical data for the 3 progression graphs
  Future<List<Map<String, dynamic>>> getExerciseProgress(int exerciseId) async {
    Database db = await database;

    // We group by the session ID/start_time so each point on the graph is one workout
    String sql = '''
      SELECT 
        s.start_time as date,
        MAX(st.weight * (1.0 + st.reps / 30.0)) as est_1rm,
        MAX(st.weight) as max_weight,
        SUM(st.weight * st.reps) as volume
      FROM Sessions s
      JOIN Session_Exercises se ON s.id = se.session_id
      JOIN Sets st ON se.id = st.session_exercise_id
      WHERE se.exercise_id = ? AND st.weight > 0 AND st.reps > 0
      GROUP BY s.id, s.start_time
      ORDER BY s.start_time ASC
    ''';

    return await db.rawQuery(sql, [exerciseId]);
  }
  // Fetch overall macro analytics for the General View graphs
  Future<Map<String, dynamic>> getMacroAnalytics() async {
    Database db = await database;

    // 1. Total Tonnage (Line Chart)
    List<Map<String, dynamic>> tonnage = await db.rawQuery('''
      SELECT s.start_time as date, SUM(st.weight * st.reps) as tonnage
      FROM Sessions s
      JOIN Session_Exercises se ON s.id = se.session_id
      JOIN Sets st ON se.id = st.session_exercise_id
      WHERE st.weight > 0 AND st.reps > 0
      GROUP BY s.id, s.start_time
      ORDER BY s.start_time ASC
    ''');

    // 2. Muscle Distribution (Pie Chart) - relies on the junction table
    List<Map<String, dynamic>> muscles = await db.rawQuery('''
      SELECT m.name as muscle, COUNT(st.id) as set_count
      FROM Sets st
      JOIN Session_Exercises se ON st.session_exercise_id = se.id
      JOIN Exercise_Muscles em ON se.exercise_id = em.exercise_id
      JOIN Muscle_Groups m ON em.muscle_id = m.id
      WHERE em.is_primary = 1
      GROUP BY m.id, m.name
    ''');

    // 3. Consistency (Workouts per month for Bar Chart)
    List<Map<String, dynamic>> consistency = await db.rawQuery('''
      SELECT strftime('%Y-%m', start_time) as month, COUNT(*) as workout_count
      FROM Sessions
      GROUP BY month
      ORDER BY month ASC
    ''');

    return {
      'tonnage': tonnage,
      'muscles': muscles,
      'consistency': consistency,
    };
  }
  // ==========================================
  // WORKOUT EXECUTION LOGIC
  // ==========================================

  // Start a workout session from a multi-day program template day safely
  Future<int> startWorkoutFromProgramDay(int programDayId) async {
    Database db = await database;

    // 1. Create a new Session record
    // NEW: We now link the session directly to the program_day_id so the "Up Next" tracker knows what you just finished
    String startTime = DateTime.now().toIso8601String();
    int sessionId = await db.insert('Sessions', {
      'start_time': startTime,
      'program_day_id': programDayId,
    });

    // 2. Fetch all exercises assigned to this program day template
    List<Map<String, dynamic>> programExercises = await db.query(
      'Program_Day_Exercises',
      where: 'program_day_id = ?',
      whereArgs: [programDayId],
      orderBy: 'order_index ASC', // NEW: Uses the updated order_index column
    );

    // 3. Copy the template exercises into the live session tracking tables
    for (var ex in programExercises) {
      await db.insert('Session_Exercises', {
        'session_id': sessionId,
        'exercise_id': ex['exercise_id'],
        'order_number': ex['order_index'],
      });
    }

    return sessionId;
  }

  // Fetch session exercises along with their routine targets (Used by ActiveWorkoutScreen)
  Future<List<Map<String, dynamic>>> getSessionExercises(int sessionId) async {
    Database db = await database;

    return await db.rawQuery('''
      SELECT 
        se.id as session_exercise_id,
        e.id as id,
        e.name,
        e.implement
      FROM Session_Exercises se
      JOIN Exercises e ON se.exercise_id = e.id
      WHERE se.session_id = ?
      ORDER BY se.order_number ASC
    ''', [sessionId]);
  }

  // ==========================================
  // RENAME & DELETE METHODS
  // ==========================================

  Future<void> deleteProgramWeek(int weekId) async {
    Database db = await database;
    await db.delete('Program_Weeks', where: 'id = ?', whereArgs: [weekId]);
  }

  Future<void> renameProgramWeek(int weekId, String newName) async {
    Database db = await database;
    await db.update('Program_Weeks', {'week_name': newName}, where: 'id = ?', whereArgs: [weekId]);
  }

  Future<void> deleteProgramDay(int dayId) async {
    Database db = await database;
    await db.delete('Program_Days', where: 'id = ?', whereArgs: [dayId]);
  }

  Future<void> renameProgramDay(int dayId, String newName) async {
    Database db = await database;
    await db.update('Program_Days', {'day_name': newName}, where: 'id = ?', whereArgs: [dayId]);
  }

  Future<void> removeExerciseFromDay(int programDayExerciseId) async {
    Database db = await database;
    await db.delete('Program_Day_Exercises', where: 'id = ?', whereArgs: [programDayExerciseId]);
  }
  // ==========================================
  // MULTI-DAY PROGRAMS BACKEND
  // ==========================================

  // ==========================================
  // BLOCK PERIODIZATION BACKEND (WEEKS & DAYS)
  // ==========================================

  Future<List<Map<String, dynamic>>> getPrograms() async {
    Database db = await database;
    return await db.query('Programs', orderBy: 'id ASC');
  }

  Future<void> createProgram(String name, String description) async {
    Database db = await database;
    await db.insert('Programs', {'name': name, 'description': description}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteProgram(int programId) async {
    Database db = await database;
    await db.delete('Programs', where: 'id = ?', whereArgs: [programId]);
  }

  // --- WEEKS ---
  Future<List<Map<String, dynamic>>> getProgramWeeks(int programId) async {
    Database db = await database;
    return await db.query('Program_Weeks', where: 'program_id = ?', whereArgs: [programId], orderBy: 'order_index ASC');
  }

  Future<void> createProgramWeek(int programId, String weekName) async {
    Database db = await database;
    List<Map<String, dynamic>> existing = await db.rawQuery('SELECT MAX(order_index) as max_val FROM Program_Weeks WHERE program_id = ?', [programId]);
    int nextOrder = (existing.first['max_val'] as int? ?? 0) + 1;
    await db.insert('Program_Weeks', {'program_id': programId, 'week_name': weekName, 'order_index': nextOrder});
  }

  // Duplicate an entire week, including all days and target exercises
  Future<void> duplicateWeek(int weekId, int programId) async {
    Database db = await database;
    await db.transaction((txn) async {
      // 1. Copy the Week
      List<Map<String, dynamic>> originalWeek = await txn.query('Program_Weeks', where: 'id = ?', whereArgs: [weekId]);
      if (originalWeek.isEmpty) return;

      List<Map<String, dynamic>> existingWeeks = await txn.rawQuery('SELECT MAX(order_index) as max_val FROM Program_Weeks WHERE program_id = ?', [programId]);
      int nextWeekOrder = (existingWeeks.first['max_val'] as int? ?? 0) + 1;

      int newWeekId = await txn.insert('Program_Weeks', {
        'program_id': programId,
        'week_name': '${originalWeek.first['week_name']} (Copy)',
        'order_index': nextWeekOrder
      });

      // 2. Copy the Days inside the Week
      List<Map<String, dynamic>> days = await txn.query('Program_Days', where: 'week_id = ?', whereArgs: [weekId]);
      for (var day in days) {
        int newDayId = await txn.insert('Program_Days', {
          'week_id': newWeekId,
          'day_name': day['day_name'],
          'order_index': day['order_index']
        });

        // 3. Copy the Exercises inside the Day
        List<Map<String, dynamic>> exercises = await txn.query('Program_Day_Exercises', where: 'program_day_id = ?', whereArgs: [day['id']]);
        for (var ex in exercises) {
          await txn.insert('Program_Day_Exercises', {
            'program_day_id': newDayId,
            'exercise_id': ex['exercise_id'],
            'order_index': ex['order_index'],
            'target_sets': ex['target_sets'],
            'target_reps': ex['target_reps']
          });
        }
      }
    });
  }

  // --- DAYS ---
  Future<List<Map<String, dynamic>>> getProgramDays(int weekId) async {
    Database db = await database;
    return await db.query('Program_Days', where: 'week_id = ?', whereArgs: [weekId], orderBy: 'order_index ASC');
  }

  Future<void> createProgramDay(int weekId, String dayName) async {
    Database db = await database;
    List<Map<String, dynamic>> existing = await db.rawQuery('SELECT MAX(order_index) as max_val FROM Program_Days WHERE week_id = ?', [weekId]);
    int nextOrder = (existing.first['max_val'] as int? ?? 0) + 1;
    await db.insert('Program_Days', {'week_id': weekId, 'day_name': dayName, 'order_index': nextOrder});
  }

  // --- EXERCISES ---
  Future<List<Map<String, dynamic>>> getProgramDayExercises(int programDayId) async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT e.id as exercise_id, e.name, e.implement, pde.id as program_day_exercise_id, pde.target_sets, pde.target_reps, pde.order_index
      FROM Program_Day_Exercises pde
      JOIN Exercises e ON pde.exercise_id = e.id
      WHERE pde.program_day_id = ?
      ORDER BY pde.order_index ASC
    ''', [programDayId]);
  }

  Future<void> addExerciseToProgramDay(dynamic programDayId, dynamic exerciseId, dynamic targetSets, dynamic targetReps) async {
    Database db = await database;
    int pDayId = int.parse(programDayId.toString());

    List<Map<String, dynamic>> existing = await db.rawQuery('SELECT MAX(order_index) as max_val FROM Program_Day_Exercises WHERE program_day_id = ?', [pDayId]);
    int nextOrder = (existing.first['max_val'] as int? ?? 0) + 1;

    await db.insert('Program_Day_Exercises', {
      'program_day_id': pDayId,
      'exercise_id': int.parse(exerciseId.toString()),
      'order_index': nextOrder,
      'target_sets': int.parse(targetSets.toString()),
      'target_reps': int.parse(targetReps.toString()),
    });
  }

  // --- REORDERING LOGIC ---
  // Call these when a user drops an item in a ReorderableListView
  Future<void> updateWeekOrder(List<Map<String, dynamic>> orderedWeeks) async {
    Database db = await database;
    await db.transaction((txn) async {
      for (int i = 0; i < orderedWeeks.length; i++) {
        await txn.update('Program_Weeks', {'order_index': i}, where: 'id = ?', whereArgs: [orderedWeeks[i]['id']]);
      }
    });
  }

  Future<void> updateDayOrder(List<Map<String, dynamic>> orderedDays) async {
    Database db = await database;
    await db.transaction((txn) async {
      for (int i = 0; i < orderedDays.length; i++) {
        await txn.update('Program_Days', {'order_index': i}, where: 'id = ?', whereArgs: [orderedDays[i]['id']]);
      }
    });
  }

  Future<void> updateExerciseOrder(List<Map<String, dynamic>> orderedExercises) async {
    Database db = await database;
    await db.transaction((txn) async {
      for (int i = 0; i < orderedExercises.length; i++) {
        await txn.update('Program_Day_Exercises', {'order_index': i}, where: 'id = ?', whereArgs: [orderedExercises[i]['program_day_exercise_id']]);
      }
    });
  }

  // --- UP NEXT & LAST WORKOUT TRACKER ---
  Future<Map<String, dynamic>> getProgramTrackingInfo(int programId) async {
    Database db = await database;
    Map<String, dynamic> tracking = {};

    // 1. Get the Last Completed Day for this specific program
    List<Map<String, dynamic>> lastSession = await db.rawQuery('''
      SELECT pd.id as day_id, pd.day_name, pw.week_name
      FROM Sessions s
      JOIN Program_Days pd ON s.program_day_id = pd.id
      JOIN Program_Weeks pw ON pd.week_id = pw.id
      WHERE pw.program_id = ? AND s.program_day_id IS NOT NULL
      ORDER BY s.end_time DESC LIMIT 1
    ''', [programId]);

    // 2. Fetch ALL days in this program sequentially
    List<Map<String, dynamic>> allDays = await db.rawQuery('''
      SELECT pd.id as day_id, pd.day_name, pw.week_name 
      FROM Program_Days pd
      JOIN Program_Weeks pw ON pd.week_id = pw.id
      WHERE pw.program_id = ?
      ORDER BY pw.order_index ASC, pd.order_index ASC
    ''', [programId]);

    if (allDays.isEmpty) return tracking; // Program is completely empty

    if (lastSession.isEmpty) {
      // Program has never been started, so "Next" is the very first day
      tracking['next'] = allDays.first;
      return tracking;
    }

    tracking['last'] = lastSession.first;

    // 3. Find where we left off, and select the next day
    int lastDayId = lastSession.first['day_id'];
    int nextIndex = allDays.indexWhere((day) => day['day_id'] == lastDayId) + 1;

    if (nextIndex < allDays.length) {
      tracking['next'] = allDays[nextIndex]; // Standard next day
    } else {
      tracking['next'] = allDays.first; // Reached the end, loop back to Week 1, Day 1
    }
    if (lastSession.isEmpty) {
      // Program has never been started, so "Next" is Week 1, Day 1
      tracking['next'] = allDays.first;
      return tracking;
    }

    return tracking;
  }

  // --- UP NEXT TRACKER ---
  Future<Map<String, dynamic>?> getUpNextWorkout(int programId) async {
    Database db = await database;

    // 1. Find the last completed day for this specific program
    List<Map<String, dynamic>> lastSession = await db.rawQuery('''
      SELECT s.program_day_id, pd.week_id, pd.order_index as day_order, pw.order_index as week_order
      FROM Sessions s
      JOIN Program_Days pd ON s.program_day_id = pd.id
      JOIN Program_Weeks pw ON pd.week_id = pw.id
      WHERE pw.program_id = ? AND s.program_day_id IS NOT NULL
      ORDER BY s.end_time DESC LIMIT 1
    ''', [programId]);

    if (lastSession.isEmpty) return null;

    int currentWeekId = lastSession.first['week_id'];
    int currentDayOrder = lastSession.first['day_order'];
    int currentWeekOrder = lastSession.first['week_order'];

    // 2. Try to find the NEXT day in the SAME week
    List<Map<String, dynamic>> nextDay = await db.rawQuery('''
      SELECT pd.id, pd.day_name, pw.week_name 
      FROM Program_Days pd
      JOIN Program_Weeks pw ON pd.week_id = pw.id
      WHERE pd.week_id = ? AND pd.order_index > ?
      ORDER BY pd.order_index ASC LIMIT 1
    ''', [currentWeekId, currentDayOrder]);

    if (nextDay.isNotEmpty) return nextDay.first;

    // 3. If no more days in this week, find the FIRST day of the NEXT week
    List<Map<String, dynamic>> nextWeekDay = await db.rawQuery('''
      SELECT pd.id, pd.day_name, pw.week_name 
      FROM Program_Days pd
      JOIN Program_Weeks pw ON pd.week_id = pw.id
      WHERE pw.program_id = ? AND pw.order_index > ?
      ORDER BY pw.order_index ASC, pd.order_index ASC LIMIT 1
    ''', [programId, currentWeekOrder]);

    if (nextWeekDay.isNotEmpty) return nextWeekDay.first;

    // 4. End of program reached
    return null;
  }

  // --- FULL DATABASE BACKUP ---
  Future<String> exportFullDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'gym_database.db'); // Ensure this matches your actual DB name
      final dbFile = File(path);

      if (!await dbFile.exists()) {
        return '❌ Database file not found.';
      }

      final exportPath = '/storage/emulated/0/Download/GymTracker_FullBackup.db';
      await dbFile.copy(exportPath);

      return '📦 Full database backup saved to Downloads!';
    } catch (e) {
      throw Exception('Failed to export full database: $e');
    }
  }

  // Retrieve history for the Analytics Screen
  Future<List<Map<String, dynamic>>> getWorkoutHistory() async {
    Database db = await database;

    String sql = '''
      SELECT 
        s.id as session_id,
        s.start_time,
        p.name as program_name,
        pd.day_name as day_name,
        (SELECT COUNT(*) FROM Session_Exercises se WHERE se.session_id = s.id) as exercise_count,
        (SELECT GROUP_CONCAT(e.name, ', ') 
         FROM Session_Exercises se2 
         JOIN Exercises e ON se2.exercise_id = e.id 
         WHERE se2.session_id = s.id) as exercise_names,
        (SELECT SUM(sets.weight * sets.reps) 
         FROM Sets sets 
         JOIN Session_Exercises se3 ON sets.session_exercise_id = se3.id 
         WHERE se3.session_id = s.id) as total_tonnage
      FROM Sessions s
      LEFT JOIN Program_Days pd ON s.program_day_id = pd.id
      LEFT JOIN Program_Weeks pw ON pd.week_id = pw.id
      LEFT JOIN Programs p ON pw.program_id = p.id
      ORDER BY s.start_time DESC
    ''';

    return await db.rawQuery(sql);
  }

  // --- NEW: Plateau Detection Engine ---
  Future<Map<String, dynamic>?> getDeloadRecommendation(int exerciseId) async {
    Database db = await database;

    // Fetch the max weight lifted for this exercise in the last 3 sessions
    List<Map<String, dynamic>> stats = await db.rawQuery('''
      SELECT se.session_id, MAX(s.weight) as max_weight
      FROM Session_Exercises se
      JOIN Sets s ON s.session_exercise_id = se.id
      WHERE se.exercise_id = ?
      GROUP BY se.session_id
      ORDER BY se.session_id DESC
      LIMIT 3
    ''', [exerciseId]);

    // We need at least 3 historical sessions to determine a true plateau
    if (stats.length < 3) return null;

    double w1 = (stats[0]['max_weight'] as num?)?.toDouble() ?? 0.0; // Most recent session
    double w2 = (stats[1]['max_weight'] as num?)?.toDouble() ?? 0.0; // Previous session
    double w3 = (stats[2]['max_weight'] as num?)?.toDouble() ?? 0.0; // Oldest session

    // If max weight plateaued or decreased over 3 consecutive sessions (w1 <= w2 <= w3)
    if (w1 > 0 && w1 <= w2 && w2 <= w3) {
      return {
        'is_deload': true,
        'suggested_weight': (w1 * 0.8).roundToDouble(), // Calculate a 20% drop for CNS recovery
      };
    }

    return null; // No deload needed, you are progressing!
  }
  // --- Fetch muscles for the chart calculation ---
  Future<List<Map<String, dynamic>>> getExerciseMuscles(int exerciseId) async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT mg.name, em.is_primary
      FROM Exercise_Muscles em
      JOIN Muscle_Groups mg ON mg.id = em.muscle_id
      WHERE em.exercise_id = ?
    ''', [exerciseId]);
  }
  // --- Check previous all-time maximum weight for an exercise ---
  Future<double> getPreviousMaxWeight(int exerciseId, String currentSessionStartTime) async {
    Database db = await database;
    final result = await db.rawQuery('''
      SELECT MAX(st.weight) as max_weight
      FROM Sets st
      JOIN Session_Exercises se ON st.session_exercise_id = se.id
      JOIN Sessions s ON se.session_id = s.id
      WHERE se.exercise_id = ? AND s.start_time < ?
    ''', [exerciseId, currentSessionStartTime]);

    if (result.isNotEmpty && result.first['max_weight'] != null) {
      return double.tryParse(result.first['max_weight'].toString()) ?? 0.0;
    }
    return 0.0; // Returns 0 if there's no prior history (first time doing the exercise)
  }
  // --- Fetch historical sets to calculate previous max Estimated 1RM ---
  Future<List<Map<String, dynamic>>> getPreviousSets(int exerciseId, String currentSessionStartTime) async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT st.weight, st.reps
      FROM Sets st
      JOIN Session_Exercises se ON st.session_exercise_id = se.id
      JOIN Sessions s ON se.session_id = s.id
      WHERE se.exercise_id = ? AND s.start_time < ?
    ''', [exerciseId, currentSessionStartTime]);
  }
  // --- Fetch latest training timestamp for each muscle group ---
  Future<List<Map<String, dynamic>>> getMuscleRecoveryData() async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT mg.name as muscle_name, 
             MAX(s.start_time) as last_trained
      FROM Muscle_Groups mg
      LEFT JOIN Exercise_Muscles em ON em.muscle_id = mg.id
      LEFT JOIN Session_Exercises se ON se.exercise_id = em.exercise_id
      LEFT JOIN Sessions s ON s.id = se.session_id
      GROUP BY mg.id
    ''');
  }
  // --- Fetch detailed exercises and sets for a specific session ---
  Future<List<Map<String, dynamic>>> getSessionDetails(int sessionId) async {
    Database db = await database;
    print("--- DEBUG SESSION DETAILS ---");
    print("Requested Session ID: $sessionId");

    final sessionExercises = await db.rawQuery('''
      SELECT se.id as session_exercise_id, e.name as exercise_name
      FROM Session_Exercises se
      JOIN Exercises e ON se.exercise_id = e.id
      WHERE se.session_id = ?
      ORDER BY se.order_number ASC
    ''', [sessionId]);

    print("Found ${sessionExercises.length} exercises for session $sessionId");

    List<Map<String, dynamic>> detailedExercises = [];

    for (var se in sessionExercises) {
      int seId = int.parse(se['session_exercise_id'].toString());
      final sets = await db.rawQuery('''
        SELECT set_number, weight, reps
        FROM Sets
        WHERE session_exercise_id = ?
        ORDER BY set_number ASC
      ''', [seId]);

      print("Exercise '${se['exercise_name']}' has ${sets.length} sets.");

      detailedExercises.add({
        'exercise_name': se['exercise_name'],
        'sets': sets,
      });
    }

    print("-----------------------------");
    return detailedExercises;
  }

  // --- DIAGNOSTIC TEST FOR ALTERNATIVES ---
  Future<void> testAlternatives() async {
    Database db = await database;

    try {
      // We join the Exercises table twice to get the actual text names instead of just IDs
      List<Map<String, dynamic>> results = await db.rawQuery('''
        SELECT a.name AS original_exercise, b.name AS alternative_exercise
        FROM Exercise_Alternatives ea
        JOIN Exercises a ON ea.exercise_a_id = a.id
        JOIN Exercises b ON ea.exercise_b_id = b.id
        WHERE ea.exercise_a_id = 1
      ''');

      print('\n=== EXERCISE ALTERNATIVES TEST ===');
      if (results.isEmpty) {
        print('Table exists, but no data was found for ID 1.');
      } else {
        for (var row in results) {
          print('${row['original_exercise']}  -->  ${row['alternative_exercise']}');
        }
      }
      print('==================================\n');

    } catch (e) {
      print('\n=== TEST FAILED ===');
      print('The table might not exist yet. Error details: $e\n');
    }
  }
  // --- Fetch curated alternatives for an exercise ---
  Future<List<Map<String, dynamic>>> getExerciseAlternatives(int exerciseId) async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT e.id, e.name, e.implement
      FROM Exercise_Alternatives ea
      JOIN Exercises e ON ea.exercise_b_id = e.id
      WHERE ea.exercise_a_id = ?
      ORDER BY e.name ASC
    ''', [exerciseId]);
  }

  // --- Add a new alternative link bidirectionally ---
  Future<void> addExerciseAlternative(int exerciseAId, int exerciseBId) async {
    Database db = await database;
    await db.insert(
      'Exercise_Alternatives',
      {'exercise_a_id': exerciseAId, 'exercise_b_id': exerciseBId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.insert(
      'Exercise_Alternatives',
      {'exercise_a_id': exerciseBId, 'exercise_b_id': exerciseAId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // --- Create an Exercise Variation (Modifier) ---
  Future<void> createExerciseVariation({
    required int parentId,
    required String variationName,
    required String implement,
    required bool isSwappable,
  }) async {
    Database db = await database;

    await db.transaction((txn) async {
      // 1. Insert the new variation into Exercises
      int newExerciseId = await txn.insert(
        'Exercises',
        {
          'name': variationName,
          'implement': implement,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Fetch the muscle group mappings of the parent exercise
      List<Map<String, dynamic>> parentMuscles = await txn.query(
        'Exercise_Muscles',
        where: 'exercise_id = ?',
        whereArgs: [parentId],
      );

      // 3. Copy those exact muscle mappings to the new variation
      for (var pm in parentMuscles) {
        await txn.insert(
          'Exercise_Muscles',
          {
            'exercise_id': newExerciseId,
            'muscle_id': pm['muscle_id'],
            'is_primary': pm['is_primary'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 4. If checked as swappable, link them bidirectionally in Exercise_Alternatives
      if (isSwappable) {
        await txn.insert(
          'Exercise_Alternatives',
          {'exercise_a_id': parentId, 'exercise_b_id': newExerciseId},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await txn.insert(
          'Exercise_Alternatives',
          {'exercise_a_id': newExerciseId, 'exercise_b_id': parentId},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  // Export custom exercises and muscle links as raw SQL script
  Future<String> exportCustomExercisesAsSql() async {
    Database db = await database;

    // 1. Fetch all exercises
    List<Map<String, dynamic>> exercises = await db.query('Exercises');

    // 2. Fetch all exercise-muscle mappings
    List<Map<String, dynamic>> exerciseMuscles = await db.query('Exercise_Muscles');

    // 3. Fetch all alternative links
    List<Map<String, dynamic>> alternatives = await db.query('Exercise_Alternatives');

    StringBuffer sqlBuffer = StringBuffer();
    sqlBuffer.writeln('-- AUTO-GENERATED EXPORT SCRIPT');
    sqlBuffer.writeln('BEGIN TRANSACTION;\n');

    // Generate Exercise Inserts
    for (var ex in exercises) {
      String name = ex['name'].toString().replaceAll("'", "''"); // Escape single quotes for SQL
      String implement = ex['implement'].toString().replaceAll("'", "''");
      int id = ex['id'];
      sqlBuffer.writeln("INSERT OR IGNORE INTO Exercises (id, name, implement) VALUES ($id, '$name', '$implement');");
    }

    sqlBuffer.writeln('');

    // Generate Muscle Mapping Inserts
    for (var em in exerciseMuscles) {
      int exId = em['exercise_id'];
      int muscleId = em['muscle_id'];
      int isPrimary = em['is_primary'];
      sqlBuffer.writeln("INSERT OR IGNORE INTO Exercise_Muscles (exercise_id, muscle_id, is_primary) VALUES ($exId, $muscleId, $isPrimary);");
    }

    sqlBuffer.writeln('');

    // Generate Alternative Inserts
    for (var alt in alternatives) {
      int aId = alt['exercise_a_id'];
      int bId = alt['exercise_b_id'];
      sqlBuffer.writeln("INSERT OR IGNORE INTO Exercise_Alternatives (exercise_a_id, exercise_b_id) VALUES ($aId, $bId);");
    }

    sqlBuffer.writeln('\nCOMMIT;');
    return sqlBuffer.toString();
  }

  // Export programs and their hierarchy as raw SQL script
  Future<String> exportProgramsAsSql() async {
    Database db = await database;
    StringBuffer sqlBuffer = StringBuffer();

    sqlBuffer.writeln('-- AUTO-GENERATED PROGRAMS SCRIPT');
    sqlBuffer.writeln('BEGIN TRANSACTION;\n');

    // 1. Export Programs
    List<Map<String, dynamic>> programs = await db.query('Programs');
    for (var p in programs) {
      String name = p['name'].toString().replaceAll("'", "''");
      String desc = (p['description'] ?? '').toString().replaceAll("'", "''");
      sqlBuffer.writeln("INSERT OR IGNORE INTO Programs (id, name, description) VALUES (${p['id']}, '$name', '$desc');");
    }
    sqlBuffer.writeln('');

    // 2. Export Weeks
    List<Map<String, dynamic>> weeks = await db.query('Program_Weeks');
    for (var w in weeks) {
      String wName = w['week_name'].toString().replaceAll("'", "''");
      sqlBuffer.writeln("INSERT OR IGNORE INTO Program_Weeks (id, program_id, week_name, order_index) VALUES (${w['id']}, ${w['program_id']}, '$wName', ${w['order_index']});");
    }
    sqlBuffer.writeln('');

    // 3. Export Days
    List<Map<String, dynamic>> days = await db.query('Program_Days');
    for (var d in days) {
      String dName = d['day_name'].toString().replaceAll("'", "''");
      sqlBuffer.writeln("INSERT OR IGNORE INTO Program_Days (id, week_id, day_name, order_index) VALUES (${d['id']}, ${d['week_id']}, '$dName', ${d['order_index']});");
    }
    sqlBuffer.writeln('');

    // 4. Export Day Exercises (Targets)
    List<Map<String, dynamic>> dayExercises = await db.query('Program_Day_Exercises');
    for (var de in dayExercises) {
      String reps = de['target_reps'].toString().replaceAll("'", "''");
      sqlBuffer.writeln("INSERT OR IGNORE INTO Program_Day_Exercises (id, program_day_id, exercise_id, order_index, target_sets, target_reps) VALUES (${de['id']}, ${de['program_day_id']}, ${de['exercise_id']}, ${de['order_index']}, ${de['target_sets']}, '$reps');");
    }

    sqlBuffer.writeln('\nCOMMIT;');
    return sqlBuffer.toString();
  }

  // Update targets for an existing exercise in a program day
  Future<int> updateProgramDayExerciseTargets(int programDayExerciseId, int targetSets, String targetReps) async {
    Database db = await database;
    return await db.update(
      'Program_Day_Exercises',
      {
        'target_sets': targetSets,
        'target_reps': targetReps,
      },
      where: 'id = ?',
      whereArgs: [programDayExerciseId],
    );
  }

  Future<List<ProgramDayCycleStats>> getProgramDayProgression(int programDayId) async {
    Database db = await database;
    List<ProgramDayCycleStats> progression = [];

    final List<Map<String, dynamic>> sessions = await db.query(
      'Sessions',
      where: 'program_day_id = ? AND end_time IS NOT NULL',
      whereArgs: [programDayId],
      orderBy: 'start_time ASC',
    );

    int cycleCounter = 1;

    for (var session in sessions) {
      int sessionId = int.parse(session['id'].toString());
      DateTime date = DateTime.parse(session['start_time'].toString());

      double sessionTonnage = 0;
      int sessionTotalSets = 0;
      int sessionTotalReps = 0; // <-- Restored tracking
      Map<int, ExerciseCycleStats> sessionExercisesMap = {};

      final List<Map<String, dynamic>> sessionExercises = await db.rawQuery('''
        SELECT se.id AS session_exercise_id, se.exercise_id, e.name 
        FROM Session_Exercises se
        JOIN Exercises e ON se.exercise_id = e.id
        WHERE se.session_id = ?
      ''', [sessionId]);

      for (var ex in sessionExercises) {
        int sessionExId = int.parse(ex['session_exercise_id'].toString());
        int exId = int.parse(ex['exercise_id'].toString());
        String exName = ex['name'];
        double exMaxWeight = 0;
        double exMax1RM = 0;
        int exTotalSets = 0;

        final List<Map<String, dynamic>> sets = await db.query(
          'Sets',
          where: 'session_exercise_id = ?',
          whereArgs: [sessionExId],
        );

        for (var s in sets) {
          double weight = double.tryParse(s['weight'].toString()) ?? 0.0;
          int reps = int.tryParse(s['reps'].toString()) ?? 0;

          if (reps > 0) {
            sessionTotalSets++;
            sessionTotalReps += reps; // <-- Track total reps
            sessionTonnage += (weight * reps);
            exTotalSets++;

            double estimated1RM = reps == 1 ? weight : weight * (1 + (reps / 30.0));
            if (weight > exMaxWeight) exMaxWeight = weight;
            if (estimated1RM > exMax1RM) exMax1RM = estimated1RM;
          }
        }
        if (exTotalSets > 0) {
          sessionExercisesMap[exId] = ExerciseCycleStats(
              exerciseId: exId,
              name: exName,
              maxWeight: exMaxWeight,
              estimated1RM: exMax1RM
          );
        }
      }

      if (sessionTotalSets > 0) {
        progression.add(ProgramDayCycleStats(
            cycleNumber: cycleCounter,
            sessionDate: date,
            totalTonnage: sessionTonnage,
            totalSets: sessionTotalSets, // <-- Pass to model
            totalReps: sessionTotalReps, // <-- Pass to model
            exerciseStats: sessionExercisesMap
        ));
        cycleCounter++;
      }
    }
    return progression;
  }

  Future<List<Map<String, dynamic>>> getDaysForProgramAnalytics(int programId) async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT pd.id, pw.week_name, pd.day_name 
      FROM Program_Days pd
      JOIN Program_Weeks pw ON pd.week_id = pw.id
      WHERE pw.program_id = ?
      ORDER BY pw.order_index ASC, pd.order_index ASC
    ''', [programId]);
  }

  // --- OVERALL PROGRAM MACRO PROGRESSION ---
  Future<List<MacroCycleStats>> getProgramMacroProgression(int programId) async {
    final days = await getDaysForProgramAnalytics(programId);
    Map<int, MacroCycleStats> macroMap = {};

    for (var d in days) {
      int dayId = int.parse(d['id'].toString());
      // Fetch the progression for this specific day
      var dayProgression = await getProgramDayProgression(dayId);

      // Distribute the day's stats into the overarching Program Cycles
      for (var cycle in dayProgression) {
        int cNum = cycle.cycleNumber;
        if (!macroMap.containsKey(cNum)) {
          macroMap[cNum] = MacroCycleStats(cycleNumber: cNum);
        }
        macroMap[cNum]!.totalTonnage += cycle.totalTonnage;
        macroMap[cNum]!.totalSets += cycle.totalSets;
        macroMap[cNum]!.totalReps += cycle.totalReps;
        macroMap[cNum]!.workoutsCompleted += 1;
      }
    }

    var macroList = macroMap.values.toList();
    macroList.sort((a, b) => a.cycleNumber.compareTo(b.cycleNumber));
    return macroList;
  }

  // --- FETCH RECENT PROGRAMS FOR DASHBOARD ---
  Future<List<Map<String, dynamic>>> getRecentPrograms({int limit = 2}) async {
    Database db = await database;
    // Orders by the most recently completed session, falling back to the highest program ID
    return await db.rawQuery('''
      SELECT p.*, MAX(s.start_time) as last_activity
      FROM Programs p
      LEFT JOIN Program_Weeks pw ON p.id = pw.program_id
      LEFT JOIN Program_Days pd ON pw.id = pd.week_id
      LEFT JOIN Sessions s ON pd.id = s.program_day_id
      GROUP BY p.id
      ORDER BY last_activity DESC, p.id DESC
      LIMIT ?
    ''', [limit]);
  }



}


// Add these models to the very bottom of database_helper.dart
class ExerciseCycleStats {
  final int exerciseId;
  final String name;
  final double maxWeight;
  final double estimated1RM;

  ExerciseCycleStats({
    required this.exerciseId,
    required this.name,
    required this.maxWeight,
    required this.estimated1RM
  });
}

class ProgramDayCycleStats {
  final int cycleNumber;
  final DateTime sessionDate;
  final double totalTonnage;
  final int totalSets; // <-- Restored
  final int totalReps; // <-- Restored
  final Map<int, ExerciseCycleStats> exerciseStats;

  ProgramDayCycleStats({
    required this.cycleNumber,
    required this.sessionDate,
    required this.totalTonnage,
    required this.totalSets,
    required this.totalReps,
    required this.exerciseStats
  });
}

class MacroCycleStats {
  final int cycleNumber;
  double totalTonnage;
  int totalSets;
  int totalReps;
  int workoutsCompleted;

  MacroCycleStats({
    required this.cycleNumber,
    this.totalTonnage = 0.0,
    this.totalSets = 0,
    this.totalReps = 0,
    this.workoutsCompleted = 0,
  });
}




