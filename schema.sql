CREATE TABLE Muscle_Groups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE Exercises (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    implement TEXT NOT NULL -- e.g., 'Barbell', 'Dumbbell', 'Machine', 'Bodyweight'
);

CREATE TABLE Exercise_Muscles (
    exercise_id INTEGER,
    muscle_id INTEGER,
    is_primary INTEGER NOT NULL CHECK (is_primary IN (0, 1)),
    PRIMARY KEY (exercise_id, muscle_id),
    FOREIGN KEY (exercise_id) REFERENCES Exercises(id) ON DELETE CASCADE,
    FOREIGN KEY (muscle_id) REFERENCES Muscle_Groups(id) ON DELETE CASCADE
);

CREATE TABLE Sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    start_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    end_time DATETIME,
    notes TEXT
);

CREATE TABLE Session_Exercises (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER,
    exercise_id INTEGER,
    order_number INTEGER NOT NULL,
    FOREIGN KEY (session_id) REFERENCES Sessions(id) ON DELETE CASCADE,
    FOREIGN KEY (exercise_id) REFERENCES Exercises(id) ON DELETE CASCADE
);

CREATE TABLE Sets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_exercise_id INTEGER,
    set_number INTEGER NOT NULL,
    weight REAL NOT NULL,
    reps INTEGER NOT NULL,
    FOREIGN KEY (session_exercise_id) REFERENCES Session_Exercises(id) ON DELETE CASCADE
);
