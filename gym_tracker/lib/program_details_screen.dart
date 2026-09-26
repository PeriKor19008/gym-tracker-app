import 'package:flutter/material.dart';
import 'exercise_library.dart';
import 'database_helper.dart';
import 'active_workout.dart';
import 'program_day_builder.dart';

class ProgramDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> program;

  const ProgramDetailsScreen({super.key, required this.program});

  @override
  State<ProgramDetailsScreen> createState() => _ProgramDetailsScreenState();
}

class _ProgramDetailsScreenState extends State<ProgramDetailsScreen> {
  List<Map<String, dynamic>> _weeks = [];
  final Map<int, List<Map<String, dynamic>>> _weekDays = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgramData();
  }

  Future<void> _loadProgramData() async {
    int programId = int.parse(widget.program['id'].toString());
    final weeks = await DatabaseHelper.instance.getProgramWeeks(programId);
    final Map<int, List<Map<String, dynamic>>> tempWeekDays = {};

    for (var week in weeks) {
      int weekId = int.parse(week['id'].toString());
      final days = await DatabaseHelper.instance.getProgramDays(weekId);

      List<Map<String, dynamic>> mutableDays = [];
      for (var day in days) {
        var mutableDay = Map<String, dynamic>.from(day);
        final exercises = await DatabaseHelper.instance.getProgramDayExercises(mutableDay['id']);

        mutableDay['exercise_count'] = exercises.length;

        Map<String, double> muscleScores = {};
        for (var ex in exercises) {
          int exId = int.parse(ex['exercise_id'].toString());
          int targetSets = int.tryParse(ex['target_sets']?.toString() ?? '3') ?? 3;

          List<Map<String, dynamic>> dbMuscles = await DatabaseHelper.instance.getExerciseMuscles(exId);
          for (var m in dbMuscles) {
            String muscleName = m['name'];
            bool isPrimary = m['is_primary'] == 1;
            double multiplier = isPrimary ? 1.0 : 0.5;

            muscleScores[muscleName] = (muscleScores[muscleName] ?? 0) + (targetSets * multiplier);
          }
        }

        List<String> muscleStrings = [];
        var sortedEntries = muscleScores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

        for (var entry in sortedEntries.take(4)) {
          String valStr = entry.value.truncateToDouble() == entry.value
              ? entry.value.toInt().toString()
              : entry.value.toStringAsFixed(1);
          // Format as "3 Core", "2 Back", etc.
          muscleStrings.add('$valStr ${entry.key}');
        }

        mutableDay['muscle_list'] = muscleStrings; // Saving as a List instead of a single String
        mutableDays.add(mutableDay);
      }
      tempWeekDays[weekId] = mutableDays;
    }

    setState(() {
      _weeks = weeks;
      _weekDays.clear();
      _weekDays.addAll(tempWeekDays);
      _isLoading = false;
    });
  }

  // --- ADD DIALOGS ---
  Future<void> _showAddWeekDialog() async {
    final TextEditingController nameController = TextEditingController();
    await _showInputDialog('Add Week', 'Week Name (e.g. Week 1)', nameController, () async {
      int programId = int.parse(widget.program['id'].toString());
      await DatabaseHelper.instance.createProgramWeek(programId, nameController.text.trim());
      _loadProgramData();
    });
  }

  Future<void> _showAddDayDialog(int weekId) async {
    final TextEditingController nameController = TextEditingController();
    await _showInputDialog('Add Day', 'Day Name (e.g. Push)', nameController, () async {
      await DatabaseHelper.instance.createProgramDay(weekId, nameController.text.trim());
      _loadProgramData();
    });
  }

  // --- RENAME DIALOGS ---
  Future<void> _showRenameWeekDialog(int weekId, String currentName) async {
    final TextEditingController nameController = TextEditingController(text: currentName);
    await _showInputDialog('Rename Week', 'New Week Name', nameController, () async {
      await DatabaseHelper.instance.renameProgramWeek(weekId, nameController.text.trim());
      _loadProgramData();
    });
  }

  Future<void> _showRenameDayDialog(int dayId, String currentName) async {
    final TextEditingController nameController = TextEditingController(text: currentName);
    await _showInputDialog('Rename Day', 'New Day Name', nameController, () async {
      await DatabaseHelper.instance.renameProgramDay(dayId, nameController.text.trim());
      _loadProgramData();
    });
  }

  // Generic Reusable Input Dialog
  Future<void> _showInputDialog(String title, String label, TextEditingController controller, Function onSave) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.grey),
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
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onSave();
                Navigator.pop(context);
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- DELETE CONFIRMATIONS ---
  Future<void> _confirmDelete(String title, String content, Function onDelete) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(content, style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              onDelete();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- REORDERING ---
  void _onReorderDays(int weekId, int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final day = _weekDays[weekId]!.removeAt(oldIndex);
      _weekDays[weekId]!.insert(newIndex, day);
    });
    await DatabaseHelper.instance.updateDayOrder(_weekDays[weekId]!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.program['name'] ?? 'Program Details'),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.add, color: Colors.teal), tooltip: 'Add Week', onPressed: _showAddWeekDialog)
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _weeks.isEmpty
          ? const Center(child: Text('No weeks added yet. Tap "+" to add Week 1!', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: _weeks.length,
        itemBuilder: (context, index) {
          return _buildWeekCard(_weeks[index]);
        },
      ),
    );
  }

  Widget _buildWeekCard(Map<String, dynamic> week) {
    int weekId = int.parse(week['id'].toString());
    String weekName = week['week_name'] ?? 'Week';
    final days = _weekDays[weekId] ?? [];

    return Card(
      color: const Color(0xFF2C2C2C), // <-- 1. LIGHTEST (Custom Hex)
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(weekName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Colors.teal, size: 22),
                      onPressed: () => _showAddDayDialog(weekId),
                    ),
                    PopupMenuButton<String>(
                      color: Colors.grey[800],
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      onSelected: (value) async {
                        if (value == 'rename') _showRenameWeekDialog(weekId, weekName);
                        if (value == 'duplicate') {
                          int programId = int.parse(widget.program['id'].toString());
                          await DatabaseHelper.instance.duplicateWeek(weekId, programId);
                          _loadProgramData();
                        }
                        if (value == 'delete') {
                          _confirmDelete('Delete Week?', 'This will permanently delete this week and all its days.', () async {
                            await DatabaseHelper.instance.deleteProgramWeek(weekId);
                            _loadProgramData();
                          });
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'rename', child: Text('Rename Week', style: TextStyle(color: Colors.white))),
                        const PopupMenuItem(value: 'duplicate', child: Text('Duplicate Week', style: TextStyle(color: Colors.white))),
                        const PopupMenuItem(value: 'delete', child: Text('Delete Week', style: TextStyle(color: Colors.redAccent))),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const Divider(color: Colors.grey),
            days.isEmpty
                ? const Padding(padding: EdgeInsets.all(8.0), child: Text('No days in this week.', style: TextStyle(color: Colors.grey)))
                : ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: days.length,
              onReorder: (oldIndex, newIndex) => _onReorderDays(weekId, oldIndex, newIndex),
              itemBuilder: (context, dayIndex) {
                return _buildDayCard(days[dayIndex], key: ValueKey(days[dayIndex]['id']));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCard(Map<String, dynamic> day, {required Key key}) {
    int dayId = int.parse(day['id'].toString());
    String dayName = day['day_name'] ?? 'Day';
    int exerciseCount = day['exercise_count'] ?? 0;

    List<String> muscleList = day['muscle_list'] != null
        ? List<String>.from(day['muscle_list'])
        : [];

    return Card(
      key: key,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProgramDayBuilderScreen(dayId: dayId, dayName: dayName),
            ),
          ).then((_) => _loadProgramData());
        },
        child: Column(
          children: [
            // --- TOP SECTION ---
            Ink(
              color: const Color(0xFF242424), // <-- 2. MIDDLE (Custom Hex)
              child: Padding(
                padding: const EdgeInsets.only(left: 12.0, right: 8.0, top: 6.0, bottom: 6.0),
                child: Row(
                  children: [
                    const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(dayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill, color: Colors.teal, size: 32),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Start Workout',
                      onPressed: () async {
                        int sessionId = await DatabaseHelper.instance.startWorkoutFromProgramDay(dayId);
                        if (context.mounted) {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => ActiveWorkoutScreen(sessionId: sessionId)));
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            // --- BOTTOM SECTION ---
            Ink(
              color: const Color(0xFF1C1C1C), // <-- 3. DARKEST (Custom Hex)
              child: Padding(
                padding: const EdgeInsets.only(left: 44.0, right: 12.0, top: 12.0, bottom: 16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '$exerciseCount exercises',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)
                    ),
                    const SizedBox(width: 24),
                    if (muscleList.isNotEmpty)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: muscleList.map((m) =>
                              Text(m, style: TextStyle(color: Colors.grey[400], fontSize: 12, height: 1.3))
                          ).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}