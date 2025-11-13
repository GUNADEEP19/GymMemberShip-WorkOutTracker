import os
from functools import wraps
from flask import Flask, render_template, request, redirect, url_for, flash, session
import pymysql
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Debug: Print DB config (remove password for security)
if __name__ == '__main__':
    print(f"DB_HOST: {os.getenv('DB_HOST')}")
    print(f"DB_USER: {os.getenv('DB_USER')}")
    print(f"DB_PASSWORD: {'*' * len(os.getenv('DB_PASSWORD', ''))} (length: {len(os.getenv('DB_PASSWORD', ''))})")
    print(f"DB_NAME: {os.getenv('DB_NAME')}")


def get_db_connection():
    """Get MySQL database connection using PyMySQL"""
    return pymysql.connect(
        host=os.getenv('DB_HOST', 'localhost'),
        user=os.getenv('DB_USER', 'root'),
        password=os.getenv('DB_PASSWORD', ''),
        database=os.getenv('DB_NAME', 'GymMemberShip_WorkOutTracker'),
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=False,
    )


app = Flask(__name__)
app.secret_key = os.getenv('FLASK_SECRET', 'dev-secret')


@app.route('/')
def index():
    role = session.get('role')
    if not role:
        return redirect(url_for('login'))
    return redirect(url_for('dashboard'))


# ---------------- Auth (very simple demo) ----------------
def role_required(*allowed_roles):
    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            role = session.get('role')
            if role is None or (allowed_roles and role not in allowed_roles):
                flash('Not authorized', 'danger')
                return redirect(url_for('login'))
            return fn(*args, **kwargs)
        return wrapper
    return decorator


@app.route('/login', methods=['GET', 'POST'])
def login():
    """Unified login page with email and password"""
    if request.method == 'POST':
        email = request.form.get('email', '').strip()
        password = request.form.get('password', '')
        
        if not email or not password:
            flash('Email and password are required', 'danger')
            return render_template('auth/login.html')
        
        try:
            # Try Admin first
            admin = execute_query('SELECT * FROM Admin WHERE Email=%s', (email,))
            if admin and admin[0]['Password'] == password:
                session['role'] = 'admin'
                session['user_id'] = admin[0]['AdminId']
                session['user_name'] = admin[0]['Name']
                flash('Logged in as admin', 'success')
                return redirect(url_for('dashboard'))
            
            # Try Member
            member = execute_query('SELECT * FROM Member WHERE Email=%s', (email,))
            if member and member[0]['Password'] == password:
                session['role'] = 'member'
                session['user_id'] = member[0]['MemberId']
                session['user_name'] = member[0]['Name']
                flash('Logged in as member', 'success')
                return redirect(url_for('dashboard'))
            
            # Try Trainer
            trainer = execute_query('SELECT * FROM Trainer WHERE Email=%s', (email,))
            if trainer and trainer[0]['Password'] == password:
                session['role'] = 'trainer'
                session['user_id'] = trainer[0]['TrainerId']
                session['user_name'] = trainer[0]['TrainerName']
                flash('Logged in as trainer', 'success')
                return redirect(url_for('dashboard'))
            
            flash('Invalid email or password', 'danger')
        except Exception as e:
            flash(f'Database error: {str(e)}', 'danger')
    
    return render_template('auth/login.html')


@app.route('/logout')
def logout():
    session.clear()
    flash('Logged out', 'success')
    return redirect(url_for('login'))


# ---------- Role-based Dashboard ----------
@app.route('/dashboard')
def dashboard():
    role = session.get('role')
    if not role:
        return redirect(url_for('login'))
    return render_template('dashboard.html', role=role, user_name=session.get('user_name'))


def execute_query(sql, params=None, commit=False, silent=False):
    """Execute MySQL query with error handling. Returns empty list/None on error if silent=True."""
    try:
        conn = get_db_connection()
        try:
            with conn.cursor() as cur:
                cur.execute(sql, params or ())
                if commit:
                    conn.commit()
                if cur.description:
                    return cur.fetchall()
                return None
        except Exception as e:
            if commit:
                conn.rollback()
            if silent:
                if commit:
                    return None
                return []
            raise e
        finally:
            conn.close()
    except Exception as e:
        if silent:
            if commit:
                return None
            return []
        raise e


