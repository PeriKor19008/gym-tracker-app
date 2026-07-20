import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'database_helper.dart';

class ExerciseDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> exercise;

  const ExerciseDetailsScreen({super.key, required this.exercise});

  @override
  State<ExerciseDetailsScreen> createState() => _ExerciseDetailsScreenState();
}

class _ExerciseDetailsScreenState extends State<ExerciseDetailsScreen> {
  List<Map<String, dynamic>> _progressData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final data = await DatabaseHelper.instance.getExerciseProgress(widget.exercise['id']);
    setState(() {
      _progressData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exercise['name']),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _progressData.isEmpty
          ? const Center(child: Text('No historical data found. Start lifting!', style: TextStyle(color: Colors.grey)))
          : ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildChartCard('Estimated 1RM (kg/lbs)', 'est_1rm', Colors.blueAccent),
          const SizedBox(height: 20),
          _buildChartCard('Maximum Weight (kg/lbs)', 'max_weight', Colors.deepPurpleAccent),
          const SizedBox(height: 20),
          _buildChartCard('Session Volume', 'volume', Colors.teal),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, String dataKey, Color lineColor) {
    // Convert the SQL data into points for the graph
    List<FlSpot> spots = [];
    for (int i = 0; i < _progressData.length; i++) {
      double value = (_progressData[i][dataKey] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), value));
    }

    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: lineColor, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index >= 0 && index < _progressData.length) {
                            // Extract just the Month/Day from the ISO string
                            DateTime date = DateTime.parse(_progressData[index]['date']);
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text('${date.month}/${date.day}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: lineColor,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: lineColor.withOpacity(0.15),
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