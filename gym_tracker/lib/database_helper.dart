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

    return await openDatabase(dbPath, version: 1);
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

  // Retrieve history for the Analytics Screen
  Future<List<Map<String, dynamic>>> getWorkoutHistory() async {
    Database db = await database;

    String sql = '''
      SELECT 
        s.id as session_id,
        s.start_time,
        (SELECT COUNT(*) FROM Session_Exercises se WHERE se.session_id = s.id) as exercise_count,
        (SELECT GROUP_CONCAT(e.name, ', ') 
         FROM Session_Exercises se2 
         JOIN Exercises e ON se2.exercise_id = e.id 
         WHERE se2.session_id = s.id) as exercise_names
      FROM Sessions s
      ORDER BY s.start_time DESC
    ''';

    return await db.rawQuery(sql);
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
  // MULTI-DAY PROGRAMS BACKEND
  // ==========================================

  // 1. Fetch all available workout programs
  Future<List<Map<String, dynamic>>> getPrograms() async {
    Database db = await database;
    return await db.query('Programs', orderBy: 'id ASC');
  }

  // 2. Fetch the specific days (e.g., Day 1: Push, Day 2: Pull) for a program
  Future<List<Map<String, dynamic>>> getProgramDays(int programId) async {
    Database db = await database;
    // Assuming your schema uses a 'day_number' or similar for ordering
    return await db.query(
      'Program_Days',
      where: 'program_id = ?',
      whereArgs: [programId],
      orderBy: 'id ASC',
    );
  }

  // 3. Fetch the exercises assigned to a specific program day
  Future<List<Map<String, dynamic>>> getProgramDayExercises(int programDayId) async {
    Database db = await database;

    String sql = '''
      SELECT 
        e.id as exercise_id,
        e.name,
        e.implement,
        pde.id as program_day_exercise_id,
        pde.target_sets,
        pde.target_reps
      FROM Program_Day_Exercises pde
      JOIN Exercises e ON pde.exercise_id = e.id
      WHERE pde.program_day_id = ?
      ORDER BY pde.order_number ASC
    ''';

    return await db.rawQuery(sql, [programDayId]);
  }
  // Create a new master program template
  Future<void> createProgram(String name, String description) async {
    Database db = await database;

    await db.insert(
      'Programs',
      {
        'name': name,
        'description': description,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  // Create a new day inside a program routine
  // Create a new day inside a program routine, including the required day_number
  Future<void> createProgramDay(int programId, String dayName) async {
    Database db = await database;

    // 1. Count how many days currently exist for this program to determine the next day_number
    List<Map<String, dynamic>> existingDays = await db.rawQuery(
      'SELECT COUNT(*) as count FROM Program_Days WHERE program_id = ?',
      [programId],
    );
    int nextDayNumber = (Sqflite.firstIntValue(existingDays) ?? 0) + 1;

    // 2. Insert with the required day_number column included
    await db.insert(
      'Program_Days',
      {
        'program_id': programId,
        'day_name': dayName,
        'day_number': nextDayNumber, // Satisfies the NOT NULL constraint
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Link an exercise to a specific program day with the required order_number
  // Link an exercise to a specific program day with safe integer casting
  Future<void> addExerciseToProgramDay(dynamic programDayId, dynamic exerciseId, dynamic targetSets, dynamic targetReps) async {
    Database db = await database;

    int pDayId = int.parse(programDayId.toString());
    int exId = int.parse(exerciseId.toString());
    int tSets = int.parse(targetSets.toString());
    int tReps = int.parse(targetReps.toString());

    List<Map<String, dynamic>> existing = await db.rawQuery(
      'SELECT COUNT(*) as count FROM Program_Day_Exercises WHERE program_day_id = ?',
      [pDayId],
    );
    int nextOrderNumber = (Sqflite.firstIntValue(existing) ?? 0) + 1;

    await db.insert(
      'Program_Day_Exercises',
      {
        'program_day_id': pDayId,
        'exercise_id': exId,
        'order_number': nextOrderNumber,
        'target_sets': tSets,
        'target_reps': tReps,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  // Start a workout session from a multi-day program template day
  // Start a workout session from a multi-day program template day safely
  Future<int> startWorkoutFromProgramDay(int programDayId) async {
    Database db = await database;

    // 1. Create a new Session record
    String startTime = DateTime.now().toIso8601String();
    int sessionId = await db.insert('Sessions', {
      'start_time': startTime,
    });

    // 2. Fetch all exercises assigned to this program day template
    List<Map<String, dynamic>> programExercises = await db.query(
      'Program_Day_Exercises',
      where: 'program_day_id = ?',
      whereArgs: [programDayId],
      orderBy: 'order_number ASC',
    );

    // 3. Copy only the columns that actually exist in Session_Exercises
    for (var ex in programExercises) {
      await db.insert('Session_Exercises', {
        'session_id': sessionId,
        'exercise_id': ex['exercise_id'],
        'order_number': ex['order_number'],
      });
    }

    return sessionId;
  }
  // Fetch exercises linked to a live session (when starting from a template)
  // Fetch session exercises along with their routine targets
  Future<List<Map<String, dynamic>>> getSessionExercises(int sessionId) async {
    Database db = await database;

    // First, let's find out which program day this session originated from,
    // or just fetch the exercise library details and match order.
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
  // Delete a master program (cascades to days and exercises automatically)
  Future<void> deleteProgram(int programId) async {
    Database db = await database;
    await db.delete(
      'Programs',
      where: 'id = ?',
      whereArgs: [programId],
    );
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


}