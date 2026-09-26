import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'database_helper.dart';

class ProgramAnalyticsScreen extends StatefulWidget {
  final int programId;
  final String programName;

  const ProgramAnalyticsScreen({super.key, required this.programId, required this.programName});

  @override
  State<ProgramAnalyticsScreen> createState() => _ProgramAnalyticsScreenState();
}

class _ProgramAnalyticsScreenState extends State<ProgramAnalyticsScreen> {
  bool _isLoading = true;

  // Macro State
  List<MacroCycleStats> _macroProgression = [];

  // Day Selection State
  List<Map<String, dynamic>> _programDays = [];
  int? _selectedDayId;

  // Micro Chart State
  List<ProgramDayCycleStats> _dayProgression = [];
  int? _selectedExerciseId;
  Map<int, String> _availableExercises = {};

  @override
  void initState() {
    super.initState();
    _loadProgramStructure();
  }

  Future<void> _loadProgramStructure() async {
    // Load Macro Data
    final macroData = await DatabaseHelper.instance.getProgramMacroProgression(widget.programId);

    // Load Micro Data Structure
    final days = await DatabaseHelper.instance.getDaysForProgramAnalytics(widget.programId);

    setState(() {
      _macroProgression = macroData;
      _programDays = days;
    });

    if (days.isNotEmpty) {
      _selectedDayId = int.parse(days.first['id'].toString());
      await _loadAnalyticsForDay(_selectedDayId!);
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAnalyticsForDay(int dayId) async {
    setState(() => _isLoading = true);

    final data = await DatabaseHelper.instance.getProgramDayProgression(dayId);
    Map<int, String> exercises = {};

    for (var cycle in data) {
      cycle.exerciseStats.forEach((id, stat) {
        exercises[id] = stat.name;
      });
    }

    setState(() {
      _dayProgression = data;
      _availableExercises = exercises;
      _selectedExerciseId = exercises.isNotEmpty ? exercises.keys.first : null;
      _selectedDayId = dayId;
      _isLoading = false;
    });
  }

  Widget _buildLineChart(List<FlSpot> spots, double minY, double maxY, String label, Color lineColor) {
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[800], strokeWidth: 1)),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('C${value.toInt()}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                getTitlesWidget: (value, meta) {
                  String text = value >= 1000 ? '${(value/1000).toStringAsFixed(1)}k' : value.toInt().toString();
                  return Text(text, style: const TextStyle(color: Colors.grey, fontSize: 10));
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
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 4, color: lineColor, strokeWidth: 1, strokeColor: Colors.white)),
              belowBarData: BarAreaData(show: true, color: lineColor.withOpacity(0.1)),
            ),
          ],
        ),
      ),
    );
  }

  // --- MACRO OVERVIEW TAB ---
  Widget _buildMacroTab() {
    if (_macroProgression.isEmpty) {
      return const Center(child: Text("Complete workouts to see program overview.", style: TextStyle(color: Colors.grey)));
    }

    // Prepare Macro Chart
    List<FlSpot> macroSpots = [];
    double minTonnage = double.infinity;
    double maxTonnage = 0;

    for (var m in _macroProgression) {
      macroSpots.add(FlSpot(m.cycleNumber.toDouble(), m.totalTonnage));
      if (m.totalTonnage < minTonnage) minTonnage = m.totalTonnage;
      if (m.totalTonnage > maxTonnage) maxTonnage = m.totalTonnage;
    }

    // Quick & Dirty Comparisons (Latest vs Previous)
    MacroCycleStats latest = _macroProgression.last;
    MacroCycleStats? previous = _macroProgression.length > 1 ? _macroProgression[_macroProgression.length - 2] : null;

    String tonnageDiff = "";
    Color diffColor = Colors.grey;
    if (previous != null) {
      double diff = latest.totalTonnage - previous.totalTonnage;
      tonnageDiff = diff > 0 ? '+${diff.toStringAsFixed(0)} kg vs C${previous.cycleNumber}' : '${diff.toStringAsFixed(0)} kg vs C${previous.cycleNumber}';
      diffColor = diff > 0 ? Colors.greenAccent : (diff < 0 ? Colors.redAccent : Colors.grey);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Quick Stats Header
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard('Current Cycle', 'C${latest.cycleNumber}', Icons.loop, Colors.purpleAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard('Workouts', '${latest.workoutsCompleted}', Icons.fitness_center, Colors.orangeAccent),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Cycle Comparison Banner
          if (previous != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF242424), borderRadius: BorderRadius.circular(12), border: Border.all(color: diffColor.withOpacity(0.5))),
              child: Column(
                children: [
                  const Text('Cycle Progression', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(tonnageDiff, style: TextStyle(color: diffColor, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Total Program Volume', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // 3. Macro Chart
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF242424), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Overall Program Volume (kg)', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 24),
                _buildLineChart(macroSpots, minTonnage == double.infinity ? 0 : minTonnage * 0.8, maxTonnage * 1.1, 'kg', Colors.purpleAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF242424), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // --- MICRO BREAKDOWN TAB (Your previous charts) ---
  Widget _buildMicroTab() {
    if (_programDays.isEmpty) {
      return const Center(child: Text("Add days to this program to view analytics.", style: TextStyle(color: Colors.grey)));
    }

    List<FlSpot> tonnageSpots = [];
    double minTonnage = double.infinity;
    double maxTonnage = 0;

    for (var cycle in _dayProgression) {
      tonnageSpots.add(FlSpot(cycle.cycleNumber.toDouble(), cycle.totalTonnage));
      if (cycle.totalTonnage < minTonnage) minTonnage = cycle.totalTonnage;
      if (cycle.totalTonnage > maxTonnage) maxTonnage = cycle.totalTonnage;
    }

    List<FlSpot> prSpots = [];
    double minPR = double.infinity;
    double maxPR = 0;

    if (_selectedExerciseId != null) {
      for (var cycle in _dayProgression) {
        if (cycle.exerciseStats.containsKey(_selectedExerciseId)) {
          double e1rm = cycle.exerciseStats[_selectedExerciseId!]!.estimated1RM;
          prSpots.add(FlSpot(cycle.cycleNumber.toDouble(), e1rm));
          if (e1rm < minPR) minPR = e1rm;
          if (e1rm > maxPR) maxPR = e1rm;
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(8)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedDayId,
                dropdownColor: const Color(0xFF2C2C2C),
                isExpanded: true,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                items: _programDays.map((day) {
                  return DropdownMenuItem<int>(
                    value: int.parse(day['id'].toString()),
                    child: Text('${day['week_name']} - ${day['day_name']}'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) _loadAnalyticsForDay(val);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (_dayProgression.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: const Color(0xFF242424), borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Text("Complete this day at least once to view progression.", style: TextStyle(color: Colors.grey), textAlign: TextAlign.center)),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF242424), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Session Volume (kg)', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 24),
                  _buildLineChart(tonnageSpots, minTonnage == double.infinity ? 0 : minTonnage * 0.8, maxTonnage * 1.1, 'kg', Colors.teal),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF242424), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Estimated 1RM Growth', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (_availableExercises.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(8)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedExerciseId,
                          dropdownColor: const Color(0xFF2C2C2C),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          isExpanded: true,
                          items: _availableExercises.entries.map((e) {
                            return DropdownMenuItem(value: e.key, child: Text(e.value));
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedExerciseId = val),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  prSpots.isEmpty
                      ? const SizedBox(height: 200, child: Center(child: Text("No 1RM data for this exercise.", style: TextStyle(color: Colors.grey))))
                      : _buildLineChart(prSpots, minPR == double.infinity ? 0 : minPR * 0.8, maxPR * 1.1, '1RM', Colors.blueAccent),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: Color(0xFF1C1C1C), body: Center(child: CircularProgressIndicator(color: Colors.teal)));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF1C1C1C),
        appBar: AppBar(
          title: Text('${widget.programName} Insights'),
          backgroundColor: const Color(0xFF242424),
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.teal,
            labelColor: Colors.teal,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: "OVERVIEW"),
              Tab(text: "DAY BREAKDOWN"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMacroTab(),
            _buildMicroTab(),
          ],
        ),
      ),
    );
  }
}