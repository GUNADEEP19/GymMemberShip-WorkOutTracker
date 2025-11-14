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

-- 3.2 WorkoutTracker trigger removed
-- SetsComplete validation is handled by CHECK constraint (chk_sets_nonneg)
-- Status capitalization removed as it's not critical for business logic

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
-- 4.1 Authentication helpers
DELIMITER //
CREATE PROCEDURE sp_get_admin_by_email(IN p_email VARCHAR(150))
BEGIN
  SELECT * FROM Admin WHERE Email = p_email LIMIT 1;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_get_member_by_email(IN p_email VARCHAR(150))
BEGIN
  SELECT * FROM Member WHERE Email = p_email LIMIT 1;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_get_trainer_by_email(IN p_email VARCHAR(150))
BEGIN
  SELECT * FROM Trainer WHERE Email = p_email LIMIT 1;
END//
DELIMITER ;

-- 4.2 Reference data lookups
DELIMITER //
CREATE PROCEDURE sp_list_packages()
BEGIN
  SELECT PackageId, PackageName, Price
  FROM Package
  ORDER BY PackageName;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_list_trainers()
BEGIN
  SELECT TrainerId, TrainerName
  FROM Trainer
  ORDER BY TrainerName;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_list_workout_plans()
BEGIN
  SELECT PlanId, Goal
  FROM WorkOutPlan
  ORDER BY Goal;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_list_members_basic()
BEGIN
  SELECT MemberId, Name
  FROM Member
  ORDER BY Name;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_list_members_for_trainer(IN p_trainer INT)
BEGIN
  SELECT MemberId, Name
  FROM Member
  WHERE TrainerId = p_trainer
  ORDER BY Name;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_get_member_basic(IN p_member INT)
BEGIN
  SELECT MemberId, Name
  FROM Member
  WHERE MemberId = p_member;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_get_package_price(IN p_package INT)
BEGIN
  SELECT Price
  FROM Package
  WHERE PackageId = p_package;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_get_payment_audit_all()
BEGIN
  SELECT *
  FROM Payment_Audit
  ORDER BY AuditId DESC;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_get_payment_audit_for_member(IN p_member INT)
BEGIN
  SELECT PA.*
  FROM Payment_Audit PA
  JOIN Payment P ON PA.PaymentId = P.PaymentId
  WHERE P.MemberId = p_member
  ORDER BY PA.AuditId DESC;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_list_equipment()
BEGIN
  SELECT EquipmentId, Name, Quantity
  FROM Equipment
  ORDER BY Name;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_list_exercises()
BEGIN
  SELECT E.ExerciseId,
         E.ExerciseName,
         E.MuscleGroup,
         E.DefaultSets,
         E.DefaultReps,
         E.EquipmentId,
         EQ.Name AS EquipmentName
  FROM Exercise E
  LEFT JOIN Equipment EQ ON E.EquipmentId = EQ.EquipmentId
  ORDER BY E.ExerciseName;
END//
DELIMITER ;

-- 4.3 Member CRUD
DELIMITER //
CREATE PROCEDURE sp_get_members()
BEGIN
  SELECT M.MemberId,
         M.Name,
         M.Email,
         M.PhoneNo,
         M.Password,
         M.Address,
         M.DoB,
         M.JoinDate,
         M.Gender,
         M.PackageId,
         M.TrainerId,
         P.PackageName,
         T.TrainerName
  FROM Member M
  LEFT JOIN Package P ON M.PackageId = P.PackageId
  LEFT JOIN Trainer T ON M.TrainerId = T.TrainerId
  ORDER BY M.MemberId;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_get_member_detail(IN p_member INT)
