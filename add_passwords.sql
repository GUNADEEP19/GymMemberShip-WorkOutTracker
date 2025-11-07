-- Migration: Add Password fields and Admin table for unified email/password login
-- Run this AFTER running GymMemberShip_WorkOutTracker.sql

USE GymMemberShip_WorkOutTracker;

-- Create Admin table
CREATE TABLE IF NOT EXISTS Admin (
  AdminId INT PRIMARY KEY AUTO_INCREMENT,
  Email VARCHAR(150) UNIQUE NOT NULL,
  Password VARCHAR(255) NOT NULL,
  Name VARCHAR(150) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Add Password column to Member table (if not exists)
ALTER TABLE Member 
  ADD COLUMN IF NOT EXISTS Password VARCHAR(255) NOT NULL DEFAULT 'member123';

-- Add Password column to Trainer table (if not exists)
ALTER TABLE Trainer 
  ADD COLUMN IF NOT EXISTS Password VARCHAR(255) NOT NULL DEFAULT 'trainer123';

-- Insert default admin user
INSERT IGNORE INTO Admin (Email, Password, Name) VALUES
('admin@gym.com', 'admin123', 'System Admin');

-- Update existing members with default password (if they don't have one)
UPDATE Member SET Password = 'member123' WHERE Password IS NULL OR Password = '';

-- Update existing trainers with default password (if they don't have one)
UPDATE Trainer SET Password = 'trainer123' WHERE Password IS NULL OR Password = '';

