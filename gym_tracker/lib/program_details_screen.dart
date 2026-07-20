import 'package:flutter/material.dart';
import 'exercise_library.dart';
import 'database_helper.dart';
import 'active_workout.dart';

class ProgramDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> program;

  const ProgramDetailsScreen({super.key, required this.program});

  @override
  State<ProgramDetailsScreen> createState() => _ProgramDetailsScreenState();
}

class _ProgramDetailsScreenState extends State<ProgramDetailsScreen> {
  List<Map<String, dynamic>> _days = [];
  final Map<int, List<Map<String, dynamic>>> _dayExercises = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgramData();
  }

  Future<void> _loadProgramData() async {
    int programId = int.parse(widget.program['id'].toString());
    final days = await DatabaseHelper.instance.getProgramDays(programId);

    final Map<int, List<Map<String, dynamic>>> tempDayExercises = {};
    for (var day in days) {
      int dayId = int.parse(day['id'].toString());
      final exercises = await DatabaseHelper.instance.getProgramDayExercises(dayId);
      tempDayExercises[dayId] = exercises;
    }

    setState(() {
      _days = days;
      _dayExercises.clear();
      _dayExercises.addAll(tempDayExercises);
      _isLoading = false;
    });
  }

  Future<void> _showAddDayDialog() async {
    final TextEditingController nameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Add Routine Day'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Day Name (e.g. Push, Upper Body)',
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () async {
                String dayName = nameController.text.trim();
                if (dayName.isNotEmpty) {
                  try {
                    int programId = int.parse(widget.program['id'].toString());
                    await DatabaseHelper.instance.createProgramDay(programId, dayName);

                    if (context.mounted) Navigator.pop(context);
                    _loadProgramData();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showTargetInputAndAddExercise(int programDayId) async {
    final selectedExercise = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ExerciseLibraryScreen()),
    );

    if (selectedExercise == null || !mounted) return;

    final TextEditingController setsController = TextEditingController(text: '3');
    final TextEditingController repsController = TextEditingController(text: '10');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Targets for ${selectedExercise['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: setsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Target Sets',
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: repsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Target Reps',
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () async {
                try {
                  int targetSets = int.tryParse(setsController.text.trim()) ?? 3;
                  int targetReps = int.tryParse(repsController.text.trim()) ?? 10;
                  int exerciseId = int.parse(selectedExercise['id'].toString());
                  int dayId = int.parse(programDayId.toString());

                  await DatabaseHelper.instance.addExerciseToProgramDay(
                    dayId,
                    exerciseId,
                    targetSets,
                    targetReps,
                  );

                  if (context.mounted) Navigator.pop(context);
                  _loadProgramData();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error adding exercise: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.program['name'] ?? 'Program Details'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.teal),
            tooltip: 'Add Day',
            onPressed: _showAddDayDialog,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _days.isEmpty
          ? const Center(child: Text('No days added to this program yet. Tap "+" to add one!', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _days.length,
        itemBuilder: (context, index) {
          final day = _days[index];
          int dayId = int.parse(day['id'].toString());
          final exercises = _dayExercises[dayId] ?? [];

          return Card(
            color: Colors.grey[900],
            margin: const EdgeInsets.only(bottom: 16.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        day['day_name'] ?? day['name'] ?? 'Day ${index + 1}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            int sessionId = await DatabaseHelper.instance.startWorkoutFromProgramDay(dayId);

                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ActiveWorkoutScreen(sessionId: sessionId),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error starting workout: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('START'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                    ],
                  ),
                  const Divider(color: Colors.grey),

                  exercises.isEmpty
                      ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('No exercises added yet.', style: TextStyle(color: Colors.grey)),
                  )
                      : Column(
                    children: exercises.map((ex) {
                      int targetSets = int.tryParse(ex['target_sets']?.toString() ?? '3') ?? 3;
                      int targetReps = int.tryParse(ex['target_reps']?.toString() ?? '10') ?? 10;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        title: Text(ex['name'] ?? '', style: const TextStyle(color: Colors.white)),
                        subtitle: Text(
                          'Target: $targetSets sets × $targetReps reps',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                        trailing: const Icon(Icons.drag_handle, color: Colors.grey),
                      );
                    }).toList(),
                  ),

                  TextButton.icon(
                    onPressed: () => _showTargetInputAndAddExercise(dayId),
                    icon: const Icon(Icons.add_circle_outline, color: Colors.grey, size: 18),
                    label: const Text('Add Exercise', style: TextStyle(color: Colors.grey)),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}