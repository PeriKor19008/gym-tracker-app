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

    // Join the junction table with your main Exercises table to get the names
    String sql = '''
      SELECT 
        e.id as exercise_id,
        e.name,
        e.implement,
        pde.id as program_day_exercise_id
      FROM Program_Day_Exercises pde
      JOIN Exercises e ON pde.exercise_id = e.id
      WHERE pde.program_day_id = ?
      ORDER BY pde.id ASC
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
  Future<void> addExerciseToProgramDay(int programDayId, int exerciseId) async {
    Database db = await database;

    // 1. Calculate the next order number for this routine day
    List<Map<String, dynamic>> existing = await db.rawQuery(
      'SELECT COUNT(*) as count FROM Program_Day_Exercises WHERE program_day_id = ?',
      [programDayId],
    );
    int nextOrderNumber = (Sqflite.firstIntValue(existing) ?? 0) + 1;

    // 2. Insert with the order_number included to satisfy the constraint
    await db.insert(
      'Program_Day_Exercises',
      {
        'program_day_id': programDayId,
        'exercise_id': exerciseId,
        'order_number': nextOrderNumber,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}