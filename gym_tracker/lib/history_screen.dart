import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'database_helper.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _allSessions = []; // Stores the raw DB data
  List<Map<String, dynamic>> _sessions = []; // Used for the Ledger
  List<Map<String, dynamic>> _weeklyStats = []; // Used for the Stats charts

  bool _isLoading = true;
  int _chartResolution = 12; // Default to 12 weeks. 0 means "All Time"

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final sessionData = await DatabaseHelper.instance.getWorkoutHistory();

    if (mounted) {
      setState(() {
        _allSessions = sessionData;
        _sessions = sessionData;
        _processChartData(); // Process the math based on the current resolution
        _isLoading = false;
      });
    }
  }

  // Instantly recalculates chart data in memory without hitting the database
  void _processChartData() {
    Map<DateTime, int> weeklyCounts = {};
    Map<DateTime, double> weeklyTonnage = {};

    for (var session in _allSessions) {
      try {
        DateTime date = DateTime.parse(session['start_time']);
        DateTime monday = DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - 1));

        weeklyCounts[monday] = (weeklyCounts[monday] ?? 0) + 1;

        double sessionTonnage = double.tryParse(session['total_tonnage']?.toString() ?? '0') ?? 0.0;
        weeklyTonnage[monday] = (weeklyTonnage[monday] ?? 0.0) + sessionTonnage;
      } catch (e) {
        debugPrint("Error parsing date: $e");
      }
    }

    List<Map<String, dynamic>> weeklyData = [];
    var sortedWeeks = weeklyCounts.keys.toList()..sort();

    // Slice the data based on the selected dropdown resolution
    if (_chartResolution > 0 && sortedWeeks.length > _chartResolution) {
      sortedWeeks = sortedWeeks.sublist(sortedWeeks.length - _chartResolution);
    }

    for (var week in sortedWeeks) {
      weeklyData.add({
        'week_label_date': week.toIso8601String(),
        'workout_count': weeklyCounts[week],
        'total_tonnage': weeklyTonnage[week],
      });
    }

    _weeklyStats = weeklyData;
  }

  // ==========================================
  // SHARED DROPDOWN WIDGET
  // ==========================================
  Widget _buildResolutionDropdown() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<int>(
        value: _chartResolution,
        dropdownColor: Colors.grey[900],
        icon: const Icon(Icons.arrow_drop_down, color: Colors.teal, size: 20),
        underline: const SizedBox(), // Removes the default ugly underline
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        items: const [
          DropdownMenuItem(value: 4, child: Text('4 Weeks')),
          DropdownMenuItem(value: 12, child: Text('12 Weeks')),
          DropdownMenuItem(value: 24, child: Text('24 Weeks')),
          DropdownMenuItem(value: 0, child: Text('All Time')),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _chartResolution = value;
              _processChartData(); // Instantly update the UI
            });
          }
        },
      ),
    );
  }

  // ==========================================
  // TAB 1: THE LEDGER
  // ==========================================
  Widget _buildGroupedHistory() {
    if (_sessions.isEmpty) {
      return const Center(child: Text('No workouts logged yet.', style: TextStyle(color: Colors.grey)));
    }

    List<Widget> listItems = [];
    String lastDateString = '';
    int dayGroupIndex = -1;

    final Color colorX = const Color(0xFF1C1C1C);
    final Color colorY = const Color(0xFF2A2A2A);

    for (var session in _sessions) {
      DateTime date = DateTime.parse(session['start_time']);
      String dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      String timeString = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

      if (dateString != lastDateString) {
        dayGroupIndex++;
        lastDateString = dateString;

        listItems.add(
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 24, bottom: 8, right: 16),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.teal, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    dateString,
                    style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Divider(color: Colors.grey[800])),
                ],
              ),
            )
        );
      }

      Color cardColor = (dayGroupIndex % 2 == 0) ? colorX : colorY;
      int sessionId = int.tryParse(session['session_id']?.toString() ?? '0') ?? 0;

      bool isProgram = session['program_name'] != null;
      String programDisplay = isProgram
          ? '${session['program_name']} • ${session['day_name']}'
          : 'Ad-Hoc Workout';
      Color programColor = isProgram ? Colors.deepPurpleAccent : Colors.grey;
      IconData programIcon = isProgram ? Icons.view_timeline : Icons.play_circle_outline;

      listItems.add(
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SessionDetailScreen(
                    sessionId: sessionId,
                    formattedDate: '$dateString at $timeString',
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(timeString, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.teal.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                        child: Text('${session['exercise_count']} Exercises', style: const TextStyle(color: Colors.teal, fontSize: 12, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(programIcon, color: programColor, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          programDisplay,
                          style: TextStyle(color: programColor, fontWeight: FontWeight.w600, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(session['exercise_names'] ?? 'No exercises recorded.', style: TextStyle(color: Colors.grey[400], height: 1.4)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: listItems,
    );
  }

  // ==========================================
  // TAB 2: GLOBAL STATS
  // ==========================================
  Widget _buildStatsTab() {
    if (_weeklyStats.isEmpty) {
      return const Center(child: Text('No data yet.', style: TextStyle(color: Colors.grey)));
    }

    double maxWorkouts = 0;
    List<BarChartGroupData> barGroups = [];

    double minTonnage = double.infinity;
    double maxTonnage = 0;
    List<FlSpot> tonnageSpots = [];

    for (int i = 0; i < _weeklyStats.length; i++) {
      double count = (_weeklyStats[i]['workout_count'] as num).toDouble();
      if (count > maxWorkouts) maxWorkouts = count;
      barGroups.add(
        BarChartGroupData(
            x: i,
            barRods: [BarChartRodData(toY: count, color: Colors.blueAccent, width: 16, borderRadius: BorderRadius.circular(4))]
        ),
      );

      double ton = (_weeklyStats[i]['total_tonnage'] as num).toDouble();
      if (ton < minTonnage) minTonnage = ton;
      if (ton > maxTonnage) maxTonnage = ton;
      tonnageSpots.add(FlSpot(i.toDouble(), ton));
    }

    if (minTonnage == double.infinity) minTonnage = 0;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [

        // --- 1. TOTAL TONNAGE CHART ---
        Card(
          color: const Color(0xFF1C1C1C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Training Volume', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 16)),
                    _buildResolutionDropdown(),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 220,
                  child: LineChart(
                    LineChartData(
                      minY: minTonnage * 0.8,
                      maxY: maxTonnage * 1.1,
                      gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[850], strokeWidth: 1)
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 35,
                            getTitlesWidget: (value, meta) {
                              int index = value.toInt();
                              if (index >= 0 && index < _weeklyStats.length) {
                                DateTime parsed = DateTime.parse(_weeklyStats[index]['week_label_date']);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text('${parsed.day}/${parsed.month}', style: const TextStyle(color: Colors.grey, fontSize: 10)),                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: tonnageSpots,
                          isCurved: true,
                          color: Colors.teal,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                  radius: 4, color: Colors.teal, strokeWidth: 2, strokeColor: const Color(0xFF1C1C1C)
                              )
                          ),
                          belowBarData: BarAreaData(show: true, color: Colors.teal.withOpacity(0.15)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // --- 2. CONSISTENCY CHART ---
        Card(
          color: const Color(0xFF1C1C1C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Workouts Per Week', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    _buildResolutionDropdown(),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      maxY: maxWorkouts == 0 ? 7 : maxWorkouts * 1.3,
                      gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[850], strokeWidth: 1)
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              if (value % 1 == 0) {
                                return Text(value.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 11));
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 35,
                            getTitlesWidget: (value, meta) {
                              int index = value.toInt();
                              if (index >= 0 && index < _weeklyStats.length) {
                                DateTime parsed = DateTime.parse(_weeklyStats[index]['week_label_date']);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text('${parsed.day}/${parsed.month}', style: const TextStyle(color: Colors.grey, fontSize: 10)),                                );
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
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          title: const Text('Workout History', style: TextStyle(fontWeight: FontWeight.bold)),
          elevation: 0,
          centerTitle: true,
          backgroundColor: const Color(0xFF1C1C1C),
          bottom: const TabBar(
            indicatorColor: Colors.teal,
            labelColor: Colors.teal,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.list_alt), text: 'Ledger'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Stats'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : TabBarView(
          children: [
            _buildGroupedHistory(),
            _buildStatsTab(),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// SESSION DETAIL SCREEN
// ==========================================
class SessionDetailScreen extends StatelessWidget {
  final int sessionId;
  final String formattedDate;

  const SessionDetailScreen({super.key, required this.sessionId, required this.formattedDate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(formattedDate, style: const TextStyle(fontSize: 16)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper.instance.getSessionDetails(sessionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.teal));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No details found for this session.', style: TextStyle(color: Colors.grey)));
          }

          final exercises = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final ex = exercises[index];
              final exerciseName = ex['exercise_name'];
              final List sets = ex['sets'];

              return Card(
                color: const Color(0xFF1C1C1C),
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exerciseName,
                        style: const TextStyle(color: Colors.blueAccent, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.grey, height: 1),
                      const SizedBox(height: 8),
                      ...sets.map<Widget>((s) {
                        int setNum = s['set_number'];
                        double weight = double.tryParse(s['weight'].toString()) ?? 0.0;
                        int reps = int.tryParse(s['reps'].toString()) ?? 0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Set $setNum', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                              Text('${weight.toStringAsFixed(1)} kg × $reps reps',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}