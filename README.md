# GymMemberShip-WorkOutTracker
The Gym Membership and Workout Tracker is a database-driven system designed to manage gym operations efficiently. It maintains detailed records of members, trainers, workout plans, exercises, attendance, and payments, ensuring smooth coordination between gym staff and members.

## Setup (with Python virtual environment)

Follow these steps on macOS/Linux (zsh/bash):

```bash
# 1) Create and activate a virtual environment in the project folder
python3 -m venv .venv
source .venv/bin/activate

# 2) Upgrade pip and install dependencies
pip install --upgrade pip
pip install -r requirements.txt

# 3) Set environment variables (example)
export DB_HOST=localhost
export DB_USER=root
export DB_PASSWORD=yourpass
export DB_NAME=GymMemberShip_WorkOutTracker
export FLASK_SECRET=dev
export ADMIN_PASSWORD=admin

# 4) Run the Flask app
python "/Users/chennupatigunadeep/Downloads/5TH SEM/DBMS/MINI-PROJECT/app.py"

# 5) Deactivate the venv when done
deactivate
```

On Windows (PowerShell):

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install --upgrade pip
pip install -r "C:\Users\chennupatigunadeep\Downloads\5TH SEM\DBMS\MINI-PROJECT\requirements.txt"
$env:DB_HOST = "localhost"
$env:DB_USER = "root"
$env:DB_PASSWORD = "yourpass"
$env:DB_NAME = "GymMemberShip_WorkOutTracker"
$env:FLASK_SECRET = "dev"
$env:ADMIN_PASSWORD = "admin"
python "C:\Users\chennupatigunadeep\Downloads\5TH SEM\DBMS\MINI-PROJECT\app.py"
deactivate
```

## Notes
- Use `.venv` (recommended) or `venv` as your virtual environment folder name.
- The repository `.gitignore` excludes common venv folders so they won’t be committed.
