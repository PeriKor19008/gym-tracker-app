import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'program_details_screen.dart';
import 'active_workout.dart';
import 'program_analytics_screen.dart';

class ProgramCard extends StatelessWidget {
  final Map<String, dynamic> program;
  final Map<String, dynamic> tracking;
  final VoidCallback onRefresh; // Tells the parent screen to reload when you finish a workout

  const ProgramCard({
    super.key,
    required this.program,
    required this.tracking,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    int programId = int.parse(program['id'].toString());
    var lastWorkout = tracking['last'];
    var nextWorkout = tracking['next'];

    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                        onRefresh();
                      },
                      child: const Text('DETAILS', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24, color: Colors.grey),
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
                        if (lastWorkout != null)
                          Text('Last: ${lastWorkout['week_name']} • ${lastWorkout['day_name']}', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                        if (lastWorkout != null) const SizedBox(height: 4),
                        Text('Next: ${nextWorkout['week_name']} • ${nextWorkout['day_name']}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      int dayIdToStart = nextWorkout['day_id'];
                      int sessionId = await DatabaseHelper.instance.startWorkoutFromProgramDay(dayIdToStart);
                      if (context.mounted) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ActiveWorkoutScreen(sessionId: sessionId)),
                        );
                        onRefresh();
                      }
                    },
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('START'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}