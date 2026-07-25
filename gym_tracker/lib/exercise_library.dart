import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'exercise_details_screen.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  List<Map<String, dynamic>> _exercises = [];
  final TextEditingController _searchController = TextEditingController();

  // Filter States
  String _selectedImplement = 'All';
  String _selectedMuscle = 'All';

  final List<String> _implements = ['All', 'Barbell', 'Dumbbell', 'Bodyweight', 'Cable', 'Machine'];
  final List<String> _muscles = [
    'All',
    'Chest',
    'Back',
    'Quads',
    'Hamstrings',
    'Calves',
    'Shoulders',
    'Triceps',
    'Biceps',
    'Core',
    'Glutes'
  ];
  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  // --- NEW: The Dialog to Create Exercise Variations ---
  void _showVariationDialog(Map<String, dynamic> parentExercise) {
    int parentId = int.parse(parentExercise['id'].toString());
    String baseName = parentExercise['name'] ?? '';
    String baseImplement = parentExercise['implement'] ?? 'Barbell';

    TextEditingController nameController = TextEditingController(text: '$baseName (');
    String selectedImplement = baseImplement;
    bool isSwappable = true; // Default to true since variations are usually swappable

    final creationImplements = _implements.where((i) => i != 'All').toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text('Create Variation of $baseName', style: const TextStyle(color: Colors.white, fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Variation Name', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 5),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text('Equipment', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 5),
                  DropdownButtonFormField<String>(
                    value: selectedImplement,
                    dropdownColor: Colors.grey[800],
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    items: creationImplements.map((imp) => DropdownMenuItem(value: imp, child: Text(imp))).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedImplement = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    title: const Text('Swappable with parent', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: const Text('Allows swapping mid-workout', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    value: isSwappable,
                    activeColor: Colors.blueAccent,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      if (val != null) setDialogState(() => isSwappable = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  onPressed: () async {
                    String variationName = nameController.text.trim();
                    if (variationName.isNotEmpty) {
                      await DatabaseHelper.instance.createExerciseVariation(
                        parentId: parentId,
                        variationName: variationName,
                        implement: selectedImplement,
                        isSwappable: isSwappable,
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        _loadExercises(); // Refresh list to show new variation
                      }
                    }
                  },
                  child: const Text('Create', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _loadExercises() async {
    final data = await DatabaseHelper.instance.searchExercises(
      query: _searchController.text,
      implementFilter: _selectedImplement,
      muscleFilter: _selectedMuscle,
    );
    setState(() {
      _exercises = data;
    });
  }

  // --- NEW: The Dialog to Create Custom Exercises ---
  Future<void> _showCreateDialog() async {
    String newName = '';
    String newImplement = 'Dumbbell';
    String newMuscle = 'Chest';

    // We strip out the "All" option for creation, since an exercise must have a specific type
    final creationImplements = _implements.where((i) => i != 'All').toList();
    final creationMuscles = _muscles.where((m) => m != 'All').toList();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( // StatefulBuilder allows the dropdowns inside the dialog to update
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text('Create Custom Exercise'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Exercise Name',
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) => newName = val,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: newMuscle,
                    decoration: InputDecoration(
                      labelText: 'Primary Muscle',
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    items: creationMuscles.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (val) => setDialogState(() => newMuscle = val!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: newImplement,
                    decoration: InputDecoration(
                      labelText: 'Equipment',
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    items: creationImplements.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
                    onChanged: (val) => setDialogState(() => newImplement = val!),
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
                      // 1. Save to SQLite
                      await DatabaseHelper.instance.createCustomExercise(newName.trim(), newImplement, newMuscle);
                      // 2. Close Dialog
                      Navigator.pop(context);
                      // 3. Clear search and refresh the list to show the new exercise
                      _searchController.clear();
                      _selectedImplement = 'All';
                      _selectedMuscle = 'All';
                      _loadExercises();
                    }
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Library'),
        elevation: 0,
        actions: [
          // --- NEW: The Plus Button in the top right corner ---
          IconButton(
            icon: const Icon(Icons.add, color: Colors.teal),
            tooltip: 'Create Custom Exercise',
            onPressed: _showCreateDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search exercises...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[900],
              ),
              onChanged: (value) => _loadExercises(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedMuscle,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey[900],
                    ),
                    items: _muscles.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedMuscle = value);
                        _loadExercises();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedImplement,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey[900],
                    ),
                    items: _implements.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedImplement = value);
                        _loadExercises();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: _exercises.length,
              itemBuilder: (context, index) {
                final exercise = _exercises[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: Colors.grey[850],
                  child: ListTile(
                    title: Text(
                        exercise['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold)
                    ),
                    subtitle: Text(
                      '${exercise['muscle'] ?? 'General'} • ${exercise['implement'] ?? 'Any'}',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // --- NEW: Variation / Fork Icon ---
                        IconButton(
                          icon: const Icon(Icons.call_split, color: Colors.orangeAccent, size: 20),
                          tooltip: 'Create Variation',
                          onPressed: () => _showVariationDialog(exercise),
                        ),
                        // THE PLUS BUTTON: Returns the data to the active workout
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.teal),
                          onPressed: () {
                            Navigator.pop(context, exercise);
                          },
                        ),
                      ],
                    ),
                    // TAPPING THE TILE: Opens the Progression Graphs
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExerciseDetailsScreen(exercise: exercise),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}