import 'package:flutter/material.dart';
import 'database_helper.dart';

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
    // 1. Fetch the days for this specific program
    final days = await DatabaseHelper.instance.getProgramDays(widget.program['id']);

    // 2. Fetch the exercises for each day
    final Map<int, List<Map<String, dynamic>>> tempDayExercises = {};
    for (var day in days) {
      final exercises = await DatabaseHelper.instance.getProgramDayExercises(day['id']);
      tempDayExercises[day['id']] = exercises;
    }

    setState(() {
      _days = days;
      _dayExercises.clear();
      _dayExercises.addAll(tempDayExercises);
      _isLoading = false;
    });
  }

  // --- NEW: The Dialog to Add a Day ---
  // --- UPDATED: Using TextEditingController for bulletproof input ---
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
                    // Safely parse the program ID to an integer
                    int programId = int.parse(widget.program['id'].toString());

                    // 1. Save to SQLite
                    await DatabaseHelper.instance.createProgramDay(programId, dayName);

                    // 2. Close Dialog
                    if (context.mounted) Navigator.pop(context);

                    // 3. Refresh UI
                    _loadProgramData();
                  } catch (e) {
                    // Show the exact error on screen so we can see it!
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.program['name'] ?? 'Program Details'),
        elevation: 0,
        actions: [
          // --- UPDATED TO CALL DIALOG ---
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
          final exercises = _dayExercises[day['id']] ?? [];

          return Card(
            color: Colors.grey[900],
            margin: const EdgeInsets.only(bottom: 16.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        day['day_name'] ?? 'Day ${index + 1}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Starting ${day['name']}...')),
                          );
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

                  // Exercise List for this Day
                  exercises.isEmpty
                      ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('No exercises added yet.', style: TextStyle(color: Colors.grey)),
                  )
                      : Column(
                    children: exercises.map((ex) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        title: Text(ex['name'], style: const TextStyle(color: Colors.white)),
                        subtitle: Text(ex['implement'] ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        trailing: const Icon(Icons.drag_handle, color: Colors.grey),
                      );
                    }).toList(),
                  ),

                  // Add Exercise to Day Button
                  TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Add Exercise to Routine Day coming next!')),
                      );
                    },
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