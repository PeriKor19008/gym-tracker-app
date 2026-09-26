import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async'; // --- NEW: Required for the Timer ---
import 'exercise_library.dart';
import 'database_helper.dart';
import 'post_workout_summary.dart';
import 'exercise_details_screen.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'workout_foreground_task.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/cupertino.dart';


// Data model for a single set
class WorkoutSet {
  TextEditingController weightController = TextEditingController();
  TextEditingController repsController = TextEditingController();
  bool isCompleted = false;
  // --- NEW: Focus nodes to control keyboard actions ---
  FocusNode weightFocusNode = FocusNode();
  FocusNode repsFocusNode = FocusNode();
}

// Data model for an exercise added to the workout
class ActiveExercise {
  final Map<String, dynamic> exerciseData;
  List<WorkoutSet> sets = [WorkoutSet()];

  // --- NEW: Track deload state ---
  bool isDeload = false;
  double? suggestedWeight;

  ActiveExercise(this.exerciseData);
}

class ActiveWorkoutScreen extends StatefulWidget {
  final int? sessionId;
  const ActiveWorkoutScreen({super.key, this.sessionId});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  final List<ActiveExercise> _workoutExercises = [];
  final DateTime _workoutStartTime = DateTime.now();

  // --- NEW: Timer State Variables ---
  Timer? _restTimer;
  int _restSeconds = 90; // Default rest time: 1m 30s
  int _baseRestSeconds = 90; // <--- ADD THIS: Remembers your preferred rest time
  bool _isTimerRunning = false;

  @override
  void initState() {
    super.initState();
    _initForegroundTask();
    _requestNotificationPermission();
    DatabaseHelper.instance.testAlternatives();
    if (widget.sessionId != null) {
      _loadRoutineExercises();
    }

  }


  // --- NEW: Clean up the timer when leaving the screen ---
  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  // --- FOREGROUND SERVICE CONTROLS ---

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'gym_tracker_rest_timer_v4', // <-- v4 forces the OS to apply the new rules
        channelName: 'Workout Rest Timer',
        channelDescription: 'Active rest timer running in background',
        channelImportance: NotificationChannelImportance.DEFAULT, // <-- DEFAULT stops the big pop-down banner
        priority: NotificationPriority.DEFAULT,                   // <-- DEFAULT keeps the small status bar icon
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  Future<void> _requestNotificationPermission() async {
    // Check if notification permission is granted, if not request it
    NotificationPermission permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  Future<void> _startForegroundService() async {
    if (await FlutterForegroundTask.isRunningService) {
      return;
    }

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'Gym Tracker Active',
      notificationText: 'Rest Timer: ${_formatTime(_restSeconds)}',
      callback: startCallback,
    );
  }

  Future<void> _stopForegroundService() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  // --- SWAP & SPLIT LOGIC ---

