import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'active_workout.dart';
import 'database_helper.dart';

// Helper class to hold exercise summary data including multiple PR statuses
class ExerciseSummaryResult {
  final ActiveExercise exercise;
  final Map<String, dynamic> fatigueAnalysis;
  final bool isWeightPR;
  final bool is1RMPR;
  final double maxWeightLifted;
  final double max1RMLifted;

  ExerciseSummaryResult({
    required this.exercise,
    required this.fatigueAnalysis,
    required this.isWeightPR,
    required this.is1RMPR,
    required this.maxWeightLifted,
    required this.max1RMLifted,
  });
}

class PostWorkoutSummaryScreen extends StatefulWidget {
  final List<ActiveExercise> workoutExercises;
  final DateTime sessionStartTime;
  final DateTime sessionEndTime;

  const PostWorkoutSummaryScreen({
    super.key,
    required this.workoutExercises,
    required this.sessionStartTime,
    required this.sessionEndTime,
  });

  @override
  State<PostWorkoutSummaryScreen> createState() => _PostWorkoutSummaryScreenState();
}

class _PostWorkoutSummaryScreenState extends State<PostWorkoutSummaryScreen> {
  bool _isLoading = true;
  double _totalTonnage = 0;
  int _totalSets = 0;
  int _totalReps = 0;

  Map<String, double> _muscleScores = {};
  List<ExerciseSummaryResult> _analyzedExercises = [];

  @override
  void initState() {
    super.initState();
    _calculateWorkoutData();
  }

  // --- Formula for Estimated 1RM (Epley Formula) ---
  double _calculateEstimated1RM(double weight, int reps) {
    if (reps <= 0) return 0;
    if (reps == 1) return weight;
    return weight * (1 + (reps / 30.0));
  }

  Future<void> _calculateWorkoutData() async {
    double tempTonnage = 0;
    int tempSets = 0;
    int tempReps = 0;
    Map<String, double> tempScores = {};
    List<ExerciseSummaryResult> tempAnalyzed = [];

    String startTimeStr = widget.sessionStartTime.toIso8601String();

    for (var ex in widget.workoutExercises) {
      List<WorkoutSet> completedSets = ex.sets.where((s) => s.isCompleted).toList();
      if (completedSets.isEmpty) continue;

      int setsDone = completedSets.length;
      tempSets += setsDone;

      double exerciseMaxWeight = 0;
      double exerciseMax1RM = 0;

      for (var s in completedSets) {
        double w = double.tryParse(s.weightController.text) ?? 0.0;
        int r = int.tryParse(s.repsController.text) ?? 0;
        tempReps += r;
        tempTonnage += (w * r);

        if (w > exerciseMaxWeight) exerciseMaxWeight = w;

        double set1RM = _calculateEstimated1RM(w, r);
        if (set1RM > exerciseMax1RM) exerciseMax1RM = set1RM;
      }

      // --- DUAL PR ENGINE CHECK ---
      int exId = ex.exerciseData['id'] ?? ex.exerciseData['exercise_id'];

      // 1. Max Weight Check
      double previousMaxWeight = await DatabaseHelper.instance.getPreviousMaxWeight(exId, startTimeStr);
      bool isWeightPR = previousMaxWeight > 0 && exerciseMaxWeight > previousMaxWeight;

      // 2. Estimated 1RM Check
      List<Map<String, dynamic>> pastSets = await DatabaseHelper.instance.getPreviousSets(exId, startTimeStr);
      double previousMax1RM = 0;
      for (var row in pastSets) {
        double pw = double.tryParse(row['weight'].toString()) ?? 0.0;
        int pr = int.tryParse(row['reps'].toString()) ?? 0;
        double past1RM = _calculateEstimated1RM(pw, pr);
        if (past1RM > previousMax1RM) previousMax1RM = past1RM;
      }
      bool is1RMPR = previousMax1RM > 0 && exerciseMax1RM > previousMax1RM;

      // Muscle distribution score calculation
      List<Map<String, dynamic>> dbMuscles = await DatabaseHelper.instance.getExerciseMuscles(exId);
      for (var m in dbMuscles) {
        String muscleName = m['name'];
        bool isPrimary = m['is_primary'] == 1;
        double multiplier = isPrimary ? 1.0 : 0.5;
        double impactScore = setsDone * multiplier;
        tempScores[muscleName] = (tempScores[muscleName] ?? 0) + impactScore;
      }

      var fatigue = _calculateFatigue(ex);

      tempAnalyzed.add(ExerciseSummaryResult(
        exercise: ex,
        fatigueAnalysis: fatigue,
        isWeightPR: isWeightPR,
        is1RMPR: is1RMPR,
        maxWeightLifted: exerciseMaxWeight,
        max1RMLifted: exerciseMax1RM,
      ));
    }

    setState(() {
      _totalTonnage = tempTonnage;
      _totalSets = tempSets;
      _totalReps = tempReps;
      _muscleScores = tempScores;
      _analyzedExercises = tempAnalyzed;
      _isLoading = false;
    });
  }

