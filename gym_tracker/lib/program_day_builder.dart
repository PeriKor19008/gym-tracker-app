import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'exercise_library.dart';

class ProgramDayBuilderScreen extends StatefulWidget {
  final int dayId;
  final String dayName;

  const ProgramDayBuilderScreen({super.key, required this.dayId, required this.dayName});

  @override
  State<ProgramDayBuilderScreen> createState() => _ProgramDayBuilderScreenState();
}

class _ProgramDayBuilderScreenState extends State<ProgramDayBuilderScreen> {
  List<Map<String, dynamic>> _exercises = [];
  bool _isLoading = true;
  late String _currentDayName; // <-- ADD THIS

  @override
  void initState() {
    super.initState();
    _currentDayName = widget.dayName; // <-- SET THIS INITIAL VALUE
    _loadDayExercises();
  }

  Future<void> _showRenameDayDialog() async {
    final TextEditingController nameController = TextEditingController(text: _currentDayName);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Rename Day', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'New Day Name',
            labelStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                await DatabaseHelper.instance.renameProgramDay(widget.dayId, nameController.text.trim());
                setState(() => _currentDayName = nameController.text.trim()); // Instantly updates AppBar
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteDay() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete Day?', style: TextStyle(color: Colors.white)),
        content: const Text('This will permanently remove this day and its exercises.', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await DatabaseHelper.instance.deleteProgramDay(widget.dayId);
              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close builder screen and go back to Program Details
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadDayExercises() async {
    final exercises = await DatabaseHelper.instance.getProgramDayExercises(widget.dayId);

    List<Map<String, dynamic>> exercisesWithDeloads = [];
    for (var ex in exercises) {
      var mutableEx = Map<String, dynamic>.from(ex);
      var deloadData = await DatabaseHelper.instance.getDeloadRecommendation(mutableEx['exercise_id']);
      if (deloadData != null) mutableEx['is_deload'] = true;
      exercisesWithDeloads.add(mutableEx);
    }

    setState(() {
      _exercises = exercisesWithDeloads;
      _isLoading = false;
    });
  }

  Future<void> _showTargetInputAndAddExercise() async {
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
          title: Text('Targets for ${selectedExercise['name']}', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: setsController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Target Sets',
                  filled: true,
                  fillColor: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: repsController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Target Reps',
                  filled: true,
                  fillColor: Colors.grey[800],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () async {
                int targetSets = int.tryParse(setsController.text.trim()) ?? 3;
                int targetReps = int.tryParse(repsController.text.trim()) ?? 10;
                int exerciseId = int.parse(selectedExercise['id'].toString());

                await DatabaseHelper.instance.addExerciseToProgramDay(widget.dayId, exerciseId, targetSets, targetReps);
                if (context.mounted) Navigator.pop(context);
                _loadDayExercises();
              },
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditTargetDialog(Map<String, dynamic> ex) async {
    final TextEditingController setsController = TextEditingController(text: ex['target_sets']?.toString() ?? '3');
    final TextEditingController repsController = TextEditingController(text: ex['target_reps']?.toString() ?? '10');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Edit Targets for ${ex['name']}', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: setsController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(labelText: 'Target Sets', filled: true, fillColor: Colors.grey[800]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: repsController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(labelText: 'Target Reps', filled: true, fillColor: Colors.grey[800]),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () async {
                int targetSets = int.tryParse(setsController.text.trim()) ?? 3;
                String targetReps = repsController.text.trim();
                int exProgramId = ex['program_day_exercise_id'];

                if (targetReps.isNotEmpty) {
                  await DatabaseHelper.instance.updateProgramDayExerciseTargets(exProgramId, targetSets, targetReps);
                  if (context.mounted) Navigator.pop(context);
                  _loadDayExercises();
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _onReorderExercises(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final exercise = _exercises.removeAt(oldIndex);
      _exercises.insert(newIndex, exercise);
    });
    await DatabaseHelper.instance.updateExerciseOrder(_exercises);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.dayName} Exercises'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showTargetInputAndAddExercise,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Exercise', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _exercises.isEmpty
          ? const Center(child: Text('No exercises added yet. Tap Add below!', style: TextStyle(color: Colors.grey)))
          : ReorderableListView.builder(
        padding: const EdgeInsets.only(bottom: 80, top: 12),
        itemCount: _exercises.length,
        onReorder: _onReorderExercises,
        itemBuilder: (context, index) {
          final ex = _exercises[index];
          int exProgramId = ex['program_day_exercise_id'];
          int targetSets = int.tryParse(ex['target_sets']?.toString() ?? '3') ?? 3;
          String targetReps = ex['target_reps']?.toString() ?? '10';

          return Card(
            key: ValueKey(exProgramId),
            color: Colors.grey[850],
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              onTap: () => _showEditTargetDialog(ex),
              leading: const Icon(Icons.drag_indicator, color: Colors.grey),
              title: Row(
                children: [
                  Expanded(child: Text(ex['name'], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                  if (ex['is_deload'] == true)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blueAccent),
                      ),
                      child: const Text('Deload', style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                ],
              ),
              subtitle: Text('Target: $targetSets sets × $targetReps reps', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
              trailing: IconButton(
                icon: const Icon(Icons.close, color: Colors.redAccent),
                onPressed: () async {
                  await DatabaseHelper.instance.removeExerciseFromDay(exProgramId);
                  _loadDayExercises();
                },
              ),
            ),
          );
        },
      ),
    );
  }
}