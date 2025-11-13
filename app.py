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
            admin = execute_query('CALL sp_get_admin_by_email(%s)', (email,), silent=True)
            if admin and admin[0]['Password'] == password:
                session['role'] = 'admin'
                session['user_id'] = admin[0]['AdminId']
                session['user_name'] = admin[0]['Name']
                flash('Logged in as admin', 'success')
                return redirect(url_for('dashboard'))
            
            # Try Member
            member = execute_query('CALL sp_get_member_by_email(%s)', (email,), silent=True)
            if member and member[0]['Password'] == password:
                session['role'] = 'member'
                session['user_id'] = member[0]['MemberId']
                session['user_name'] = member[0]['Name']
                flash('Logged in as member', 'success')
                return redirect(url_for('dashboard'))
            
            # Try Trainer
            trainer = execute_query('CALL sp_get_trainer_by_email(%s)', (email,), silent=True)
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
        rows = execute_query('CALL sp_get_members()', silent=True)
    except Exception as e:
        flash(f'Database error: {str(e)}. Ensure DB is set up.', 'danger')
        rows = []
    return render_template('members/list.html', rows=rows)


@app.route('/members/create', methods=['GET', 'POST'])
@role_required('admin')
def members_create():
    try:
        packages = execute_query('CALL sp_list_packages()', silent=True)
        trainers = execute_query('CALL sp_list_trainers()', silent=True)
    except Exception as e:
        flash(f'Error loading dropdowns: {str(e)}', 'warning')
        packages = []
        trainers = []

    if request.method == 'POST':
        name = request.form['Name'].strip()
        email = request.form.get('Email') or None
        phone = request.form.get('PhoneNo') or None
        password = request.form.get('Password') or None
        address = request.form.get('Address') or None
        dob = request.form.get('DoB') or None
        join_date = request.form.get('JoinDate') or None
        gender = request.form.get('Gender') or None
        package_id = request.form.get('PackageId')
        package_id = int(package_id) if package_id else None
        trainer_id = request.form.get('TrainerId')
        trainer_id = int(trainer_id) if trainer_id else None

        try:
            execute_query(
                'CALL sp_create_member(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)',
                (
                    name,
                    email,
                    phone,
                    password,
                    address,
                    dob or None,
                    join_date or None,
                    gender or None,
                    package_id,
                    trainer_id,
                ),
                commit=True,
            )
            flash('Member created successfully in MySQL database', 'success')
            return redirect(url_for('members_list'))
        except Exception as e:
            flash(f'Error creating member: {str(e)}', 'danger')

    return render_template('members/create.html', packages=packages or [], trainers=trainers or [])


@app.route('/members/<int:member_id>/edit', methods=['GET', 'POST'])
@role_required('admin')
def members_edit(member_id: int):
    try:
        member_rows = execute_query('CALL sp_get_member_detail(%s)', (member_id,), silent=True)
        if not member_rows:
            flash('Member not found', 'warning')
            return redirect(url_for('members_list'))
        member_record = member_rows[0]
        packages = execute_query('CALL sp_list_packages()', silent=True)
        trainers = execute_query('CALL sp_list_trainers()', silent=True)
    except Exception as e:
        flash(f'Database error: {str(e)}', 'danger')
        return redirect(url_for('members_list'))

    if request.method == 'POST':
        name = request.form['Name'].strip()
        email = request.form.get('Email') or None
        phone = request.form.get('PhoneNo') or None
        password = request.form.get('Password') or None
        address = request.form.get('Address') or None
        dob = request.form.get('DoB') or None
        join_date = request.form.get('JoinDate') or None
        gender = request.form.get('Gender') or None
        package_id = request.form.get('PackageId')
        package_id = int(package_id) if package_id else None
        trainer_id = request.form.get('TrainerId')
        trainer_id = int(trainer_id) if trainer_id else None
        try:
            execute_query(
                'CALL sp_update_member(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)',
                (
                    member_id,
                    name,
                    email,
                    phone,
                    password,
                    address,
                    dob or None,
                    join_date or None,
                    gender or None,
                    package_id,
                    trainer_id,
                ),
                commit=True,
            )
            flash('Member updated', 'success')
            return redirect(url_for('members_list'))
        except Exception as e:
            flash(str(e), 'danger')
            # refresh latest data on error
            refreshed = execute_query('CALL sp_get_member_detail(%s)', (member_id,), silent=True)
            if refreshed:
                member_record = refreshed[0]

    return render_template('members/edit.html', m=member_record, packages=packages or [], trainers=trainers or [])