# ---------- CRUD: Member ----------
@app.route('/members')
@role_required('admin')
def members_list():
    try:
        rows = execute_query('SELECT * FROM Member ORDER BY MemberId')
    except Exception as e:
        flash(f'Database error: {str(e)}. Ensure DB is set up.', 'danger')
        rows = []
    return render_template('members/list.html', rows=rows)


@app.route('/members/create', methods=['GET', 'POST'])
@role_required('admin')
def members_create():
    if request.method == 'POST':
        password = request.form.get('Password') or 'member123'
        data = (
            request.form['Name'],
            request.form.get('Email') or None,
            request.form.get('PhoneNo') or None,
            password,
            request.form.get('Address') or None,
            request.form.get('DoB') or None,
            request.form.get('JoinDate') or None,
            request.form.get('Gender') or None,
            request.form.get('PackageId') or None,
            request.form.get('TrainerId') or None,
        )
        try:
            execute_query(
                'INSERT INTO Member(Name,Email,PhoneNo,Password,Address,DoB,JoinDate,Gender,PackageId,TrainerId)\n'
                'VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)',
                data,
                commit=True,
            )
            flash('Member created successfully in MySQL database', 'success')
            return redirect(url_for('members_list'))
        except Exception as e:
            flash(f'Error creating member: {str(e)}', 'danger')
    try:
        packages = execute_query('SELECT PackageId, PackageName FROM Package ORDER BY PackageName', silent=True)
        trainers = execute_query('SELECT TrainerId, TrainerName FROM Trainer ORDER BY TrainerName', silent=True)
    except Exception as e:
        flash(f'Error loading dropdowns: {str(e)}', 'warning')
        packages = []
        trainers = []
    return render_template('members/create.html', packages=packages, trainers=trainers)


@app.route('/members/<int:member_id>/edit', methods=['GET', 'POST'])
@role_required('admin')
def members_edit(member_id: int):
    if request.method == 'POST':
        data = (
            request.form['Name'],
            request.form.get('Email') or None,
            request.form.get('PhoneNo') or None,
            request.form.get('Address') or None,
            request.form.get('DoB') or None,
            request.form.get('JoinDate') or None,
            request.form.get('Gender') or None,
            request.form.get('PackageId') or None,
            request.form.get('TrainerId') or None,
            member_id,
        )
        try:
            password = request.form.get('Password') or None
            if password:
                execute_query(
                    'UPDATE Member SET Name=%s,Email=%s,PhoneNo=%s,Password=%s,Address=%s,DoB=%s,JoinDate=%s,Gender=%s,PackageId=%s,TrainerId=%s WHERE MemberId=%s',
                    (request.form['Name'], request.form.get('Email') or None, request.form.get('PhoneNo') or None, password,
                     request.form.get('Address') or None, request.form.get('DoB') or None, request.form.get('JoinDate') or None,
                     request.form.get('Gender') or None, request.form.get('PackageId') or None, request.form.get('TrainerId') or None, member_id),
                    commit=True,
                )
            else:
                execute_query(
                    'UPDATE Member SET Name=%s,Email=%s,PhoneNo=%s,Address=%s,DoB=%s,JoinDate=%s,Gender=%s,PackageId=%s,TrainerId=%s WHERE MemberId=%s',
                    data,
                    commit=True,
                )
            flash('Member updated', 'success')
            return redirect(url_for('members_list'))
        except Exception as e:
            flash(str(e), 'danger')
    try:
        row = execute_query('SELECT * FROM Member WHERE MemberId=%s', (member_id,))
        if not row:
            flash('Member not found', 'warning')
            return redirect(url_for('members_list'))
        packages = execute_query('SELECT PackageId, PackageName FROM Package ORDER BY PackageName', silent=True)
        trainers = execute_query('SELECT TrainerId, TrainerName FROM Trainer ORDER BY TrainerName', silent=True)
    except Exception as e:
        flash(f'Database error: {str(e)}', 'danger')
        return redirect(url_for('members_list'))
    return render_template('members/edit.html', m=row[0], packages=packages or [], trainers=trainers or [])