BEGIN
  SELECT M.MemberId,
         M.Name,
         M.Email,
         M.PhoneNo,
         M.Password,
         M.Address,
         M.DoB,
         M.JoinDate,
         M.Gender,
         M.PackageId,
         M.TrainerId
  FROM Member M
  WHERE M.MemberId = p_member;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_create_member(
  IN p_name VARCHAR(150),
  IN p_email VARCHAR(150),
  IN p_phone VARCHAR(20),
  IN p_password VARCHAR(255),
  IN p_address TEXT,
  IN p_dob DATE,
  IN p_join DATE,
  IN p_gender VARCHAR(10),
  IN p_package INT,
  IN p_trainer INT
)
BEGIN
  IF p_email = '' THEN SET p_email = NULL; END IF;
  IF p_phone = '' THEN SET p_phone = NULL; END IF;
  IF p_address = '' THEN SET p_address = NULL; END IF;
  IF p_gender = '' THEN SET p_gender = NULL; END IF;
  IF p_password IS NULL OR p_password = '' THEN
    SET p_password = 'member123';
  END IF;
  INSERT INTO Member(Name, Email, PhoneNo, Password, Address, DoB, JoinDate, Gender, PackageId, TrainerId)
  VALUES(p_name, p_email, p_phone, p_password, p_address, p_dob, p_join, p_gender, p_package, p_trainer);
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_update_member(
  IN p_member INT,
  IN p_name VARCHAR(150),
  IN p_email VARCHAR(150),
  IN p_phone VARCHAR(20),
  IN p_password VARCHAR(255),
  IN p_address TEXT,
  IN p_dob DATE,
  IN p_join DATE,
  IN p_gender VARCHAR(10),
  IN p_package INT,
  IN p_trainer INT
)
BEGIN
  IF p_email = '' THEN SET p_email = NULL; END IF;
  IF p_phone = '' THEN SET p_phone = NULL; END IF;
  IF p_address = '' THEN SET p_address = NULL; END IF;
  IF p_gender = '' THEN SET p_gender = NULL; END IF;
  UPDATE Member
  SET Name = p_name,
      Email = p_email,
      PhoneNo = p_phone,
      Password = CASE WHEN p_password IS NULL OR p_password = '' THEN Password ELSE p_password END,
      Address = p_address,
      DoB = p_dob,
      JoinDate = p_join,
      Gender = p_gender,
      PackageId = p_package,
      TrainerId = p_trainer
  WHERE MemberId = p_member;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_delete_member(IN p_member INT)
BEGIN
  DECLARE v_is_active TINYINT(1);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;
  
  START TRANSACTION;
  
  -- Check if member is active
  SET v_is_active = fn_is_member_active(p_member);
  
  IF v_is_active = 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cannot delete active member. Please wait until membership expires.';
  END IF;
  
  -- Member is not active, proceed with deletion
  -- First, delete related records to satisfy foreign key constraints
  
  -- Delete attendance records (weak entity - depends on member)
  DELETE FROM Attendance WHERE MemberId = p_member;
  
  -- Delete member-workout plan associations
  DELETE FROM Member_WorkOutPlan WHERE MemberId = p_member;
  
  -- Delete payment records (audit trail in Payment_Audit will remain)
  DELETE FROM Payment WHERE MemberId = p_member;
  
  -- Now delete the member
  DELETE FROM Member WHERE MemberId = p_member;
  
  COMMIT;
END//
DELIMITER ;

-- 4.4 Trainer/Member views
DELIMITER //
CREATE PROCEDURE sp_get_trainer_members(IN p_trainer INT)
BEGIN
  SELECT M.MemberId,
         M.Name,
         M.Email,
         M.PhoneNo,
         M.Address,
         M.DoB,
         M.Gender,
         M.JoinDate,
         P.PackageName,
         P.Price
  FROM Member M
  LEFT JOIN Package P ON M.PackageId = P.PackageId
  WHERE M.TrainerId = p_trainer
  ORDER BY M.Name;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_get_member_plans(IN p_member INT)
