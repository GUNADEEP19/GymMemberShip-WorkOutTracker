-- STEP 1 — USE DATABASE
USE GymMemberShip_WorkOutTracker;


-- STEP 2 — CREATE AUDIT TABLE
CREATE TABLE Payment_Audit (
  AuditId      BIGINT PRIMARY KEY AUTO_INCREMENT,
  PaymentId    INT,
  ActionType   ENUM('INSERT','UPDATE','DELETE'),
  OldAmount    DECIMAL(8,2),
  NewAmount    DECIMAL(8,2),
  OldMode      VARCHAR(50),
  NewMode      VARCHAR(50),
  OldTimeStamp DATETIME,
  NewTimeStamp DATETIME,
  OldMemberId  INT,
  NewMemberId  INT,
  OldPackageId INT,
  NewPackageId INT,
  ActionTS     DATETIME DEFAULT CURRENT_TIMESTAMP
);


-- STEP 3 — TRIGGERS
-- 3.1 Attendance trigger (no checkout before check-in)
DELIMITER //
CREATE TRIGGER trg_attendance_check_times
BEFORE INSERT ON Attendance
FOR EACH ROW
BEGIN
  IF NEW.CheckOutTime < NEW.CheckInTime THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Check-out time cannot be before check-in time';
  END IF;
END//
DELIMITER ;

-- 3.2 WorkoutTracker trigger (validate sets)
DELIMITER //
CREATE TRIGGER trg_workout_validate
BEFORE INSERT ON WorkOutTracker
FOR EACH ROW
BEGIN
  IF NEW.SetsComplete < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='SetsComplete cannot be negative';
  END IF;
  SET NEW.Status = CONCAT(UCASE(LEFT(NEW.Status,1)), LCASE(SUBSTRING(NEW.Status,2)));
END//
DELIMITER ;

-- 3.3 Payment trigger (auto-audit & validate)
DELIMITER //
CREATE TRIGGER trg_payment_audit
AFTER INSERT ON Payment
FOR EACH ROW
BEGIN
  DECLARE pkg_price DECIMAL(8,2);
  SELECT Price INTO pkg_price FROM Package WHERE PackageId=NEW.PackageId;
  IF NEW.Amount <> pkg_price THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Payment amount must match package price';
  END IF;

  INSERT INTO Payment_Audit(PaymentId,ActionType,NewAmount,NewMode,NewMemberId,NewPackageId)
  VALUES(NEW.PaymentId,'INSERT',NEW.Amount,NEW.Mode,NEW.MemberId,NEW.PackageId);
END//
DELIMITER ;


-- STEP 4 — STORED PROCEDURES
-- 4.1 Enroll a member to a workout plan
DELIMITER //
CREATE PROCEDURE sp_enroll_member_to_plan(IN p_member INT, IN p_plan INT)
BEGIN
  IF NOT EXISTS(SELECT 1 FROM Member_WorkOutPlan WHERE MemberId=p_member AND PlanId=p_plan) THEN
    INSERT INTO Member_WorkOutPlan(MemberId,PlanId) VALUES(p_member,p_plan);
  END IF;
END//
DELIMITER ;


-- 4.2 Log a workout entry
DELIMITER //
CREATE PROCEDURE sp_log_workout(
  IN p_member INT, IN p_plan INT, IN p_exercise INT,
  IN p_sets INT, IN p_notes TEXT, IN p_date DATE)
BEGIN
  INSERT INTO WorkOutTracker
  VALUES(
    (SELECT COALESCE(MAX(TrackerId),0)+1 FROM WorkOutTracker),
    p_date,'Completed',DAYNAME(p_date),WEEK(p_date,1),
    p_sets,p_notes,p_member,p_plan,p_exercise
  );
END//
DELIMITER ;


-- 4.3 Record attendance
DELIMITER //
CREATE PROCEDURE sp_record_attendance(
  IN p_member INT, IN p_date DATE,
  IN p_in TIME, IN p_out TIME)
BEGIN
  INSERT INTO Attendance
  VALUES(
    (SELECT COALESCE(MAX(AttendanceId),0)+1 FROM Attendance),
    p_member,p_date,p_in,p_out
  );
END//
DELIMITER ;


-- 4.4 Make a payment
DELIMITER //
CREATE PROCEDURE sp_make_payment(
  IN p_member INT, IN p_package INT, IN p_amount DECIMAL(8,2), IN p_mode VARCHAR(50))
BEGIN
  INSERT INTO Payment
  VALUES(
    (SELECT COALESCE(MAX(PaymentId),0)+1 FROM Payment),
    p_amount,p_mode,NOW(),p_member,p_package
  );
END//
DELIMITER ;


-- STEP 5 — STORED FUNCTIONS
-- 5.1 Get membership end date
DELIMITER //
CREATE FUNCTION fn_membership_end_date(p_member INT)
RETURNS DATE
READS SQL DATA
BEGIN
  DECLARE v_ts DATETIME; DECLARE v_weeks INT;
  SELECT p.TimeStamp, pkg.DurationWeeks
  INTO v_ts, v_weeks
  FROM Payment p JOIN Package pkg ON p.PackageId=pkg.PackageId
  WHERE p.MemberId=p_member ORDER BY p.TimeStamp DESC LIMIT 1;
  RETURN DATE_ADD(DATE(v_ts), INTERVAL v_weeks WEEK);
END//
DELIMITER ;


-- 5.2 Check if member is active
DELIMITER //
CREATE FUNCTION fn_is_member_active(p_member INT)
RETURNS TINYINT(1)
READS SQL DATA
BEGIN
  DECLARE v_end DATE;
  SET v_end = fn_membership_end_date(p_member);
  RETURN (v_end >= CURDATE());
END//
DELIMITER ;

-- 5.3 Count completed workouts
DELIMITER //
CREATE FUNCTION fn_total_workouts(p_member INT)
RETURNS INT
READS SQL DATA
BEGIN
  DECLARE v_cnt INT;
  SELECT COUNT(*) INTO v_cnt FROM WorkOutTracker
  WHERE MemberId=p_member AND Status='Completed';
  RETURN COALESCE(v_cnt,0);
END//
DELIMITER ;


-- STEP 6 — DEMONSTRATE
-- (A) Test triggers

-- valid attendance
CALL sp_record_attendance(1,'2025-05-06','07:00:00','08:00:00');

-- invalid attendance (should error)
-- CALL sp_record_attendance(1,'2025-05-06','08:00:00','07:00:00');



-- (B) Payment trigger + audit
-- valid
CALL sp_make_payment(1,2,1499.00,'Card');

-- invalid (mismatch amount, should error)
-- CALL sp_make_payment(1,2,1000.00,'Cash');

SELECT * FROM Payment_Audit;


-- (C) Procedure & Function demo
CALL sp_enroll_member_to_plan(1,1);
CALL sp_log_workout(1,1,2,3,'Proc inserted workout','2025-05-07');

SELECT fn_membership_end_date(1)   AS EndDate,
       fn_is_member_active(1)      AS ActiveStatus,
       fn_total_workouts(1)        AS TotalWorkouts;