  void _showSwapBottomSheet(int exerciseIndex) async {
    final currentExercise = _workoutExercises[exerciseIndex];
    int exerciseId = currentExercise.exerciseData['id'] ?? currentExercise.exerciseData['exercise_id'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: DatabaseHelper.instance.getExerciseAlternatives(exerciseId),
              builder: (context, snapshot) {
                List<Map<String, dynamic>> alternatives = snapshot.data ?? [];

                return Container(
                  padding: const EdgeInsets.all(20),
                  height: 420,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Swap Alternatives for ${currentExercise.exerciseData['name']}',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 15),
                      Expanded(
                        child: snapshot.connectionState == ConnectionState.waiting
                            ? const Center(child: CircularProgressIndicator())
                            : alternatives.isEmpty
                            ? const Center(
                          child: Text(
                            'No curated alternatives found for this exercise.',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        )
                            : ListView.builder(
                          itemCount: alternatives.length,
                          itemBuilder: (context, index) {
                            var alt = alternatives[index];
                            return ListTile(
                              title: Text(alt['name'], style: const TextStyle(color: Colors.white)),
                              subtitle: Text(alt['implement'], style: const TextStyle(color: Colors.grey)),
                              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                              onTap: () {
                                Navigator.pop(context);
                                _executeSwapOrSplit(exerciseIndex, alt);
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      // --- ADD RELATED EXERCISE BUTTON ---
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text('Add Related Exercise', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          // 1. Open your library to select an exercise
                          final selectedExercise = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ExerciseLibraryScreen()),
                          );

                          if (selectedExercise != null) {
                            int newExId = int.parse(selectedExercise['id'].toString());

                            // Prevent linking an exercise to itself
                            if (newExId != exerciseId) {
                              // 2. Save link bidirectionally in database
                              await DatabaseHelper.instance.addExerciseAlternative(exerciseId, newExId);

                              // 3. Refresh the modal view so the new alternative shows up instantly
                              setModalState(() {});
                            }
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _executeSwapOrSplit(int index, Map<String, dynamic> newExerciseData) {
    setState(() {
      var currentActiveEx = _workoutExercises[index];
      List<WorkoutSet> sets = currentActiveEx.sets;

      // Check if any set has data entered or is marked completed
      bool hasCompletedSets = sets.any((s) =>
      s.isCompleted ||
          (double.tryParse(s.weightController.text) ?? 0) > 0 ||
          (int.tryParse(s.repsController.text) ?? 0) > 0
      );

      if (!hasCompletedSets) {
        // --- SCENARIO A: CLEAN SWAP (Zero sets done) ---
        // Overwrite the exercise entirely in place
        _workoutExercises[index] = ActiveExercise(newExerciseData);
      } else {
        // --- SCENARIO B: MID-WORKOUT SPLIT ---
        // 1. Keep only the completed sets on the original exercise block
        List<WorkoutSet> completedSets = sets.where((s) =>
        s.isCompleted ||
            (double.tryParse(s.weightController.text) ?? 0) > 0 ||
            (int.tryParse(s.repsController.text) ?? 0) > 0
        ).toList();

        currentActiveEx.sets = completedSets;

        // 2. Create the new alternative exercise block with fresh empty sets to finish volume
        ActiveExercise splitExercise = ActiveExercise(newExerciseData);
        splitExercise.sets = [WorkoutSet(), WorkoutSet(), WorkoutSet()];

        // 3. Insert the new exercise directly below the current one
        _workoutExercises.insert(index + 1, splitExercise);
      }
    });
  }

  void _confirmRemoveExercise(int index) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Remove Exercise?', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Are you sure you want to remove this exercise from your current workout?',
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _workoutExercises.removeAt(index);
                });
                Navigator.pop(ctx);
              },
              child: const Text('REMOVE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // --- NEW: Timer Logic Methods ---
  void _startTimer() {
    if (_restTimer != null) _restTimer!.cancel();

    setState(() {
      if (_restSeconds == 0) {
        _restSeconds = _baseRestSeconds;
      }
      _isTimerRunning = true;
    });

    // --- START BACKGROUND SERVICE ---
    _startForegroundService();

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_restSeconds > 0) {
          _restSeconds--;
          // --- UPDATE NOTIFICATION SHADE IN REAL-TIME ---
          FlutterForegroundTask.updateService(
            notificationTitle: 'Rest Period Active',
            notificationText: 'Time remaining: ${_formatTime(_restSeconds)}',
          );
        } else {
          _stopTimer();
          _restSeconds = _baseRestSeconds;
          FlutterRingtonePlayer().playNotification();
          // --- STOP SERVICE WHEN TIMER ENDS ---
          _stopForegroundService();
        }
      });
    });
  }

  void _stopTimer() {
    _restTimer?.cancel();
    setState(() => _isTimerRunning = false);
    // --- STOP SERVICE WHEN PAUSED/STOPPED ---
    _stopForegroundService();
  }

  void _resetTimer(int seconds) {
    _stopTimer();
    setState(() => _restSeconds = seconds);
  }

  void _adjustTimer(int seconds) {
    setState(() {
      _restSeconds += seconds;
      if (_restSeconds < 0) _restSeconds = 0;

      // If you adjust the clock while paused, remember this as the new default
      if (!_isTimerRunning) {
        _baseRestSeconds = _restSeconds;
      }
    });
  }

  String _formatTime(int totalSeconds) {
    int m = totalSeconds ~/ 60;
    int s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showTimerPicker() {
    // Pause the timer while the user is adjusting it
    bool wasRunning = _isTimerRunning;
    if (wasRunning) _stopTimer();

    int selectedMinutes = _restSeconds ~/ 60;
    int selectedSeconds = _restSeconds % 60;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext builder) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              // Header with Title and Done button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Set Rest Timer', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _restSeconds = (selectedMinutes * 60) + selectedSeconds;
                          _baseRestSeconds = _restSeconds; // Remember this as the new default
                        });
                        Navigator.pop(context);
                        if (wasRunning && _restSeconds > 0) _startTimer(); // Resume if it was running
                      },
                      child: const Text('DONE', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
              // The Spinning Cupertino Wheel
              Expanded(
                child: CupertinoTheme(
                  data: const CupertinoThemeData(
                    textTheme: CupertinoTextThemeData(
                      pickerTextStyle: TextStyle(color: Colors.white, fontSize: 22),
                    ),
                  ),
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.ms,
                    initialTimerDuration: Duration(seconds: _restSeconds),
                    onTimerDurationChanged: (Duration newDuration) {
                      selectedMinutes = newDuration.inMinutes;
                      selectedSeconds = newDuration.inSeconds % 60;
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --------------------------------

  Future<void> _loadRoutineExercises() async {
    final exercisesData = await DatabaseHelper.instance.getSessionExercises(widget.sessionId!);

    for (var exData in exercisesData) {
      ActiveExercise activeEx = ActiveExercise(exData);
      int exId = activeEx.exerciseData['id'] ?? activeEx.exerciseData['exercise_id'];

      // --- NEW: Check for deload and auto-fill weight ---
      var deloadData = await DatabaseHelper.instance.getDeloadRecommendation(exId);
      if (deloadData != null) {
        activeEx.isDeload = true;
        activeEx.suggestedWeight = deloadData['suggested_weight'];

        // Auto-fill the first set with the reduced weight
        activeEx.sets[0].weightController.text = activeEx.suggestedWeight.toString();
      }

      setState(() {
        _workoutExercises.add(activeEx);
      });
    }
  }

  Future<void> _addExercise() async {
    final selectedExercise = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ExerciseLibraryScreen()),
    );

    if (selectedExercise != null) {
      ActiveExercise newEx = ActiveExercise(selectedExercise);
      int exId = int.parse(selectedExercise['id'].toString());

      // --- NEW: Check for deload when manually adding an exercise ---
      var deloadData = await DatabaseHelper.instance.getDeloadRecommendation(exId);
      if (deloadData != null) {
        newEx.isDeload = true;
        newEx.suggestedWeight = deloadData['suggested_weight'];

        // Auto-fill the first set with the reduced weight
        newEx.sets[0].weightController.text = newEx.suggestedWeight.toString();
      }

      setState(() {
        _workoutExercises.add(newEx);
      });
    }
  }

  void _finishWorkout() async {
    List<Map<String, dynamic>> exercisesToSave = [];

    for (var activeEx in _workoutExercises) {
      List<Map<String, dynamic>> completedSets = [];

      for (var s in activeEx.sets) {
        if (s.isCompleted) {
          completedSets.add({
            'weight': double.tryParse(s.weightController.text) ?? 0.0,
            'reps': int.tryParse(s.repsController.text) ?? 0,
          });
        }
      }

      if (completedSets.isNotEmpty) {
        exercisesToSave.add({
          'exercise_id': activeEx.exerciseData['id'] ?? activeEx.exerciseData['exercise_id'],
          'sets': completedSets,
        });
      }
    }

    if (exercisesToSave.isEmpty) {
      Navigator.pop(context);
      return;
    }

    try {
      await DatabaseHelper.instance.saveWorkoutSession(exercisesToSave);

      // --- STOP SERVICE ---
      await _stopForegroundService();
      // --- Go to Summary Screen ---
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PostWorkoutSummaryScreen(
              workoutExercises: _workoutExercises,
              sessionStartTime: _workoutStartTime, // Passed down
              sessionEndTime: DateTime.now(),      // Captured instantly
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Workout'),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _finishWorkout,
            child: const Text('FINISH', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: _workoutExercises.isEmpty
          ? const Center(child: Text("Tap '+' to add your first exercise", style: TextStyle(color: Colors.grey)))
          : ListView.builder(
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: _workoutExercises.length,
        itemBuilder: (context, exerciseIndex) {
          final activeExercise = _workoutExercises[exerciseIndex];
          return _buildExerciseCard(activeExercise, exerciseIndex);
        },
      ),
      // --- NEW: Persistent Rest Timer Banner ---
      bottomNavigationBar: BottomAppBar(
        color: Colors.grey[900],
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _isTimerRunning
                ? TextButton(
              onPressed: () => _adjustTimer(-15),
              child: const Text('-15s', style: TextStyle(color: Colors.grey)),
            )
                : TextButton(
              onPressed: () => _resetTimer(_baseRestSeconds),
              child: const Text('RESET', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
            ),
            GestureDetector(
              onTap: _showTimerPicker, // <--- Triggers the pop-up wheel
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[800], // Subtle background to indicate it's tappable
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatTime(_restSeconds),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    // Glows teal when running
                    color: _isTimerRunning ? Colors.tealAccent : Colors.white,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => _adjustTimer(15),
              child: const Text('+15s', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: _isTimerRunning ? _stopTimer : _startTimer,
              icon: Icon(_isTimerRunning ? Icons.pause : Icons.play_arrow, color: Colors.white),
              label: Text(_isTimerRunning ? 'PAUSE' : 'START', style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isTimerRunning ? Colors.orange : Colors.teal,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: MediaQuery.of(context).viewInsets.bottom > 0
          ? null
          : FloatingActionButton.extended(
        onPressed: _addExercise,
        icon: const Icon(Icons.add),
        label: const Text('Add Exercise'),
        backgroundColor: Colors.blueAccent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildExerciseCard(ActiveExercise activeExercise, int exerciseIndex) {
    final exerciseMap = activeExercise.exerciseData;
    int exId = exerciseMap['id'] ?? exerciseMap['exercise_id'];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    exerciseMap['name'] ?? 'Exercise',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                ),
                // --- ACTION BUTTONS (SWAP & HISTORY) ---
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.swap_horiz, color: Colors.orangeAccent),
                      tooltip: 'Swap Exercise',
                      onPressed: () => _showSwapBottomSheet(exerciseIndex), // <--- Triggers swap sheet
                    ),
                    IconButton(
                      icon: const Icon(Icons.history, color: Colors.tealAccent),
                      tooltip: 'View Exercise Analytics',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ExerciseDetailsScreen(exercise: exerciseMap),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      tooltip: 'Remove Exercise',
                      onPressed: () => _confirmRemoveExercise(exerciseIndex),
                    ),
                  ],
                ),
              ],
            ),
            // --- NEW: Coach Suggestion Banner ---
            if (activeExercise.isDeload)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blueAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Plateau detected. Suggesting a 20% deload to ${activeExercise.suggestedWeight} for CNS recovery.',
                        style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            const Row(
              children: [
                SizedBox(width: 40, child: Text('Set', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                Expanded(child: Center(child: Text('kg / lbs', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))),
                Expanded(child: Center(child: Text('Reps', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))),
                SizedBox(width: 48, child: Center(child: Icon(Icons.check, color: Colors.grey, size: 18))),
              ],
            ),
            const Divider(color: Colors.grey),

            ...List.generate(activeExercise.sets.length, (setIndex) {
              final workoutSet = activeExercise.sets[setIndex];

              return Dismissible(
                // ObjectKey ensures Flutter tracks this specific set perfectly during deletion
                key: ObjectKey(workoutSet),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(8), // Matches the textfield curves
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  setState(() {
                    activeExercise.sets.removeAt(setIndex);
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      SizedBox(width: 40, child: Text('${setIndex + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          child: TextField(
                            controller: workoutSet.weightController,
                            focusNode: workoutSet.weightFocusNode,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textInputAction: TextInputAction.next,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: workoutSet.isCompleted ? Colors.green.withOpacity(0.1) : Colors.grey[800],
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          child: TextField(
                            controller: workoutSet.repsController,
                            focusNode: workoutSet.repsFocusNode,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (value) {
                              setState(() {
                                workoutSet.isCompleted = true;
                              });
                              FocusScope.of(context).unfocus();
                            },
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: workoutSet.isCompleted ? Colors.green.withOpacity(0.1) : Colors.grey[800],
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: IconButton(
                          icon: Icon(
                            workoutSet.isCompleted ? Icons.check_box : Icons.check_box_outline_blank,
                            color: workoutSet.isCompleted ? Colors.green : Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              workoutSet.isCompleted = !workoutSet.isCompleted;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  activeExercise.sets.add(WorkoutSet());
                });
              },
              child: const Text('+ Add Set', style: TextStyle(color: Colors.grey)),
            )
          ],
        ),
      ),
    );
  }
}