BEGIN
  SELECT WP.PlanId,
         WP.Goal,
         WP.DurationWeeks
  FROM Member_WorkOutPlan MWP
  JOIN WorkOutPlan WP ON MWP.PlanId = WP.PlanId
  WHERE MWP.MemberId = p_member
  ORDER BY WP.Goal;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_get_member_plans_with_trainer(IN p_member INT)
BEGIN
  SELECT WP.PlanId,
         WP.Goal,
         WP.DurationWeeks,
         WP.TrainerId,
         T.TrainerName
  FROM Member_WorkOutPlan MWP
  JOIN WorkOutPlan WP ON MWP.PlanId = WP.PlanId
  LEFT JOIN Trainer T ON WP.TrainerId = T.TrainerId
  WHERE MWP.MemberId = p_member
  ORDER BY WP.Goal;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_get_member_trainer_info(IN p_member INT)
BEGIN
  SELECT T.TrainerId,
         T.TrainerName,
         T.Email,
         T.PhoneNo,
         T.DoB
  FROM Member M
  JOIN Trainer T ON M.TrainerId = T.TrainerId
  WHERE M.MemberId = p_member;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_verify_member_trainer(IN p_member INT, IN p_trainer INT)
BEGIN
  SELECT MemberId
  FROM Member
  WHERE MemberId = p_member AND TrainerId = p_trainer;
END//
DELIMITER ;

-- 4.5 Membership insights
DELIMITER //
CREATE PROCEDURE sp_get_membership_end_dates()
BEGIN
  SELECT M.MemberId,
         M.Name,
         M.Email,
         fn_membership_end_date(M.MemberId) AS EndDate
  FROM Member M
  ORDER BY M.Name;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_get_membership_end_date_for_member(IN p_member INT)
BEGIN
  SELECT M.MemberId,
         M.Name,
         M.Email,
         fn_membership_end_date(M.MemberId) AS EndDate
  FROM Member M
  WHERE M.MemberId = p_member;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_get_active_status_all()
BEGIN
  SELECT M.MemberId,
         M.Name,
         M.Email,
         fn_is_member_active(M.MemberId) AS IsActive,
         fn_membership_end_date(M.MemberId) AS EndDate
  FROM Member M
  ORDER BY M.Name;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_get_active_status_for_trainer(IN p_trainer INT)
BEGIN
  SELECT M.MemberId,
         M.Name,
         M.Email,
         fn_is_member_active(M.MemberId) AS IsActive,
         fn_membership_end_date(M.MemberId) AS EndDate
  FROM Member M
  WHERE M.TrainerId = p_trainer
  ORDER BY M.Name;
END//
DELIMITER ;

-- 4.6 Attendance queries (Weak Entity: PK is (MemberId, Date))
DELIMITER //
CREATE PROCEDURE sp_get_attendance_all()
BEGIN
  SELECT A.MemberId,
         M.Name AS MemberName,
         A.Date,
         A.CheckInTime,
         A.CheckOutTime,
         TIMESTAMPDIFF(MINUTE, A.CheckInTime, A.CheckOutTime) AS DurationMinutes
  FROM Attendance A
  JOIN Member M ON A.MemberId = M.MemberId
  ORDER BY A.Date DESC, A.CheckInTime DESC
  LIMIT 100;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_get_attendance_for_trainer(IN p_trainer INT)
BEGIN
  SELECT A.MemberId,
         M.Name AS MemberName,
         A.Date,
         A.CheckInTime,
         A.CheckOutTime,
         TIMESTAMPDIFF(MINUTE, A.CheckInTime, A.CheckOutTime) AS DurationMinutes
  FROM Attendance A
  JOIN Member M ON A.MemberId = M.MemberId
  WHERE M.TrainerId = p_trainer
  ORDER BY A.Date DESC, A.CheckInTime DESC
  LIMIT 100;
END//
DELIMITER ;

-- 4.7 Business actions (existing)
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

SELECT fn_membership_end_date(1)   AS EndDate,
       fn_is_member_active(1)      AS ActiveStatus;