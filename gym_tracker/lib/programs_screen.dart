import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'main.dart';
import 'program_details_screen.dart';
import 'active_workout.dart';
import 'program_analytics_screen.dart';

class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> {
  List<Map<String, dynamic>> _programs = [];
  Map<int, Map<String, dynamic>> _trackingData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrograms();
  }

  Future<void> _loadPrograms() async {
    try {
      setState(() => _isLoading = true);

      final data = await DatabaseHelper.instance.getPrograms();
      Map<int, Map<String, dynamic>> tracking = {};

      for (var program in data) {
        int pid = int.parse(program['id'].toString());
        tracking[pid] = await DatabaseHelper.instance.getProgramTrackingInfo(pid);
      }

      setState(() {
        _programs = data;
        _trackingData = tracking;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('Database Schema Error', style: TextStyle(color: Colors.redAccent)),
            content: Text('The physical device is missing new tables:\n\n$e', style: const TextStyle(color: Colors.white)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Colors.teal)),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _showCreateProgramDialog() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Create New Program', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Program Name (e.g. Push/Pull/Legs)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                maxLines: 2,
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
                String name = nameController.text.trim();
                String desc = descController.text.trim();

                if (name.isNotEmpty) {
                  try {
                    // Attempt to write to database
                    await DatabaseHelper.instance.createProgram(name, desc);

                    if (context.mounted) {
                      Navigator.pop(context); // Close the input dialog
                    }
                    _loadPrograms(); // Refresh UI
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context); // Close input dialog first
                      // POP UP THE VISUAL ERROR BANNER
                      showAppErrorDialog(context, 'Failed to Save Program', e);
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
        title: const Text('My Programs'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _programs.isEmpty
          ? const Center(child: Text('No programs created yet.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _programs.length,
        itemBuilder: (context, index) {
          final program = _programs[index];
          int programId = int.parse(program['id'].toString());
          final tracking = _trackingData[programId] ?? {};

          var lastWorkout = tracking['last'];
          var nextWorkout = tracking['next'];

          return Dismissible(
            key: ValueKey(programId),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
              return await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Colors.grey[900],
                  title: Text('Delete "${program['name']}"?', style: const TextStyle(color: Colors.white)),
                  content: const Text(
                    'This will permanently delete this program and all its routine days and exercises.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Delete', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
            onDismissed: (direction) async {
              await DatabaseHelper.instance.deleteProgram(programId);
              setState(() {
                _programs.removeAt(index);
              });
            },
            background: Container(
              alignment: Alignment.centerRight,
              margin: const EdgeInsets.only(bottom: 12.0),
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete, color: Colors.white, size: 28),
            ),
            child: Card(
              color: Colors.grey[850], // Matched to your uploaded image
              margin: const EdgeInsets.only(bottom: 12.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // TOP SECTION: Title and Details Button
                    // TOP SECTION: Title and Details Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                program['name'] ?? 'Unnamed Program',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                program['description'] == null || program['description'].isEmpty
                                    ? 'No description provided.'
                                    : program['description'],
                                style: TextStyle(color: Colors.grey[400], fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        // --- NEW: Wrap buttons in a Row ---
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.insights, color: Colors.blueAccent),
                              tooltip: 'Analytics',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProgramAnalyticsScreen(
                                      programId: programId,
                                      programName: program['name'] ?? 'Program',
                                    ),
                                  ),
                                );
                              },
                            ),
                            TextButton(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => ProgramDetailsScreen(program: program)),
                                );
                                _loadPrograms();
                              },
                              child: const Text('DETAILS', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const Divider(height: 24, color: Colors.grey),

                    // BOTTOM SECTION: Tracking & Start Action
                    if (nextWorkout == null)
                      const Text('Routine is empty. Tap Details to add weeks.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. Only renders this text if a previous workout exists
                                if (lastWorkout != null)
                                  Text(
                                    'Last: ${lastWorkout['week_name']} • ${lastWorkout['day_name']}',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                                  ),

                                // 2. Only adds spacing if the "Last" text is actually there
                                if (lastWorkout != null)
                                  const SizedBox(height: 4),

                                // 3. Always displays the upcoming workout
                                Text(
                                  'Next: ${nextWorkout['week_name']} • ${nextWorkout['day_name']}',
                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              int dayIdToStart = nextWorkout['day_id'];
                              int sessionId = await DatabaseHelper.instance.startWorkoutFromProgramDay(dayIdToStart);

                              if (context.mounted) {
                                // Wait for the active workout to finish, then update the tracking banner
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => ActiveWorkoutScreen(sessionId: sessionId)),
                                );
                                _loadPrograms();
                              }
                            },
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: const Text('START'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateProgramDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Program'),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }
}