@app.route('/members/<int:member_id>/delete', methods=['POST'])
@role_required('admin')
def members_delete(member_id: int):
    try:
        execute_query('DELETE FROM Member WHERE MemberId=%s', (member_id,), commit=True)
        flash('Member deleted', 'success')
    except Exception as e:
        flash(str(e), 'danger')
    return redirect(url_for('members_list'))


# ---------- Trainer: View Assigned Members ----------
@app.route('/trainer/members')
@role_required('trainer')
def trainer_members():
    """Trainer can see their assigned members, contact details, and assigned plans"""
    trainer_id = session.get('user_id')
    try:
        # Get all members assigned to this trainer with their contact details
        members = execute_query(
            '''SELECT M.MemberId, M.Name, M.Email, M.PhoneNo, M.Address, M.DoB, M.Gender, M.JoinDate,
                      P.PackageName, P.Price
               FROM Member M
               LEFT JOIN Package P ON M.PackageId = P.PackageId
               WHERE M.TrainerId = %s
               ORDER BY M.Name''',
            (trainer_id,),
            silent=True
        )
        
        # For each member, get their assigned plans
        members_with_plans = []
        for member in members or []:
            plans = execute_query(
                '''SELECT WP.PlanId, WP.Goal, WP.DurationWeeks
                   FROM Member_WorkOutPlan MWP
                   JOIN WorkOutPlan WP ON MWP.PlanId = WP.PlanId
                   WHERE MWP.MemberId = %s
                   ORDER BY WP.Goal''',
                (member['MemberId'],),
                silent=True
            )
            member['plans'] = plans or []
            members_with_plans.append(member)
    except Exception as e:
        flash(f'Error loading data: {str(e)}', 'danger')
        members_with_plans = []
    
    return render_template('trainer/members.html', members=members_with_plans)


# ---------- Member: View Assigned Trainer & Plans ----------
@app.route('/member/my-trainer')
@role_required('member')
def member_my_trainer():
    """Member can see their assigned trainer and assigned plans"""
    member_id = session.get('user_id')
    try:
        # Get assigned trainer details
        trainer = execute_query(
            '''SELECT T.TrainerId, T.TrainerName, T.Email, T.PhoneNo, T.DoB
               FROM Member M
               JOIN Trainer T ON M.TrainerId = T.TrainerId
               WHERE M.MemberId = %s''',
            (member_id,),
            silent=True
        )
        
        # Get assigned workout plans
        plans = execute_query(
            '''SELECT WP.PlanId, WP.Goal, WP.DurationWeeks, WP.TrainerId,
                      T.TrainerName
               FROM Member_WorkOutPlan MWP
               JOIN WorkOutPlan WP ON MWP.PlanId = WP.PlanId
               LEFT JOIN Trainer T ON WP.TrainerId = T.TrainerId
               WHERE MWP.MemberId = %s
               ORDER BY WP.Goal''',
            (member_id,),
            silent=True
        )
    except Exception as e:
        flash(f'Error loading data: {str(e)}', 'danger')
        trainer = None
        plans = []
    
    return render_template('member/my_trainer.html', trainer=trainer[0] if trainer else None, plans=plans or [])


