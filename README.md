# Gym Membership & Workout Tracker

A comprehensive database-driven web application for managing gym operations, including members, trainers, workout plans, attendance, and payments. Built with Flask (Python) and MySQL.

## Features

- **Role-based Access Control**: Admin, Member, and Trainer roles with different permissions
- **CRUD Operations**: Full Create, Read, Update, Delete for all entities
- **Database Triggers**: Automatic validation and audit logging
- **Stored Procedures & Functions**: Business logic encapsulated in database routines
- **MySQL Console**: Admin can execute SQL queries directly
- **User Management**: Create MySQL users with varied privileges
- **Query Dashboard**: Nested, Join, and Aggregate queries with GUI
- **Payment Audit Trail**: Complete audit log for all payment transactions

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
```

### Step 2: Create Database and Tables

Open MySQL console:
```bash
mysql -u root -p
```

Run the SQL files:
```sql
SOURCE GymMemberShip_WorkOutTracker.sql;
SOURCE REVIEW-3.sql;
```

Verify setup:
```sql
SHOW TABLES;
SELECT COUNT(*) FROM Trainer;
SELECT COUNT(*) FROM Member;
EXIT;
```

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

**Important:** Replace `your_mysql_password` with your actual MySQL root password (the one you use with `mysql -u root -p`).

## Running the Application

### Start the Flask Server

```bash
python app.py
```

You should see:
```
DB_HOST: localhost
DB_USER: root
DB_PASSWORD: ******** (Make Sure Length of the your Password Matches)
DB_NAME: GymMemberShip_WorkOutTracker
 * Running on http://0.0.0.0:3000
```

### Access the Application

Open your browser and navigate to:
- **Local:** http://localhost:3000
- **Network:** http://10.103.67.143:3000 (or your server IP)

You'll be redirected to the login page.

## Login Credentials

### Admin
- **Email:** `admin@gym.com`
- **Password:** `admin123`
- **Access:** Full system access, MySQL console, user management

### Member
- **Email:** `amit.sharma@example.com`
- **Password:** `member123`
- **Access:** Make payments, view queries

### Trainer
- **Email:** `rajesh@example.com`
- **Password:** `trainer123`
- **Access:** Enroll members, view queries

**Note:** Additional members and trainers are available in the seed data. Check the database for their emails.

## Project Structure

```
MINI-PROJECT/
├── app.py                          # Main Flask application
├── requirements.txt                 # Python dependencies
├── .env                            # Environment variables (create from env.example)
├── env.example                     # Environment variables template
├── GymMemberShip_WorkOutTracker.sql  # Database schema and seed data
├── REVIEW-3.sql                    # Triggers, procedures, and functions
├── TESTS.sql                       # Database integrity tests
├── templates/                      # HTML templates
│   ├── base.html                   # Base template with navigation
│   ├── dashboard.html              # Role-based dashboard
│   ├── auth/
│   │   └── login.html             # Unified login page
│   ├── members/                    # Member CRUD pages
│   ├── actions/                    # Procedures/functions GUI
│   ├── queries/                    # Query dashboard
│   └── admin/                      # Admin-only pages
│       ├── db_users.html          # MySQL user management
│       └── mysql_console.html     # SQL query console
└── README.md                       # This file
```

## Database Schema

### Tables (11 total)
1. **Admin** - System administrators
2. **Package** - Membership packages
3. **Trainer** - Gym trainers/staff
4. **Equipment** - Gym equipment inventory
5. **Exercise** - Exercise library
6. **Member** - Gym members
7. **WorkOutPlan** - Workout programs
8. **Member_WorkOutPlan** - Member-plan assignments
9. **WorkOutTracker** - Daily workout logs
10. **Attendance** - Member attendance records
11. **Payment** - Payment transactions (audited)

### Key Features
- **Foreign Keys:** Proper referential integrity with CASCADE/RESTRICT/SET NULL
- **Constraints:** UNIQUE, CHECK constraints for data quality
- **Triggers:** Validation and audit triggers
- **Procedures:** Business logic (enroll, payment, attendance, workout logging)
- **Functions:** Membership status, workout counts

## Technologies Used

- **Backend:** Flask 3.0.0 (Python)
- **Database:** MySQL 8.0+ (via PyMySQL)
- **Frontend:** HTML5, Pico CSS
- **Authentication:** Session-based with role management

## Troubleshooting

### "Access denied for user 'root'@'localhost'"
- Check `.env` file has correct MySQL password
- Verify password length matches (no extra spaces)
- Test password: `mysql -u root -p`

### "cryptography package is required"
- Install: `pip install cryptography`

### "Database error" on login
- Ensure MySQL server is running
- Verify database exists: `SHOW DATABASES;`
- Check `.env` file configuration

### Port already in use
- Change `PORT` in `.env` file
- Or kill process using port 3000

## Development Notes

- Database auto-initializes on first run (if using SQLite - not applicable for MySQL)
- All database operations use transactions for ACID compliance
- Error handling prevents crashes on database errors
- Role-based access control protects admin routes

## License

This project is for educational purposes (DBMS Mini-Project).

## Author

CHENNUPATI GUNADEEP (PES1UG23CS160)

C S DEEPAK (PES1UG23CS907)