@app.route('/members/<int:member_id>/delete', methods=['POST'])
@role_required('admin')
def members_delete(member_id: int):
    try:
        execute_query('CALL sp_delete_member(%s)', (member_id,), commit=True)
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
        members = execute_query('CALL sp_get_trainer_members(%s)', (trainer_id,), silent=True)
        members_with_plans = []
        for member in members or []:
            plans = execute_query('CALL sp_get_member_plans(%s)', (member['MemberId'],), silent=True)
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
        trainer = execute_query('CALL sp_get_member_trainer_info(%s)', (member_id,), silent=True)
        plans = execute_query('CALL sp_get_member_plans_with_trainer(%s)', (member_id,), silent=True)
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
            if not member_id or not plan_id:
                flash('Member and plan are required', 'danger')
                return redirect(url_for('action_enroll'))
            member_id_int = int(member_id)
            plan_id_int = int(plan_id)

            # For trainers, verify they can only enroll their assigned members
            if session.get('role') == 'trainer':
                trainer_id = session.get('user_id')
                member_check = execute_query('CALL sp_verify_member_trainer(%s,%s)', (member_id_int, trainer_id), silent=True)
                if not member_check:
                    flash('You can only enroll members assigned to you', 'danger')
                    return redirect(url_for('action_enroll'))
            
            execute_query('CALL sp_enroll_member_to_plan(%s,%s)', (member_id_int, plan_id_int), commit=True)
            flash('Enrolled successfully', 'success')
        except Exception as e:
            flash(str(e), 'danger')
        return redirect(url_for('action_enroll'))

    try:
        if session.get('role') == 'trainer':
            trainer_id = session.get('user_id')
            members = execute_query('CALL sp_list_members_for_trainer(%s)', (trainer_id,), silent=True)
        else:
            members = execute_query('CALL sp_list_members_basic()', silent=True)
        plans = execute_query('CALL sp_list_workout_plans()', silent=True)
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
            member_id = request.form.get('member_id')
            mode = request.form.get('mode')
            if not package_id or not member_id:
                flash('Member and package are required', 'danger')
                return redirect(url_for('action_make_payment'))
            package_id_int = int(package_id)
            member_id_int = int(member_id)

            package = execute_query('CALL sp_get_package_price(%s)', (package_id_int,), silent=True)
            if not package:
                flash('Package not found', 'danger')
                return redirect(url_for('action_make_payment'))
            amount = package[0]['Price']

            if session.get('role') == 'member' and member_id_int != session.get('user_id'):
                flash('You can only make payments for yourself', 'danger')
                return redirect(url_for('action_make_payment'))

            execute_query(
                'CALL sp_make_payment(%s,%s,%s,%s)',
                (
                    member_id_int,
                    package_id_int,
                    amount,
                    mode,
                ),
                commit=True,
            )
            flash('Payment recorded (and audited)', 'success')
        except Exception as e:
            flash(str(e), 'danger')
        return redirect(url_for('action_make_payment'))

    try:
        if session.get('role') == 'member':
            member_id = session.get('user_id')
            members = execute_query('CALL sp_get_member_basic(%s)', (member_id,), silent=True)
            audits = execute_query('CALL sp_get_payment_audit_for_member(%s)', (member_id,), silent=True)
        else:
            members = execute_query('CALL sp_list_members_basic()', silent=True)
            audits = execute_query('CALL sp_get_payment_audit_all()', silent=True)
        packages = execute_query('CALL sp_list_packages()', silent=True)
    except Exception as e:
        flash(f'Error loading data: {str(e)}', 'warning')
        members = []
        packages = []
        audits = []
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

            if not member_id:
                flash('Member is required', 'danger')
                return redirect(url_for('action_mark_attendance'))
            member_id_int = int(member_id)

            # For trainers, verify they can only mark attendance for assigned members
            if session.get('role') == 'trainer':
                trainer_id = session.get('user_id')
                member_check = execute_query('CALL sp_verify_member_trainer(%s,%s)', (member_id_int, trainer_id), silent=True)
                if not member_check:
                    flash('You can only mark attendance for members assigned to you', 'danger')
                    return redirect(url_for('action_mark_attendance'))

            # Use stored procedure to record attendance (triggers handle validation)
            execute_query(
                'CALL sp_record_attendance(%s,%s,%s,%s)',
                (member_id_int, date, check_in, check_out),
                commit=True
            )
            flash('Attendance recorded successfully', 'success')
        except Exception as e:
            flash(f'Error: {str(e)}', 'danger')
        return redirect(url_for('action_mark_attendance'))

    try:
        if session.get('role') == 'trainer':
            trainer_id = session.get('user_id')
            members = execute_query('CALL sp_list_members_for_trainer(%s)', (trainer_id,), silent=True)
        else:
            members = execute_query('CALL sp_list_members_basic()', silent=True)
    except Exception as e:
        flash(f'Error loading members: {str(e)}', 'warning')
        members = []
    
    from datetime import date as _date
    today = _date.today().isoformat()
    
    return render_template('actions/mark_attendance.html', members=members, today=today)