# ---------- Procedures / Functions GUI ----------
@app.route('/actions/enroll', methods=['GET', 'POST'])
@role_required('admin', 'trainer')
def action_enroll():
    if request.method == 'POST':
        member_id = request.form.get('member_id')
        plan_id = request.form.get('plan_id')
        try:
            # For trainers, verify they can only enroll their assigned members
            if session.get('role') == 'trainer':
                trainer_id = session.get('user_id')
                member_check = execute_query(
                    'SELECT MemberId FROM Member WHERE MemberId=%s AND TrainerId=%s',
                    (member_id, trainer_id),
                    silent=True
                )
                if not member_check:
                    flash('You can only enroll members assigned to you', 'danger')
                    return redirect(url_for('action_enroll'))
            
            execute_query('CALL sp_enroll_member_to_plan(%s,%s)', (member_id, plan_id), commit=True)
            flash('Enrolled successfully', 'success')
        except Exception as e:
            flash(str(e), 'danger')
        return redirect(url_for('action_enroll'))
    try:
        # Limit members based on role
        if session.get('role') == 'trainer':
            trainer_id = session.get('user_id')
            members = execute_query(
                'SELECT MemberId, Name FROM Member WHERE TrainerId=%s ORDER BY Name',
                (trainer_id,),
                silent=True
            )
        else:
            # Admin can see all members
            members = execute_query('SELECT MemberId, Name FROM Member ORDER BY Name', silent=True)
        
        plans = execute_query('SELECT PlanId, Goal FROM WorkOutPlan ORDER BY Goal', silent=True)
    except Exception as e:
        flash(f'Error loading data: {str(e)}', 'warning')
        members = []
        plans = []
    return render_template('actions/enroll.html', members=members, plans=plans)


@app.route('/actions/make_payment', methods=['GET', 'POST'])
@role_required('admin', 'member')
def action_make_payment():
    if request.method == 'POST':
        try:
            package_id = request.form.get('package_id')
            # Get the package price from the database
            package = execute_query('SELECT Price FROM Package WHERE PackageId=%s', (package_id,))
            if not package:
                flash('Package not found', 'danger')
                return redirect(url_for('action_make_payment'))
            amount = package[0]['Price']
            
            # For members, they can only pay for themselves
            member_id = request.form.get('member_id')
            if session.get('role') == 'member' and int(member_id) != session.get('user_id'):
                flash('You can only make payments for yourself', 'danger')
                return redirect(url_for('action_make_payment'))
            
            execute_query(
                'CALL sp_make_payment(%s,%s,%s,%s)',
                (
                    member_id,
                    package_id,
                    amount,
                    request.form.get('mode'),
                ),
                commit=True,
            )
            flash('Payment recorded (and audited)', 'success')
        except Exception as e:
            flash(str(e), 'danger')
        return redirect(url_for('action_make_payment'))
    try:
        # Limit member options for self-service
        if session.get('role') == 'member':
            member_id = session.get('user_id')
            members = execute_query('SELECT MemberId, Name FROM Member WHERE MemberId=%s', (member_id,), silent=True)
            # Show only this member's payment history
            audits = execute_query(
                '''SELECT PA.* FROM Payment_Audit PA
                   JOIN Payment P ON PA.PaymentId = P.PaymentId
                   WHERE P.MemberId = %s
                   ORDER BY PA.AuditId DESC LIMIT 20''',
                (member_id,),
                silent=True
            )
        else:
            members = execute_query('SELECT MemberId, Name FROM Member ORDER BY Name', silent=True)
            # Admin sees all audit records
            audits = execute_query('SELECT * FROM Payment_Audit ORDER BY AuditId DESC LIMIT 20', silent=True)
        packages = execute_query('SELECT PackageId, PackageName, Price FROM Package ORDER BY PackageName', silent=True)
    except Exception as e:
        flash(f'Error loading data: {str(e)}', 'warning')
        members = []
        packages = []
        audits = []
    # Payment mode options
    payment_modes = ['Card', 'Cash', 'UPI', 'Net Banking', 'Wallet']
    return render_template('actions/make_payment.html', members=members, packages=packages, audits=audits, payment_modes=payment_modes)


