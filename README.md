# Gym Membership & Workout Tracker

A comprehensive database-driven web application for managing gym operations, including members, trainers, workout plans, attendance, and payments. Built with Flask (Python) and MySQL.

## Features

- **Role-based Access Control**: Admin, Member, and Trainer roles with different permissions
- **Unified Login System**: Single login page for all user types (Admin, Member, Trainer)
- **CRUD Operations**: Full Create, Read, Update, Delete for Member management (Admin)
- **Database Triggers**: Automatic validation and audit logging for payments
- **Stored Procedures & Functions**: Business logic encapsulated in database routines
  - `sp_enroll_member_to_plan`: Enroll members to workout plans
  - `sp_make_payment`: Process payments with automatic audit
  - `sp_record_attendance` ⁠: Track member attendance
  - `fn_membership_end_date`: Calculate membership expiration
  - `fn_is_member_active`: Check member active status
- **MySQL Console**: Admin can execute SQL queries directly from the UI
- **Payment Management**: 
  - Members can make payments and view their own payment history
  - Admin can process payments for any member
  - Automatic amount calculation from package selection
- **Member-Trainer Assignment**:
  - Trainers can view their assigned members with contact details and plans
  - Members can view their assigned trainer and workout plans
- **Enrollment System**: Trainers can enroll only their assigned members to workout plans
- **Attendance Management**:
  - Trainers can mark attendance only for their assigned members
  - Admin can mark attendance for all members
  - Automatic time validation (check-out must be after check-in)
  - View attendance records with member details and duration
- **ACID Compliance**: All database operations use transactions for data integrity

## Prerequisites

- **Python 3.8+**
- **MySQL 8.0+** (with MySQL server running)
- **pip** (Python package manager)

## Installation

### Step 1: Clone/Download the Project

```bash
cd "/path/to/MINI-PROJECT"
```

### Step 2: Create Virtual Environment

**macOS/Linux:**
```bash
python3 -m venv .venv
source .venv/bin/activate
```

**Windows:**
```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

### Step 3: Install Dependencies

```bash
pip install --upgrade pip
pip install -r requirements.txt
```

## Database Setup

### Step 1: Start MySQL Server

Ensure MySQL is running:
```bash
# Check status
mysql -u root -p -e "SELECT 1;"

# If not running, start it (macOS with Homebrew)
brew services start mysql

# On Linux (systemd)
sudo systemctl start mysql

# On Windows
# Start MySQL service from Services panel
```

### Step 2: Create Database and Tables

Open MySQL console:
```bash
mysql -u root -p
```

Run the SQL files in order:
```sql
SOURCE GymMemberShip_WorkOutTracker.sql;
SOURCE REVIEW-3.sql;
```

**Note:** Make sure you're in the correct directory or provide full paths:
```sql
SOURCE /full/path/to/GymMemberShip_WorkOutTracker.sql;
SOURCE /full/path/to/REVIEW-3.sql;
```

Verify setup:
```sql
USE GymMemberShip_WorkOutTracker;
SHOW TABLES;
SELECT COUNT(*) FROM Trainer;
SELECT COUNT(*) FROM Member;
SELECT COUNT(*) FROM Admin;
EXIT;
```

You should see 11 tables and counts for Trainer, Member, and Admin.

## Configuration

### Step 1: Create `.env` File

Copy the example file:
```bash
cp env.example .env
```

### Step 2: Edit `.env` File

Open `.env` and update with your MySQL credentials:

```env
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_mysql_password
DB_NAME=GymMemberShip_WorkOutTracker
FLASK_SECRET=dev
PORT=3000
```

**Important:** 
- Replace `your_mysql_password` with your actual MySQL root password (the one you use with `mysql -u root -p`)
- Ensure there are no extra spaces in the password
- The password length will be displayed when you run the app for verification

## Running the Application

### Start the Flask Server

```bash
python app.py
```

You should see:
```
DB_HOST: localhost
DB_USER: root
DB_PASSWORD: ******** (length: 8)
DB_NAME: GymMemberShip_WorkOutTracker
 * Running on http://0.0.0.0:3000
