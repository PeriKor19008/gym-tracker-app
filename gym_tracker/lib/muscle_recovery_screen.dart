import 'package:flutter/material.dart';
import 'database_helper.dart';

class MuscleRecoveryScreen extends StatefulWidget {
  const MuscleRecoveryScreen({super.key});

  @override
  State<MuscleRecoveryScreen> createState() => _MuscleRecoveryScreenState();
}

class _MuscleRecoveryScreenState extends State<MuscleRecoveryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _recoveryData = [];

  @override
  void initState() {
    super.initState();
    _loadRecoveryData();
  }

  Future<void> _loadRecoveryData() async {
    final data = await DatabaseHelper.instance.getMuscleRecoveryData();
    setState(() {
      _recoveryData = data;
      _isLoading = false;
    });
  }

  // --- RECOVERY MATH ENGINE ---
  Map<String, dynamic> _calculateRecovery(String? lastTrainedStr) {
    if (lastTrainedStr == null) {
      return {
        'percentage': 100,
        'status': 'Prime Readiness',
        'color': Colors.green,
        'subtitle': 'Never trained / Fully fresh'
      };
    }

    DateTime lastTrained = DateTime.parse(lastTrainedStr);
    Duration difference = DateTime.now().difference(lastTrained);
    double hoursElapsed = difference.inHours.toDouble();

    // Standard recovery window set to 48 hours for full muscular recuperation
    const double standardRecoveryHours = 48.0;

    double recoveryPercent = (hoursElapsed / standardRecoveryHours) * 100;
    if (recoveryPercent > 100) recoveryPercent = 100;

    Color statusColor;
    String statusText;

    if (recoveryPercent < 40) {
      statusColor = Colors.redAccent;
      statusText = 'Fatigued';
    } else if (recoveryPercent < 80) {
      statusColor = Colors.orangeAccent;
      statusText = 'Recovering';
    } else if (recoveryPercent < 100) {
      statusColor = Colors.lightGreen;
      statusText = 'Nearly Ready';
    } else {
      statusColor = Colors.green;
      statusText = 'Prime Readiness';
    }

    int hoursLeft = (standardRecoveryHours - hoursElapsed).toInt();
    String subtitle = hoursLeft > 0
        ? 'Fully recovered in ~$hoursLeft hours'
        : 'Fully recovered & ready';

    return {
      'percentage': recoveryPercent.toInt(),
      'status': statusText,
      'color': statusColor,
      'subtitle': subtitle,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Muscle Readiness Engine'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recoveryData.isEmpty
          ? const Center(child: Text('No muscle data found.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _recoveryData.length,
        itemBuilder: (context, index) {
          final muscle = _recoveryData[index];
          String muscleName = muscle['muscle_name'];
          String? lastTrained = muscle['last_trained'];

          final recovery = _calculateRecovery(lastTrained);
          int percent = recovery['percentage'];
          Color color = recovery['color'];
          String status = recovery['status'];
          String subtitle = recovery['subtitle'];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      muscleName,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Linear progress bar for recovery
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: percent / 100.0,
                    backgroundColor: Colors.grey[800],
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(subtitle, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    Text('$percent%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}