  Map<String, dynamic> _calculateFatigue(ActiveExercise exercise) {
    List<WorkoutSet> completed = exercise.sets.where((s) => s.isCompleted).toList();
    if (completed.length < 2) {
      return {'status': 'N/A', 'message': 'Need at least 2 sets to analyze.', 'color': Colors.grey};
    }

    Map<double, List<int>> weightToReps = {};
    for (var s in completed) {
      double w = double.tryParse(s.weightController.text) ?? 0.0;
      int r = int.tryParse(s.repsController.text) ?? 0;
      if (!weightToReps.containsKey(w)) weightToReps[w] = [];
      weightToReps[w]!.add(r);
    }

    int maxDropPercent = 0;
    bool foundValidSets = false;

    for (var entry in weightToReps.entries) {
      if (entry.value.length >= 2) {
        foundValidSets = true;
        int firstRep = entry.value.first;
        int minRep = entry.value.reduce((a, b) => a < b ? a : b);

        if (firstRep > 0) {
          int drop = firstRep - minRep;
          int dropPercent = ((drop / firstRep) * 100).toInt();
          if (dropPercent > maxDropPercent) maxDropPercent = dropPercent;
        }
      }
    }

    if (!foundValidSets) {
      return {'status': 'N/A', 'message': 'Weights varied every set. Hard to analyze.', 'color': Colors.grey};
    } else if (maxDropPercent >= 40) {
      return {'status': 'High Fatigue', 'message': 'Massive rep drop ($maxDropPercent%). Rest 2-3 mins next time!', 'color': Colors.redAccent};
    } else if (maxDropPercent >= 20) {
      return {'status': 'Moderate Fatigue', 'message': 'Noticeable drop ($maxDropPercent%). Consider +30s rest.', 'color': Colors.orangeAccent};
    } else {
      return {'status': 'Great Endurance', 'message': 'Solid rep consistency. Perfect pacing!', 'color': Colors.green};
    }
  }

  String _formatDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  List<PieChartSectionData> _buildChartSections() {
    List<Color> chartColors = [
      Colors.blueAccent, Colors.purpleAccent, Colors.orangeAccent,
      Colors.tealAccent, Colors.redAccent, Colors.yellowAccent
    ];

    List<PieChartSectionData> sections = [];
    int colorIndex = 0;

    _muscleScores.forEach((muscle, score) {
      sections.add(PieChartSectionData(
        color: chartColors[colorIndex % chartColors.length],
        value: score,
        title: muscle,
        radius: 40,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      colorIndex++;
    });

    return sections;
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Workout Summary'),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: _totalSets == 0
          ? const Center(child: Text("No sets completed.", style: TextStyle(color: Colors.grey)))
          : SingleChildScrollView(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: Icon(Icons.emoji_events, color: Colors.amber, size: 48),
            ),
            const Text('Session Complete!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(child: _buildStatCard('Tonnage', '${_totalTonnage.toStringAsFixed(0)} kg', Icons.fitness_center, Colors.blueAccent)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStatCard('Sets/Reps', '$_totalSets / $_totalReps', Icons.repeat, Colors.purpleAccent)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStatCard('Time', _formatDuration(widget.sessionStartTime, widget.sessionEndTime), Icons.timer, Colors.orangeAccent)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_muscleScores.isNotEmpty) ...[
              const Text('Muscle Distribution', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 60,
                        sections: _buildChartSections(),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$_totalSets', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                        const Text('Sets', style: TextStyle(color: Colors.grey)),
                      ],
                    )
                  ],
                ),
              ),
            ],

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Divider(color: Colors.grey, height: 1),
            ),

            const Text('Fatigue & PR Analysis', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: _analyzedExercises.map((result) {
                  final ex = result.exercise;
                  final fatigue = result.fatigueAnalysis;
                  bool hasAnyPR = result.isWeightPR || result.is1RMPR;

                  return Card(
                    color: Colors.grey[900],
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: hasAnyPR ? Colors.amber : fatigue['color'].withOpacity(0.3),
                        width: hasAnyPR ? 2 : 1,
                      ),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.all(16),
                        iconColor: Colors.grey,
                        collapsedIconColor: Colors.grey,
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                ex.exerciseData['name'],
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                              ),
                            ),
                            // --- CELEBRATORY PR BADGES ---
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (result.isWeightPR)
                                  Container(
                                    margin: const EdgeInsets.only(left: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.amber),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.emoji_events, color: Colors.amber, size: 12),
                                        SizedBox(width: 3),
                                        Text('WEIGHT PR', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                if (result.is1RMPR)
                                  Container(
                                    margin: const EdgeInsets.only(left: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.amber),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.trending_up, color: Colors.amber, size: 12),
                                        SizedBox(width: 3),
                                        Text('1RM PR', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(fatigue['message'], style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: fatigue['color'].withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            fatigue['status'],
                            style: TextStyle(color: fatigue['color'], fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        children: [
                          Container(
                            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                            child: Column(
                              children: ex.sets.where((s) => s.isCompleted).map((s) {
                                int setIndex = ex.sets.indexOf(s) + 1;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Set $setIndex', style: const TextStyle(color: Colors.grey)),
                                      Text('${s.weightController.text} kg × ${s.repsController.text} reps',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('DONE', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}