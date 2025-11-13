-- STEP 1 — USE DATABASE
-- ACID Compliance Notes:
-- ATOMICITY: All procedures use START TRANSACTION/COMMIT with error handlers
--            AUTO_INCREMENT used instead of MAX()+1 (prevents race conditions)
-- CONSISTENCY: Foreign keys, CHECK constraints, UNIQUE constraints, triggers validate data
-- ISOLATION: InnoDB default isolation level (REPEATABLE READ) ensures transaction isolation
-- DURABILITY: InnoDB engine with transaction logs ensures committed changes persist

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
-- 3.1 Attendance triggers (validate times on INSERT and UPDATE)
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

-- 3.1b Attendance UPDATE trigger
DELIMITER //
CREATE TRIGGER trg_attendance_check_times_upd
BEFORE UPDATE ON Attendance
FOR EACH ROW
BEGIN
  IF NEW.CheckOutTime < NEW.CheckInTime THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Check-out time cannot be before check-in time';
  END IF;
END//
DELIMITER ;

-- 3.2 WorkoutTracker trigger (validate sets on INSERT and UPDATE)
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

-- 3.2b WorkoutTracker UPDATE trigger (validate sets on update)
DELIMITER //
CREATE TRIGGER trg_workout_validate_upd
BEFORE UPDATE ON WorkOutTracker
FOR EACH ROW
BEGIN
  IF NEW.SetsComplete < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='SetsComplete cannot be negative';
  END IF;
  SET NEW.Status = CONCAT(UCASE(LEFT(NEW.Status,1)), LCASE(SUBSTRING(NEW.Status,2)));
END//
DELIMITER ;

-- 3.3 Payment trigger (validate before insert, audit after)
-- Validation trigger (BEFORE INSERT to prevent invalid data)
DELIMITER //
CREATE TRIGGER trg_payment_validate
BEFORE INSERT ON Payment
FOR EACH ROW
BEGIN
  DECLARE pkg_price DECIMAL(8,2);
  SELECT Price INTO pkg_price FROM Package WHERE PackageId=NEW.PackageId;
  IF pkg_price IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Package does not exist';
  END IF;
  IF NEW.Amount <> pkg_price THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Payment amount must match package price';
  END IF;
END//
DELIMITER ;

-- Audit trigger (AFTER INSERT to log successful insertions)
DELIMITER //
CREATE TRIGGER trg_payment_audit
AFTER INSERT ON Payment
FOR EACH ROW
BEGIN
  INSERT INTO Payment_Audit(PaymentId,ActionType,NewAmount,NewMode,NewMemberId,NewPackageId)
  VALUES(NEW.PaymentId,'INSERT',NEW.Amount,NEW.Mode,NEW.MemberId,NEW.PackageId);
END//
DELIMITER ;

-- 3.4 Payment UPDATE validation (validate before update)
DELIMITER //
CREATE TRIGGER trg_payment_validate_upd
BEFORE UPDATE ON Payment
FOR EACH ROW
BEGIN
  DECLARE pkg_price DECIMAL(8,2);
  -- If amount or package changed, validate amount matches package price
  IF NEW.Amount <> OLD.Amount OR NEW.PackageId <> OLD.PackageId THEN
    SELECT Price INTO pkg_price FROM Package WHERE PackageId=NEW.PackageId;
    IF pkg_price IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Package does not exist';
    END IF;
    IF NEW.Amount <> pkg_price THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Payment amount must match package price';
    END IF;
  END IF;
END//
DELIMITER ;

-- 3.5 Payment UPDATE audit (captures before/after values)
DELIMITER //
CREATE TRIGGER trg_payment_audit_upd
AFTER UPDATE ON Payment
FOR EACH ROW
BEGIN
  INSERT INTO Payment_Audit(
    PaymentId,ActionType,
    OldAmount,NewAmount,
    OldMode,NewMode,
    OldTimeStamp,NewTimeStamp,
    OldMemberId,NewMemberId,
    OldPackageId,NewPackageId
  )
  VALUES(
    OLD.PaymentId,'UPDATE',
    OLD.Amount,NEW.Amount,
    OLD.Mode,NEW.Mode,
    OLD.TimeStamp,NEW.TimeStamp,
    OLD.MemberId,NEW.MemberId,
    OLD.PackageId,NEW.PackageId
  );
END//
DELIMITER ;

