-- DBMS MINI-PROJECT — Automated Integrity & ACID Test Suite (non-destructive)
-- Run with: SOURCE /Users/chennupatigunadeep/Downloads/5TH SEM/DBMS/MINI-PROJECT/TESTS.sql;

USE GymMemberShip_WorkOutTracker;

DROP TABLE IF EXISTS TestResults;
CREATE TABLE TestResults (
  TestName   VARCHAR(100) PRIMARY KEY,
  Passed     TINYINT(1) NOT NULL,
  Details    VARCHAR(255) NULL,
  ExecutedAt DATETIME DEFAULT CURRENT_TIMESTAMP
);

DELIMITER //
DROP PROCEDURE IF EXISTS sp_run_db_tests //
CREATE PROCEDURE sp_run_db_tests()
BEGIN
  DECLARE v_payment_id INT;
  DECLARE v_last_audit_id BIGINT;
  DECLARE v_cnt INT;

  -- Helper to record a passed test
  INSERT IGNORE INTO TestResults(TestName, Passed, Details) VALUES('INIT', 1, 'Start');
  DELETE FROM TestResults WHERE TestName='INIT';

  -- Test 1: Payment validation rejects wrong amount (Atomicity/Consistency via trigger)
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
      ROLLBACK; 
      INSERT INTO TestResults VALUES('T1_Payment_Validate_WrongAmount', 1, 'Rejected as expected', NOW());
    END;
    START TRANSACTION;
    INSERT INTO Payment(Amount, Mode, TimeStamp, MemberId, PackageId)
    VALUES(123.45, 'Cash', NOW(), 1, 2);  -- should fail (package 2 = 1499.00)
    -- If we reached here, trigger failed to reject
    ROLLBACK;
    INSERT INTO TestResults VALUES('T1_Payment_Validate_WrongAmount', 0, 'Was not rejected', NOW());
  END;

  -- Test 2: Payment INSERT creates audit row
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; INSERT INTO TestResults VALUES('T2_Payment_Insert_Audit', 0, 'Insert failed unexpectedly', NOW()); END;
    START TRANSACTION;
    INSERT INTO Payment(Amount, Mode, TimeStamp, MemberId, PackageId)
    VALUES(1499.00, 'Card', NOW(), 1, 2);
    SET v_payment_id = LAST_INSERT_ID();
    SELECT COUNT(*) INTO v_cnt FROM Payment_Audit WHERE PaymentId=v_payment_id AND ActionType='INSERT';
    IF v_cnt = 1 THEN
      INSERT INTO TestResults VALUES('T2_Payment_Insert_Audit', 1, 'Audit row present', NOW());
    ELSE
      INSERT INTO TestResults VALUES('T2_Payment_Insert_Audit', 0, 'Missing audit row', NOW());
    END IF;
    ROLLBACK; -- non-destructive
  END;

  -- Test 3: Attendance one per day per member (unique key)
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; INSERT INTO TestResults VALUES('T3_Attendance_Unique_Per_Day', 1, 'Duplicate blocked', NOW()); END;
    START TRANSACTION;
    INSERT INTO Attendance(MemberId, Date, CheckInTime, CheckOutTime)
    VALUES(1, '2099-01-01', '07:00:00', '08:00:00');
    -- second insert same day should fail
    INSERT INTO Attendance(MemberId, Date, CheckInTime, CheckOutTime)
    VALUES(1, '2099-01-01', '09:00:00', '10:00:00');
    ROLLBACK;
    INSERT INTO TestResults VALUES('T3_Attendance_Unique_Per_Day', 0, 'Duplicate allowed', NOW());
  END;

  -- Test 4: CASCADE on WorkOutPlan -> Member_WorkOutPlan
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; INSERT INTO TestResults VALUES('T4_Cascade_Delete_Plan', 0, 'Setup failed', NOW()); END;
    START TRANSACTION;
    -- setup: new plan, map to member
    INSERT INTO WorkOutPlan(DurationWeeks, Goal, TrainerId) VALUES(1, 'Test Cascade', NULL);
    SET @plan_id = LAST_INSERT_ID();
    INSERT INTO Member_WorkOutPlan(MemberId, PlanId) VALUES(1, @plan_id);
    -- delete parent
    DELETE FROM WorkOutPlan WHERE PlanId=@plan_id;
    -- verify child gone
    SELECT COUNT(*) INTO v_cnt FROM Member_WorkOutPlan WHERE PlanId=@plan_id;
    IF v_cnt <> 0 THEN INSERT INTO TestResults VALUES('T4_Cascade_Delete_Plan', 0, 'Member_WorkOutPlan not cascaded', NOW()); ROLLBACK; LEAVE _t4; END IF;
    INSERT INTO TestResults VALUES('T4_Cascade_Delete_Plan', 1, 'Cascaded correctly', NOW());
    ROLLBACK;
  END;

  -- Test 5: RESTRICT delete Member with Payment should fail
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; INSERT INTO TestResults VALUES('T5_Restrict_Delete_Member_With_Payments', 1, 'Blocked as expected', NOW()); END;
    START TRANSACTION;
    -- ensure there is a payment for member 1 (seed has it)
    DELETE FROM Member WHERE MemberId=1; -- should fail
    ROLLBACK;
    INSERT INTO TestResults VALUES('T5_Restrict_Delete_Member_With_Payments', 0, 'Member was deleted (unexpected)', NOW());
  END;

  -- Test 6: fn_is_member_active returns 0 for member without payments
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; INSERT INTO TestResults VALUES('T6_Function_IsActive_NoPayments', 0, 'Setup failed', NOW()); END;
    START TRANSACTION;
    INSERT INTO Member(Name, Email, PhoneNo, JoinDate, Gender, PackageId, TrainerId)
    VALUES('Temp Member', CONCAT('temp', UUID()), CONCAT('900', FLOOR(RAND()*10000000)), CURDATE(), 'M', NULL, NULL);
    SET @tmp_member = LAST_INSERT_ID();
    SELECT fn_is_member_active(@tmp_member) INTO v_cnt;
    IF v_cnt = 0 THEN
      INSERT INTO TestResults VALUES('T6_Function_IsActive_NoPayments', 1, 'Returned 0 as expected', NOW());
    ELSE
      INSERT INTO TestResults VALUES('T6_Function_IsActive_NoPayments', 0, 'Returned non-zero', NOW());
    END IF;
    ROLLBACK;
  END;
END //
DELIMITER ;

CALL sp_run_db_tests();
SELECT * FROM TestResults ORDER BY TestName;