```

### Access the Application

Open your browser and navigate to:
- **Local:** http://localhost:3000
- **Network:** http://YOUR_IP:3000 (replace YOUR_IP with your machine's IP address)

You'll be redirected to the login page.

## Login Credentials

### Admin
- **Email:** `admin@gym.com`
- **Password:** `admin123`
- **Access:** 
  - Full member CRUD operations
  - Process payments for any member
  - Enroll members to plans
  - Mark attendance for all members
  - View attendance for all members
  - View membership end dates for all members
  - View active status for all members
  - MySQL console for direct SQL queries
  - View all payment audit trails

### Member
- **Email:** `amit.sharma@example.com`
- **Password:** `member123`
- **Access:**
  - Make payments (only for themselves)
  - View own payment history
  - View assigned trainer details
  - View assigned workout plans
  - View own membership end date

### Trainer
- **Email:** `rajesh@example.com`
- **Password:** `trainer123`
- **Access:**
  - View assigned members with contact details
  - View members' assigned workout plans
  - Enroll only assigned members to workout plans
  - Mark attendance for assigned members
  - View attendance records for assigned members
  - View active status for assigned members

**Note:** Additional members and trainers are available in the seed data. Check the database for their emails:
- Members: `priya.rao@example.com`, `karan.verma@example.com`, etc.
- Trainers: `anita@example.com`, `vikram@example.com`, etc.

## Project Structure

```
MINI-PROJECT/
├── app.py                          # Main Flask application
├── requirements.txt                 # Python dependencies
├── .env                            # Environment variables (create from env.example)
├── env.example                     # Environment variables template
├── .gitignore                      # Git ignore rules
├── GymMemberShip_WorkOutTracker.sql  # Database schema and seed data
├── REVIEW-3.sql                    # Triggers, procedures, and functions
├── templates/                      # HTML templates
│   ├── base.html                   # Base template with Bootstrap navigation
│   ├── dashboard.html              # Role-based dashboard
│   ├── index.html                  # Home page
│   ├── auth/
│   │   └── login.html             # Unified login page
│   ├── members/                    # Member CRUD pages
│   │   ├── list.html              # List all members
│   │   ├── create.html            # Create new member
│   │   └── edit.html              # Edit member
│   ├── actions/                    # Procedures/functions GUI
│   │   ├── enroll.html            # Enroll member to plan
│   │   ├── make_payment.html      # Make payment
│   │   └── mark_attendance.html   # Mark attendance
│   ├── trainer/                    # Trainer-specific pages
│   │   └── members.html           # View assigned members
│   ├── member/                     # Member-specific pages
│   │   └── my_trainer.html         # View assigned trainer & plans
│   ├── attendance/                 # Attendance pages
│   │   └── view.html              # View attendance records
│   ├── membership/                 # Membership function pages
│   │   ├── end_date.html          # View membership end dates
│   │   └── active_status.html     # View member active status
│   ├── queries/                    # Query dashboard (if needed)
│   │   └── index.html
│   └── admin/                      # Admin-only pages
│       └── mysql_console.html     # SQL query console
└── README.md                       # This file
```

## Database Schema

### Tables (11 total)
1. **Admin** - System administrators with email/password authentication
2. **Package** - Membership packages with pricing and duration
3. **Trainer** - Gym trainers/staff with contact information
4. **Equipment** - Gym equipment inventory
5. **Exercise** - Exercise library with muscle groups and equipment
6. **Member** - Gym members with personal and contact details
7. **WorkOutPlan** - Workout programs created by trainers
8. **Member_WorkOutPlan** - Junction table for member-plan assignments
9. **WorkOutTracker** - Daily workout logs and progress
10. **Attendance** - Member attendance records with check-in/out times
11. **Payment** - Payment transactions (audited via triggers)
12. **Payment_Audit** - Audit trail for all payment operations

### Key Features
- **Foreign Keys:** Proper referential integrity with CASCADE/RESTRICT/SET NULL actions
- **Constraints:** 
  - UNIQUE constraints on email and phone for Member and Trainer
  - CHECK constraints for positive prices, durations, and quantities
  - UNIQUE constraint on (MemberId, Date) for Attendance
- **Triggers:** 
  - Payment validation (amount must match package price)
  - Payment audit logging (INSERT, UPDATE, DELETE)
  - Attendance time validation
  - Workout sets validation
- **Procedures:** 
  - `sp_enroll_member_to_plan`: Enroll member to workout plan
  - `sp_make_payment`: Process payment with validation
  - `sp_record_attendance`: Record member attendance
- **Functions:** 
  - `fn_membership_end_date`: Calculate membership end date
  - `fn_is_member_active`: Check if member has active membership
- **Indexes:** Optimized indexes on frequently queried columns

## Technologies Used

- **Backend:** Flask 3.0.0 (Python)
- **Database:** MySQL 8.0+ (via PyMySQL 1.1.0)
- **Frontend:** HTML5, Bootstrap 5.3.8
- **Authentication:** Session-based with role management
- **Environment Management:** python-dotenv 1.0.1
- **Security:** cryptography 41.0.7 (for MySQL 8.0+ authentication)

## Role-Based Access Control

### Admin
- Full access to all features
- Member CRUD operations
- Process payments for any member
- Enroll any member to any plan
- Mark attendance for all members
- View attendance for all members
- View membership end dates for all members
- View active status for all members
- MySQL console for direct SQL execution
- View all payment audit trails

### Member
- Make payments (only for themselves)
- View own payment history
- View assigned trainer information
- View assigned workout plans
- View own membership end date

### Trainer
- View assigned members with contact details
- View members' assigned workout plans
- Enroll only assigned members to workout plans
- Mark attendance only for assigned members
- View attendance records for assigned members
- View active status for assigned members

## Key Functionality

### Payment System
- **Automatic Amount Calculation**: Amount is automatically fetched from selected package
- **Payment Modes**: Card, Cash, UPI, Net Banking, Wallet
- **Audit Trail**: All payment operations are logged with timestamps
- **Member Restriction**: Members can only make payments for themselves

### Enrollment System
- **Trainer Restriction**: Trainers can only enroll their assigned members
- **Plan Selection**: Dropdown selection for available workout plans
- **Member Selection**: Filtered based on role (trainer sees only assigned members)

### Member-Trainer Relationship
- **Trainer View**: See all assigned members with full contact details and their plans
- **Member View**: See assigned trainer details and all assigned workout plans

### Attendance System
- **Time Validation**: Automatic validation ensures check-out time is after check-in time (enforced by database triggers)
- **Role-Based Access**:
  - Trainers can mark/view attendance only for members assigned to them
  - Admin can mark/view attendance for all members
- **Stored Procedure**: Uses `sp_record_attendance` for atomic attendance recording
- **View Records**: Display attendance with member names, dates, times, and calculated duration

### Membership Functions
- **End Date Calculation** (`fn_membership_end_date`):
  - Calculates membership expiration date based on last payment and package duration
  - Returns NULL if member has no payment records
  - Admin can view end dates for all members
  - Members can view only their own end date
  - Displays active/expired status based on current date
- **Active Status Check** (`fn_is_member_active`):
  - Checks if member has an active membership (end date >= today)
  - Returns 1 for active, 0 for inactive or no membership
  - Admin can view active status for all members
  - Trainers can view active status for assigned members only
  - Displays membership end date alongside status

## Troubleshooting

### "Access denied for user 'root'@'localhost'"
- Check `.env` file has correct MySQL password
- Verify password length matches (no extra spaces at the end)
- Test password manually: `mysql -u root -p`
- Check the debug output when running `app.py` - it shows password length

### "cryptography package is required"
- Install: `pip install cryptography`
- Or reinstall all dependencies: `pip install -r requirements.txt`

### "Database error" on login
- Ensure MySQL server is running
- Verify database exists: `SHOW DATABASES;`
- Check `.env` file configuration
- Verify tables exist: `USE GymMemberShip_WorkOutTracker; SHOW TABLES;`

### Port already in use
- Change `PORT` in `.env` file to a different port (e.g., 3001, 5000)
- Or kill the process using port 3000:
  ```bash
  # Find process
  lsof -i :3000
  # Kill process (replace PID)
  kill -9 PID
  ```

### "No members found" for Trainer
- Ensure members are assigned to the trainer in the database
- Check `Member.TrainerId` matches the trainer's `TrainerId`
- Admin can assign trainers to members via the Members edit page

### Bootstrap styles not loading
- Check internet connection (Bootstrap loads from CDN)
- Verify browser console for errors
- Check network tab in browser DevTools

## Development Notes

- All database operations use transactions for ACID compliance
- Error handling prevents crashes on database errors
- Role-based access control protects routes with decorators
- Session management for user authentication
- Bootstrap 5.3.8 for modern, responsive UI
- Green buttons for login, red buttons for logout and danger operations
- All SQL queries use parameterized statements to prevent SQL injection

## ACID Properties Implementation

- **Atomicity**: All stored procedures wrapped in transactions with ROLLBACK on errors
- **Consistency**: Foreign keys, constraints, and triggers ensure data integrity
- **Isolation**: InnoDB engine provides default isolation level
- **Durability**: InnoDB engine ensures committed transactions are durable

## License

This project is for Educational purposes (DBMS Mini-Project).

## Authors

- **CHENNUPATI GUNADEEP** (PES1UG23CS160)
- **C S DEEPAK** (PES1UG23CS907)

## Acknowledgments

- Built as part of the Database Management Systems (DBMS) course
- Follows project guidelines and rubrics for Review-1 through Review-4