# ---------- Attendance Management ----------
@app.route('/actions/mark_attendance', methods=['GET', 'POST'])
@role_required('admin', 'trainer')
def action_mark_attendance():
    if request.method == 'POST':
        try:
            member_id = request.form.get('member_id')
            date = request.form.get('date')
            check_in = request.form.get('check_in')
            check_out = request.form.get('check_out')
            
            # For trainers, verify they can only mark attendance for assigned members
            if session.get('role') == 'trainer':
                trainer_id = session.get('user_id')
                member_check = execute_query(
                    'SELECT MemberId FROM Member WHERE MemberId=%s AND TrainerId=%s',
                    (member_id, trainer_id),
                    silent=True
                )
                if not member_check:
                    flash('You can only mark attendance for members assigned to you', 'danger')
                    return redirect(url_for('action_mark_attendance'))
            
            # Use stored procedure to record attendance (triggers handle validation)
            execute_query(
                'CALL sp_record_attendance(%s,%s,%s,%s)',
                (member_id, date, check_in, check_out),
                commit=True
            )
            flash('Attendance recorded successfully', 'success')
        except Exception as e:
            flash(f'Error: {str(e)}', 'danger')
        return redirect(url_for('action_mark_attendance'))
    
    try:
        # Limit members based on role
        if session.get('role') == 'trainer':
            trainer_id = session.get('user_id')
            members = execute_query(
                'SELECT MemberId, Name, Email FROM Member WHERE TrainerId=%s ORDER BY Name',
                (trainer_id,),
                silent=True
            )
        else:
            # Admin can see all members
            members = execute_query('SELECT MemberId, Name, Email FROM Member ORDER BY Name', silent=True)
    except Exception as e:
        flash(f'Error loading members: {str(e)}', 'warning')
        members = []
    
    # Get today's date for default value
    from datetime import date
    today = date.today().isoformat()
    
    return render_template('actions/mark_attendance.html', members=members, today=today)


@app.route('/attendance/view')
@role_required('admin', 'trainer')
def attendance_view():
    try:
        if session.get('role') == 'trainer':
            trainer_id = session.get('user_id')
            # View attendance for assigned members only
            attendance = execute_query(
                '''SELECT A.AttendanceId, A.MemberId, M.Name AS MemberName, 
                          A.Date, A.CheckInTime, A.CheckOutTime,
                          TIMESTAMPDIFF(MINUTE, A.CheckInTime, A.CheckOutTime) AS DurationMinutes
                   FROM Attendance A
                   JOIN Member M ON A.MemberId = M.MemberId
                   WHERE M.TrainerId = %s
                   ORDER BY A.Date DESC, A.CheckInTime DESC
                   LIMIT 100''',
                (trainer_id,),
                silent=True
            )
        else:
            # Admin can see all attendance
            attendance = execute_query(
                '''SELECT A.AttendanceId, A.MemberId, M.Name AS MemberName, 
                          A.Date, A.CheckInTime, A.CheckOutTime,
                          TIMESTAMPDIFF(MINUTE, A.CheckInTime, A.CheckOutTime) AS DurationMinutes
                   FROM Attendance A
                   JOIN Member M ON A.MemberId = M.MemberId
                   ORDER BY A.Date DESC, A.CheckInTime DESC
                   LIMIT 100''',
                silent=True
            )
    except Exception as e:
        flash(f'Error loading attendance: {str(e)}', 'warning')
        attendance = []
    
    # Format duration for display
    if attendance:
        for record in attendance:
            if record.get('DurationMinutes') is not None and record.get('CheckOutTime'):
                minutes = record['DurationMinutes']
                hours = minutes // 60
                mins = minutes % 60
                record['Duration'] = f"{hours}h {mins}m" if hours > 0 else f"{mins}m"
            else:
                record['Duration'] = '-'
    
    return render_template('attendance/view.html', attendance=attendance or [])


