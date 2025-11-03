CREATE DATABASE IF NOT EXISTS GymMemberShip_WorkOutTracker
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE GymMemberShip_WorkOutTracker;

CREATE TABLE Package (
  PackageId INT PRIMARY KEY,
  PackageName VARCHAR(100) NOT NULL,
  Price DECIMAL(8,2) NOT NULL,
  DurationWeeks INT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE Trainer (
  TrainerId INT PRIMARY KEY,
  TrainerName VARCHAR(100) NOT NULL,
  DoB DATE,
  PhoneNo VARCHAR(20),
  Email VARCHAR(150)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE Equipment (
  EquipmentId INT PRIMARY KEY,
  Name VARCHAR(100) NOT NULL,
  Quantity INT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE Exercise (
  ExerciseId INT PRIMARY KEY,
  ExerciseName VARCHAR(100) NOT NULL,
  MuscleGroup VARCHAR(100),
  DefaultSets INT,
  DefaultReps INT,
  EquipmentId INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE Member (
  MemberId INT PRIMARY KEY,
  Name VARCHAR(150) NOT NULL,
  Email VARCHAR(150),
  PhoneNo VARCHAR(20),
  Address TEXT,
  DoB DATE,
  JoinDate DATE,
  Gender ENUM('M','F','Other'),
  PackageId INT,
  TrainerId INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE WorkOutPlan (
  PlanId INT PRIMARY KEY,
  DurationWeeks INT,
  Goal VARCHAR(255),
  TrainerId INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE Member_WorkOutPlan (
  MemberId INT,
  PlanId INT,
  PRIMARY KEY (MemberId, PlanId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE WorkOutTracker (
  TrackerId INT PRIMARY KEY,
  DateLogged DATE,
  Status VARCHAR(50),
  Day VARCHAR(20),
  WeekNumber INT,
  SetsComplete INT,
  Notes TEXT,
  MemberId INT,
  PlanId INT,
  ExerciseId INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE Attendance (
  AttendanceId INT PRIMARY KEY,
  MemberId INT,
  Date DATE,
  CheckInTime TIME,
  CheckOutTime TIME
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE Payment (
  PaymentId INT PRIMARY KEY,
  Amount DECIMAL(8,2),
  Mode VARCHAR(50),
  TimeStamp DATETIME,
  MemberId INT,
  PackageId INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


ALTER TABLE Exercise
  ADD CONSTRAINT fk_exercise_equipment
  FOREIGN KEY (EquipmentId) REFERENCES Equipment(EquipmentId);

ALTER TABLE Member
  ADD CONSTRAINT fk_member_package FOREIGN KEY (PackageId) REFERENCES Package(PackageId),
  ADD CONSTRAINT fk_member_trainer FOREIGN KEY (TrainerId) REFERENCES Trainer(TrainerId);

ALTER TABLE WorkOutPlan
  ADD CONSTRAINT fk_plan_trainer FOREIGN KEY (TrainerId) REFERENCES Trainer(TrainerId);

ALTER TABLE Member_WorkOutPlan
  ADD CONSTRAINT fk_mw_member FOREIGN KEY (MemberId) REFERENCES Member(MemberId),
  ADD CONSTRAINT fk_mw_plan FOREIGN KEY (PlanId) REFERENCES WorkOutPlan(PlanId);

ALTER TABLE WorkOutTracker
  ADD CONSTRAINT fk_tracker_member FOREIGN KEY (MemberId) REFERENCES Member(MemberId),
  ADD CONSTRAINT fk_tracker_plan FOREIGN KEY (PlanId) REFERENCES WorkOutPlan(PlanId),
  ADD CONSTRAINT fk_tracker_exercise FOREIGN KEY (ExerciseId) REFERENCES Exercise(ExerciseId);

ALTER TABLE Attendance
  ADD CONSTRAINT fk_att_member FOREIGN KEY (MemberId) REFERENCES Member(MemberId);

ALTER TABLE Payment
  ADD CONSTRAINT fk_payment_member FOREIGN KEY (MemberId) REFERENCES Member(MemberId),
  ADD CONSTRAINT fk_payment_package FOREIGN KEY (PackageId) REFERENCES Package(PackageId);


-- Packages
INSERT INTO Package VALUES
(1, 'Starter', 499.00, 4),
(2, 'Monthly', 1499.00, 4),
(3, 'Quarterly', 3999.00, 12),
(4, 'HalfYear', 6999.00, 24),
(5, 'Yearly', 11999.00, 52);

-- Trainers
INSERT INTO Trainer VALUES
(1, 'Rajesh Kumar', '1990-03-15', '9876543210', 'rajesh@example.com'),
(2, 'Anita Sharma', '1988-07-22', '9123456780', 'anita@example.com'),
(3, 'Vikram Singh', '1992-11-02', '9988776655', 'vikram@example.com'),
(4, 'Meera Patel', '1991-01-10', '9001122334', 'meera@example.com'),
(5, 'Suresh Rao', '1985-05-05', '9445566778', 'suresh@example.com');

-- Equipment
INSERT INTO Equipment VALUES
(1, 'Treadmill', 5),
(2, 'Dumbbell Set', 12),
(3, 'Barbell', 4),
(4, 'Stationary Bike', 3),
(5, 'Kettlebell Set', 6);

-- Exercise
INSERT INTO Exercise VALUES
(1, 'Treadmill Run', 'Cardio', 1, 30, 1),
(2, 'Dumbbell Curl', 'Biceps', 3, 12, 2),
(3, 'Barbell Squat', 'Legs', 4, 8, 3),
(4, 'Cycling', 'Cardio', 1, 25, 4),
(5, 'Kettlebell Swing', 'Full Body', 3, 15, 5);

-- Members
INSERT INTO Member VALUES
(1, 'Amit Sharma', 'amit.sharma@example.com', '9000000001', 'No.1, MG Road', '1998-04-12', '2025-01-15', 'M', 2, 1),
(2, 'Priya Rao', 'priya.rao@example.com', '9000000002', 'No.2, Park Street', '1997-09-20', '2025-02-01', 'F', 3, 2),
(3, 'Karan Verma', 'karan.verma@example.com', '9000000003', 'No.3, Lake View', '1995-12-05', '2025-03-10', 'M', 1, 3),
(4, 'Sneha Gupta', 'sneha.gupta@example.com', '9000000004', 'No.4, Hill Road', '2000-06-18', '2025-04-05', 'F', 5, 4),
(5, 'Rahul Patel', 'rahul.patel@example.com', '9000000005', 'No.5, Market Lane', '1994-02-28', '2025-04-20', 'M', 4, 5);

-- WorkOutPlan
INSERT INTO WorkOutPlan VALUES
(1, 8, 'Fat Loss and Cardio', 1),
(2, 12, 'Muscle Gain - Upper Body', 2),
(3, 16, 'Strength - Full Body', 3),
(4, 6, 'Beginner Conditioning', 4),
(5, 24, 'Endurance & Mobility', 5);

-- Member_WorkOutPlan
INSERT INTO Member_WorkOutPlan VALUES
(1, 1),
(2, 2),
(3, 3),
(4, 5),
(5, 4);

-- WorkOutTracker
INSERT INTO WorkOutTracker VALUES
(1, '2025-05-01', 'Completed', 'Monday', 1, 4, 'Good session', 1, 1, 1),
(2, '2025-05-02', 'Completed', 'Tuesday', 1, 3, 'Felt strong', 2, 2, 2),
(3, '2025-05-03', 'Skipped',   'Wednesday', 1, 0, 'Felt sick', 3, 3, 3),
(4, '2025-05-04', 'Completed', 'Thursday', 1, 2, 'Light cardio', 4, 5, 4),
(5, '2025-05-05', 'Completed', 'Friday', 1, 3, 'Good form', 5, 4, 5);

-- Attendance
INSERT INTO Attendance VALUES
(1, 1, '2025-05-01', '07:30:00', '08:30:00'),
(2, 2, '2025-05-02', '18:00:00', '19:15:00'),
(3, 3, '2025-05-03', '06:45:00', '07:30:00'),
(4, 4, '2025-05-04', '17:20:00', '18:05:00'),
(5, 5, '2025-05-05', '07:00:00', '07:45:00');

-- Payment
INSERT INTO Payment VALUES
(1, 1499.00, 'Card', '2025-01-15 10:15:00', 1, 2),
(2, 3999.00, 'Cash', '2025-02-01 14:45:00', 2, 3),
(3, 499.00,  'UPI',  '2025-03-10 09:00:00', 3, 1),
(4, 11999.00,'Card', '2025-04-05 16:30:00', 4, 5),
(5, 6999.00, 'UPI',  '2025-04-20 11:20:00', 5, 4);


DESC Package;

DESC Trainer;

DESC Equipment;

DESC Exercise;

DESC Member;

DESC WorkOutPlan;

DESC Member_WorkOutPlan;

DESC WorkOutTracker;

DESC Attendance;

DESC Payment;


