import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'database_helper.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _sessions = [];
  Map<String, dynamic> _analytics = {'tonnage': [], 'muscles': [], 'consistency': []};
  bool _isLoading = true;

  final List<Color> _pieColors = [
    Colors.teal, Colors.blueAccent, Colors.deepPurpleAccent,
    Colors.orange, Colors.redAccent, Colors.green, Colors.pinkAccent
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final sessionData = await DatabaseHelper.instance.getWorkoutHistory();
    final analyticsData = await DatabaseHelper.instance.getMacroAnalytics();

    setState(() {
      _sessions = sessionData;
      _analytics = analyticsData;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // DefaultTabController handles the swiping and tab state automatically
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Progression & Logs'),
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.teal,
            tabs: [
              Tab(icon: Icon(Icons.insights), text: 'General View'),
              Tab(icon: Icon(Icons.history), text: 'Workout Logs'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : TabBarView(
          children: [
            // TAB 1: The General View (Analytics)
            _buildAnalyticsTab(),
            // TAB 2: The Log List (History)
            _buildLogsTab(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: ANALYTICS WIDGETS
  // ==========================================
  Widget _buildAnalyticsTab() {
    if (_sessions.isEmpty) {
      return const Center(child: Text('No data yet. Complete a workout to see analytics!', style: TextStyle(color: Colors.grey)));
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildConsistencyChart(),
        const SizedBox(height: 24),
        _buildTonnageChart(),
        const SizedBox(height: 24),
        _buildMusclePieChart(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildConsistencyChart() {
    List<Map<String, dynamic>> data = _analytics['consistency'] ?? [];
    if (data.isEmpty) return const SizedBox();

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < data.length; i++) {
      barGroups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: (data[i]['workout_count'] as int).toDouble(),
                color: Colors.blueAccent,
                width: 16,
                borderRadius: BorderRadius.circular(4),
              )
            ],
          )
      );
    }

    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Consistency (Workouts / Month)', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index >= 0 && index < data.length) {
                            // Extract just the month (e.g. '07' from '2026-07')
                            String month = data[index]['month'].toString().split('-').last;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(month, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  barGroups: barGroups,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTonnageChart() {
    List<Map<String, dynamic>> data = _analytics['tonnage'] ?? [];
    if (data.isEmpty) return const SizedBox();

    List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), (data[i]['tonnage'] as num).toDouble()));
    }

    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Total Tonnage per Session (kg/lbs)', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // Hide dates to keep it clean
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.teal,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: Colors.teal.withOpacity(0.15)),
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

  Widget _buildMusclePieChart() {
    List<Map<String, dynamic>> data = _analytics['muscles'] ?? [];
    if (data.isEmpty) return const SizedBox();

    List<PieChartSectionData> pieSections = List.generate(data.length, (i) {
      return PieChartSectionData(
        color: _pieColors[i % _pieColors.length],
        value: (data[i]['set_count'] as int).toDouble(),
        title: data[i]['muscle'],
        radius: 60,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    });

    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Muscle Group Focus (Total Sets)', style: TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: pieSections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: LOGS LIST
  // ==========================================
  Widget _buildLogsTab() {
    if (_sessions.isEmpty) {
      return const Center(child: Text('No workouts logged yet.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        DateTime date = DateTime.parse(session['start_time']);
        String formattedDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formattedDate, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.teal.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                      child: Text('${session['exercise_count']} Exercises', style: const TextStyle(color: Colors.teal, fontSize: 12, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Text(session['exercise_names'] ?? 'No exercises recorded.', style: TextStyle(color: Colors.grey[400], height: 1.4)),
              ],
            ),
          ),
        );
      },
    );
  }
}