# ---------- Stored Functions GUI ----------
@app.route('/membership/end_date')
@role_required('admin', 'member')
def membership_end_date():
    try:
        from datetime import date
        
        if session.get('role') == 'member':
            # Member can only see their own membership end date
            member_id = session.get('user_id')
            result = execute_query(
                '''SELECT M.MemberId, M.Name, M.Email, 
                          fn_membership_end_date(M.MemberId) AS EndDate
                   FROM Member M
                   WHERE M.MemberId = %s''',
                (member_id,),
                silent=True
            )
        else:
            # Admin can see all members' end dates
            result = execute_query(
                '''SELECT M.MemberId, M.Name, M.Email, 
                          fn_membership_end_date(M.MemberId) AS EndDate
                   FROM Member M
                   ORDER BY M.Name''',
                silent=True
            )
        
        # Process results: convert dates and determine status
        today = date.today()
        if result:
            for record in result:
                end_date = record.get('EndDate')
                if end_date:
                    # Convert date object to string for display
                    if isinstance(end_date, date):
                        record['EndDateStr'] = end_date.isoformat()
                    else:
                        record['EndDateStr'] = str(end_date)
                    
                    # Determine status by comparing dates
                    if isinstance(end_date, date):
                        record['Status'] = 'Active' if end_date >= today else 'Expired'
                    else:
                        # If it's a string, parse it
                        try:
                            end_date_obj = date.fromisoformat(str(end_date))
                            record['Status'] = 'Active' if end_date_obj >= today else 'Expired'
                            record['EndDateStr'] = end_date_obj.isoformat()
                        except:
                            record['Status'] = 'Unknown'
                            record['EndDateStr'] = str(end_date)
                else:
                    record['EndDateStr'] = None
                    record['Status'] = 'No Membership'
        
    except Exception as e:
        flash(f'Error loading membership data: {str(e)}', 'warning')
        result = []
    
    return render_template('membership/end_date.html', memberships=result or [])


@app.route('/membership/active_status')
@role_required('admin', 'trainer')
def membership_active_status():
    try:
        if session.get('role') == 'trainer':
            # Trainer can only see assigned members' active status
            trainer_id = session.get('user_id')
            result = execute_query(
                '''SELECT M.MemberId, M.Name, M.Email,
                          fn_is_member_active(M.MemberId) AS IsActive,
                          fn_membership_end_date(M.MemberId) AS EndDate
                   FROM Member M
                   WHERE M.TrainerId = %s
                   ORDER BY M.Name''',
                (trainer_id,),
                silent=True
            )
        else:
            # Admin can see all members' active status
            result = execute_query(
                '''SELECT M.MemberId, M.Name, M.Email,
                          fn_is_member_active(M.MemberId) AS IsActive,
                          fn_membership_end_date(M.MemberId) AS EndDate
                   FROM Member M
                   ORDER BY M.Name''',
                silent=True
            )
    except Exception as e:
        flash(f'Error loading active status: {str(e)}', 'warning')
        result = []
    
    return render_template('membership/active_status.html', members=result or [])


# ---------- Equipment View (Admin only) ----------
@app.route('/equipment')
@role_required('admin')
def equipment_list():
    try:
        equipment = execute_query('SELECT * FROM Equipment ORDER BY EquipmentId', silent=True)
    except Exception as e:
        flash(f'Database error: {str(e)}', 'danger')
        equipment = []
    return render_template('equipment/list.html', equipment=equipment or [])


# ---------- MySQL Console (Admin only) ----------
@app.route('/mysql-console', methods=['GET', 'POST'])
@role_required('admin')
def mysql_console():
    results = None
    error = None
    query_executed = None
    
    if request.method == 'POST':
        query = request.form.get('sql_query', '').strip()
        if query:
            query_executed = query
            try:
                conn = get_db_connection()
                try:
                    with conn.cursor() as cur:
                        cur.execute(query)
                        if cur.description:
                            # SELECT query - fetch results
                            results = cur.fetchall()
                        else:
                            # INSERT/UPDATE/DELETE - show affected rows
                            conn.commit()
                            results = [{'affected_rows': cur.rowcount, 'message': 'Query executed successfully'}]
                except Exception as e:
                    conn.rollback()
                    error = str(e)
                finally:
                    conn.close()
            except Exception as e:
                error = str(e)
    
    return render_template('admin/mysql_console.html', results=results, error=error, query_executed=query_executed)


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.getenv('PORT', 3000)), debug=True)