-- 3.6 Payment DELETE audit (stores the removed row)
DELIMITER //
CREATE TRIGGER trg_payment_audit_del
AFTER DELETE ON Payment
FOR EACH ROW
BEGIN
  INSERT INTO Payment_Audit(
    PaymentId,ActionType,
    OldAmount,OldMode,OldTimeStamp,OldMemberId,OldPackageId
  )
  VALUES(
    OLD.PaymentId,'DELETE',
    OLD.Amount,OLD.Mode,OLD.TimeStamp,OLD.MemberId,OLD.PackageId
  );
END//
DELIMITER ;


-- STEP 4 — STORED PROCEDURES
-- 4.1 Enroll a member to a workout plan (atomic operation)
DELIMITER //
CREATE PROCEDURE sp_enroll_member_to_plan(IN p_member INT, IN p_plan INT)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;
  
  START TRANSACTION;
  IF NOT EXISTS(SELECT 1 FROM Member_WorkOutPlan WHERE MemberId=p_member AND PlanId=p_plan) THEN
    INSERT INTO Member_WorkOutPlan(MemberId,PlanId) VALUES(p_member,p_plan);
  END IF;
  COMMIT;
END//
DELIMITER ;


-- 4.2 Log a workout entry (atomic, uses AUTO_INCREMENT)
DELIMITER //
CREATE PROCEDURE sp_log_workout(
  IN p_member INT, IN p_plan INT, IN p_exercise INT,
  IN p_sets INT, IN p_notes TEXT, IN p_date DATE)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;
  
  START TRANSACTION;
  INSERT INTO WorkOutTracker(
    DateLogged, Status, Day, WeekNumber, SetsComplete, Notes,
    MemberId, PlanId, ExerciseId
  )
  VALUES(
    p_date, 'Completed', DAYNAME(p_date), WEEK(p_date,1),
    p_sets, p_notes, p_member, p_plan, p_exercise
  );
  COMMIT;
END//
DELIMITER ;


-- 4.3 Record attendance (atomic, uses AUTO_INCREMENT)
DELIMITER //
CREATE PROCEDURE sp_record_attendance(
  IN p_member INT, IN p_date DATE,
  IN p_in TIME, IN p_out TIME)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;
  
  START TRANSACTION;
  INSERT INTO Attendance(MemberId, Date, CheckInTime, CheckOutTime)
  VALUES(p_member, p_date, p_in, p_out);
  COMMIT;
END//
DELIMITER ;


-- 4.4 Make a payment (atomic, uses AUTO_INCREMENT, triggers handle validation & audit)
DELIMITER //
CREATE PROCEDURE sp_make_payment(
  IN p_member INT, IN p_package INT, IN p_amount DECIMAL(8,2), IN p_mode VARCHAR(50))
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;
  
  START TRANSACTION;
  INSERT INTO Payment(Amount, Mode, TimeStamp, MemberId, PackageId)
  VALUES(p_amount, p_mode, NOW(), p_member, p_package);
  -- Trigger validates amount and creates audit entry atomically
  COMMIT;
END//
DELIMITER ;


-- STEP 5 — STORED FUNCTIONS
-- 5.1 Get membership end date (returns NULL if member has no payments)
DELIMITER //
CREATE FUNCTION fn_membership_end_date(p_member INT)
RETURNS DATE
READS SQL DATA
BEGIN
  DECLARE v_ts DATETIME; 
  DECLARE v_weeks INT;
  DECLARE v_result DATE;
  
  SELECT p.TimeStamp, pkg.DurationWeeks
  INTO v_ts, v_weeks
  FROM Payment p JOIN Package pkg ON p.PackageId=pkg.PackageId
  WHERE p.MemberId=p_member ORDER BY p.TimeStamp DESC LIMIT 1;
  
  IF v_ts IS NULL OR v_weeks IS NULL THEN
    RETURN NULL;
  END IF;
  
  SET v_result = DATE_ADD(DATE(v_ts), INTERVAL v_weeks WEEK);
  RETURN v_result;
END//
DELIMITER ;


-- 5.2 Check if member is active (returns 0 if no membership or expired)
DELIMITER //
CREATE FUNCTION fn_is_member_active(p_member INT)
RETURNS TINYINT(1)
READS SQL DATA
BEGIN
  DECLARE v_end DATE;
  SET v_end = fn_membership_end_date(p_member);
  
  IF v_end IS NULL THEN
    RETURN 0;  -- No payment record means inactive
  END IF;
  
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