@app.route('/attendance/view')
@role_required('admin', 'trainer')
def attendance_view():
    try:
        if session.get('role') == 'trainer':
            trainer_id = session.get('user_id')
            attendance = execute_query('CALL sp_get_attendance_for_trainer(%s)', (trainer_id,), silent=True)
        else:
            attendance = execute_query('CALL sp_get_attendance_all()', silent=True)
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
        today = date.today()

        if session.get('role') == 'member':
            member_id = session.get('user_id')
            result = execute_query('CALL sp_get_membership_end_date_for_member(%s)', (member_id,), silent=True)
        else:
            result = execute_query('CALL sp_get_membership_end_dates()', silent=True)

        if result:
            for record in result:
                end_date = record.get('EndDate')
                if end_date:
                    if isinstance(end_date, date):
                        record['EndDateStr'] = end_date.isoformat()
                        record['Status'] = 'Active' if end_date >= today else 'Expired'
                    else:
                        try:
                            parsed = date.fromisoformat(str(end_date))
                            record['EndDateStr'] = parsed.isoformat()
                            record['Status'] = 'Active' if parsed >= today else 'Expired'
                        except Exception:
                            record['EndDateStr'] = str(end_date)
                            record['Status'] = 'Unknown'
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
            trainer_id = session.get('user_id')
            result = execute_query('CALL sp_get_active_status_for_trainer(%s)', (trainer_id,), silent=True)
        else:
            result = execute_query('CALL sp_get_active_status_all()', silent=True)
    except Exception as e:
        flash(f'Error loading active status: {str(e)}', 'warning')
        result = []

    return render_template('membership/active_status.html', members=result or [])


# ---------- Equipment View (Admin only) ----------
@app.route('/equipment')
@role_required('admin')
def equipment_list():
    try:
        equipment = execute_query('CALL sp_list_equipment()', silent=True)
    except Exception as e:
        flash(f'Database error: {str(e)}', 'danger')
        equipment = []
    return render_template('equipment/list.html', equipment=equipment or [])


# ---------- Exercise Library (Admin & Trainer) ----------
@app.route('/exercises')
@role_required('admin', 'trainer')
def exercises_list():
    try:
        exercises = execute_query('CALL sp_list_exercises()', silent=True)
    except Exception as e:
        flash(f'Error loading exercises: {str(e)}', 'danger')
        exercises = []
    return render_template('exercise/list.html', exercises=exercises or [])


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