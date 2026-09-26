BEGIN TRANSACTION;

-- 1. Ensure Dummy Exercises Exist (Ignores if they somehow already have these IDs)
INSERT OR IGNORE INTO Exercises (id, name, implement) VALUES (9991, 'Bench Press (Test)', 'Barbell');
INSERT OR IGNORE INTO Exercises (id, name, implement) VALUES (9992, 'Overhead Press (Test)', 'Barbell');
INSERT OR IGNORE INTO Exercises (id, name, implement) VALUES (9993, 'Deadlift (Test)', 'Barbell');

-- 2. Create the Program Template
INSERT INTO Programs (id, name, description)
VALUES (9999, 'Analytics Demo Program', 'A 4-cycle injected program to test progression charts.');

INSERT INTO Program_Weeks (id, program_id, week_name, order_index)
VALUES (9999, 9999, 'Week 1', 1);

-- Day 1: Push Day
INSERT INTO Program_Days (id, week_id, day_name, order_index)
VALUES (9998, 9999, 'Heavy Push', 1);

INSERT INTO Program_Day_Exercises (program_day_id, exercise_id, order_index, target_sets, target_reps)
VALUES (9998, 9991, 1, 3, '6-8');
INSERT INTO Program_Day_Exercises (program_day_id, exercise_id, order_index, target_sets, target_reps)
VALUES (9998, 9992, 2, 3, '8-10');

-- Day 2: Pull Day
INSERT INTO Program_Days (id, week_id, day_name, order_index)
VALUES (9999, 9999, 'Heavy Pull', 2);

INSERT INTO Program_Day_Exercises (program_day_id, exercise_id, order_index, target_sets, target_reps)
VALUES (9999, 9993, 1, 3, '5-5-5');


-- 3. Inject Historical Workouts (4 Cycles of Push Day progressing upwards)

-- CYCLE 1 (Oldest: Bench 60kg)
INSERT INTO Sessions (id, start_time, end_time, program_day_id)
VALUES (9901, '2026-08-01T10:00:00', '2026-08-01T11:00:00', 9998);

INSERT INTO Session_Exercises (id, session_id, exercise_id, order_number) VALUES (99011, 9901, 9991, 1);
INSERT INTO Sets (session_exercise_id, set_number, weight, reps) VALUES (99011, 1, 60, 8), (99011, 2, 60, 8), (99011, 3, 60, 7);

INSERT INTO Session_Exercises (id, session_id, exercise_id, order_number) VALUES (99012, 9901, 9992, 2);
INSERT INTO Sets (session_exercise_id, set_number, weight, reps) VALUES (99012, 1, 40, 10), (99012, 2, 40, 9), (99012, 3, 40, 8);


-- CYCLE 2 (Bench 65kg)
INSERT INTO Sessions (id, start_time, end_time, program_day_id)
VALUES (9902, '2026-08-08T10:00:00', '2026-08-08T11:00:00', 9998);

INSERT INTO Session_Exercises (id, session_id, exercise_id, order_number) VALUES (99021, 9902, 9991, 1);
INSERT INTO Sets (session_exercise_id, set_number, weight, reps) VALUES (99021, 1, 65, 8), (99021, 2, 65, 7), (99021, 3, 65, 6);

INSERT INTO Session_Exercises (id, session_id, exercise_id, order_number) VALUES (99022, 9902, 9992, 2);
INSERT INTO Sets (session_exercise_id, set_number, weight, reps) VALUES (99022, 1, 42.5, 9), (99022, 2, 42.5, 8), (99022, 3, 42.5, 8);


-- CYCLE 3 (Bench 67.5kg)
INSERT INTO Sessions (id, start_time, end_time, program_day_id)
VALUES (9903, '2026-08-15T10:00:00', '2026-08-15T11:00:00', 9998);

INSERT INTO Session_Exercises (id, session_id, exercise_id, order_number) VALUES (99031, 9903, 9991, 1);
INSERT INTO Sets (session_exercise_id, set_number, weight, reps) VALUES (99031, 1, 67.5, 7), (99031, 2, 67.5, 7), (99031, 3, 67.5, 6);

INSERT INTO Session_Exercises (id, session_id, exercise_id, order_number) VALUES (99032, 9903, 9992, 2);
INSERT INTO Sets (session_exercise_id, set_number, weight, reps) VALUES (99032, 1, 45, 8), (99032, 2, 45, 8), (99032, 3, 45, 7);


-- CYCLE 4 (Newest: Bench 70kg - Notice total reps dropped a bit to handle the heavier load)
INSERT INTO Sessions (id, start_time, end_time, program_day_id)
VALUES (9904, '2026-08-22T10:00:00', '2026-08-22T11:00:00', 9998);

INSERT INTO Session_Exercises (id, session_id, exercise_id, order_number) VALUES (99041, 9904, 9991, 1);
INSERT INTO Sets (session_exercise_id, set_number, weight, reps) VALUES (99041, 1, 70, 6), (99041, 2, 70, 6), (99041, 3, 70, 5);

INSERT INTO Session_Exercises (id, session_id, exercise_id, order_number) VALUES (99042, 9904, 9992, 2);
INSERT INTO Sets (session_exercise_id, set_number, weight, reps) VALUES (99042, 1, 47.5, 8), (99042, 2, 47.5, 7), (99042, 3, 47.5, 6);


-- 4. Inject 2 Cycles for Pull Day just so the other tab isn't empty
INSERT INTO Sessions (id, start_time, end_time, program_day_id) VALUES (9905, '2026-08-02T10:00:00', '2026-08-02T11:00:00', 9999);
INSERT INTO Session_Exercises (id, session_id, exercise_id, order_number) VALUES (99051, 9905, 9993, 1);
INSERT INTO Sets (session_exercise_id, set_number, weight, reps) VALUES (99051, 1, 100, 5), (99051, 2, 100, 5), (99051, 3, 100, 5);

INSERT INTO Sessions (id, start_time, end_time, program_day_id) VALUES (9906, '2026-08-09T10:00:00', '2026-08-09T11:00:00', 9999);
INSERT INTO Session_Exercises (id, session_id, exercise_id, order_number) VALUES (99061, 9906, 9993, 1);
INSERT INTO Sets (session_exercise_id, set_number, weight, reps) VALUES (99061, 1, 110, 5), (99061, 2, 110, 5), (99061, 3, 110, 4);

COMMIT;