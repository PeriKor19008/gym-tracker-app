import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'program_details_screen.dart';

class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> {
  List<Map<String, dynamic>> _programs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrograms();
  }

  Future<void> _loadPrograms() async {
    final data = await DatabaseHelper.instance.getPrograms();
    setState(() {
      _programs = data;
      _isLoading = false;
    });
  }

  Future<void> _showCreateProgramDialog() async {
    String newName = '';
    String newDescription = '';

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Create New Program'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Program Name (e.g. Push/Pull/Legs)',
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                onChanged: (val) => newName = val,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                maxLines: 2,
                onChanged: (val) => newDescription = val,
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
                if (newName.trim().isNotEmpty) {
                  await DatabaseHelper.instance.createProgram(newName.trim(), newDescription.trim());
                  if (context.mounted) Navigator.pop(context);
                  _loadPrograms();
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- NEW: Confirmation Dialog before Deleting ---
  Future<void> _showDeleteConfirmation(int programId, String programName) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Delete "$programName"?'),
          content: const Text(
            'This will permanently delete this program and all its routine days and exercises.',
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                await DatabaseHelper.instance.deleteProgram(programId);
                if (context.mounted) Navigator.pop(context);
                _loadPrograms();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
          return Card(
            color: Colors.grey[850],
            margin: const EdgeInsets.only(bottom: 12.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16.0),
              title: Text(
                program['name'] ?? 'Unnamed Program',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  program['description'] == null || program['description'].isEmpty
                      ? 'No description provided.'
                      : program['description'],
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ),
              // --- NEW: Delete icon combined with the arrow ---
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    tooltip: 'Delete Program',
                    onPressed: () => _showDeleteConfirmation(
                      int.parse(program['id'].toString()),
                      program['name'] ?? 'Program',
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.teal, size: 18),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProgramDetailsScreen(program: program),
                  ),
                );
              },
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