import os
from functools import wraps
from flask import Flask, render_template, request, redirect, url_for, flash, session
import pymysql


def get_db_connection():
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
    return render_template('index.html', role=session.get('role'))


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
    if request.method == 'POST':
        user_type = request.form.get('type')  # admin/member/trainer
        if user_type == 'admin':
            if request.form.get('password') == os.getenv('ADMIN_PASSWORD', 'admin'):
                session['role'] = 'admin'
                session['user_id'] = 'admin'
                flash('Logged in as admin', 'success')
                return redirect(url_for('index'))
            flash('Invalid admin password', 'danger')
        elif user_type == 'member':
            member_id = request.form.get('member_id')
            rows = execute_query('SELECT MemberId, Name FROM Member WHERE MemberId=%s', (member_id,))
            if rows:
                session['role'] = 'member'
                session['user_id'] = rows[0]['MemberId']
                session['user_name'] = rows[0]['Name']
                flash('Logged in as member', 'success')
                return redirect(url_for('index'))
            flash('Member not found', 'danger')
        elif user_type == 'trainer':
            trainer_id = request.form.get('trainer_id')
            rows = execute_query('SELECT TrainerId, TrainerName FROM Trainer WHERE TrainerId=%s', (trainer_id,))
            if rows:
                session['role'] = 'trainer'
                session['user_id'] = rows[0]['TrainerId']
                session['user_name'] = rows[0]['TrainerName']
                flash('Logged in as trainer', 'success')
                return redirect(url_for('index'))
            flash('Trainer not found', 'danger')
    members = execute_query('SELECT MemberId, Name FROM Member ORDER BY Name')
    trainers = execute_query('SELECT TrainerId, TrainerName FROM Trainer ORDER BY TrainerName')
    return render_template('auth/login.html', members=members, trainers=trainers)


@app.route('/logout')
def logout():
    session.clear()
    flash('Logged out', 'success')
    return redirect(url_for('index'))


def execute_query(sql, params=None, commit=False):
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
        conn.rollback()
        raise e
    finally:
        conn.close()


# ---------- CRUD: Member ----------
@app.route('/members')
@role_required('admin')
def members_list():
    rows = execute_query('SELECT * FROM Member ORDER BY MemberId')
    return render_template('members/list.html', rows=rows)


@app.route('/members/create', methods=['GET', 'POST'])
@role_required('admin')
def members_create():
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
        )
        try:
            execute_query(
                'INSERT INTO Member(Name,Email,PhoneNo,Address,DoB,JoinDate,Gender,PackageId,TrainerId)\n'
                'VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s)',
                data,
                commit=True,
            )
            flash('Member created', 'success')
            return redirect(url_for('members_list'))
        except Exception as e:
            flash(str(e), 'danger')
    packages = execute_query('SELECT PackageId, PackageName FROM Package ORDER BY PackageName')
    trainers = execute_query('SELECT TrainerId, TrainerName FROM Trainer ORDER BY TrainerName')
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
            execute_query(
                'UPDATE Member SET Name=%s,Email=%s,PhoneNo=%s,Address=%s,DoB=%s,JoinDate=%s,Gender=%s,PackageId=%s,TrainerId=%s WHERE MemberId=%s',
                data,
                commit=True,
            )
            flash('Member updated', 'success')
            return redirect(url_for('members_list'))
        except Exception as e:
            flash(str(e), 'danger')
    row = execute_query('SELECT * FROM Member WHERE MemberId=%s', (member_id,))
    if not row:
        flash('Member not found', 'warning')
        return redirect(url_for('members_list'))
    packages = execute_query('SELECT PackageId, PackageName FROM Package ORDER BY PackageName')
    trainers = execute_query('SELECT TrainerId, TrainerName FROM Trainer ORDER BY TrainerName')
    return render_template('members/edit.html', m=row[0], packages=packages, trainers=trainers)


@app.route('/members/<int:member_id>/delete', methods=['POST'])
@role_required('admin')
def members_delete(member_id: int):
    try:
        execute_query('DELETE FROM Member WHERE MemberId=%s', (member_id,), commit=True)
        flash('Member deleted', 'success')
    except Exception as e:
        flash(str(e), 'danger')
    return redirect(url_for('members_list'))


# ---------- Procedures / Functions GUI ----------
@app.route('/actions/enroll', methods=['GET', 'POST'])
@role_required('admin', 'trainer')
def action_enroll():
    if request.method == 'POST':
        member_id = request.form.get('member_id')
        plan_id = request.form.get('plan_id')
        try:
            execute_query('CALL sp_enroll_member_to_plan(%s,%s)', (member_id, plan_id), commit=True)
            flash('Enrolled successfully', 'success')
        except Exception as e:
            flash(str(e), 'danger')
        return redirect(url_for('action_enroll'))
    members = execute_query('SELECT MemberId, Name FROM Member ORDER BY Name')
    plans = execute_query('SELECT PlanId, Goal FROM WorkOutPlan ORDER BY Goal')
    return render_template('actions/enroll.html', members=members, plans=plans)


@app.route('/actions/make_payment', methods=['GET', 'POST'])
@role_required('admin', 'member')
def action_make_payment():
    if request.method == 'POST':
        try:
            execute_query(
                'CALL sp_make_payment(%s,%s,%s,%s)',
                (
                    request.form.get('member_id'),
                    request.form.get('package_id'),
                    request.form.get('amount'),
                    request.form.get('mode'),
                ),
                commit=True,
            )
            flash('Payment recorded (and audited)', 'success')
        except Exception as e:
            flash(str(e), 'danger')
        return redirect(url_for('action_make_payment'))
    members = execute_query('SELECT MemberId, Name FROM Member ORDER BY Name')
    packages = execute_query('SELECT PackageId, PackageName, Price FROM Package ORDER BY PackageName')
    audits = execute_query('SELECT * FROM Payment_Audit ORDER BY AuditId DESC LIMIT 20')
    return render_template('actions/make_payment.html', members=members, packages=packages, audits=audits)


# ---------- Queries (Nested / Join / Aggregate) ----------
@app.route('/queries')
@role_required('admin', 'member', 'trainer')
def queries_home():
    nested = execute_query(
        """
        SELECT m.MemberId, m.Name
        FROM Member m
        WHERE m.MemberId IN (
          SELECT DISTINCT MemberId FROM WorkOutTracker WHERE Status='Completed'
        ) ORDER BY m.Name
        """
    )
    joinq = execute_query(
        """
        SELECT m.Name AS MemberName, p.PackageName, pay.Amount, pay.TimeStamp
        FROM Payment pay
        JOIN Member m  ON m.MemberId = pay.MemberId
        JOIN Package p ON p.PackageId = pay.PackageId
        ORDER BY pay.TimeStamp DESC
        """
    )
    aggregate = execute_query(
        """
        SELECT m.MemberId, m.Name, COUNT(*) AS CompletedWorkouts
        FROM WorkOutTracker w
        JOIN Member m ON m.MemberId = w.MemberId
        WHERE w.Status='Completed'
        GROUP BY m.MemberId, m.Name
        ORDER BY CompletedWorkouts DESC
        """
    )
    return render_template('queries/index.html', nested=nested, joinq=joinq, aggregate=aggregate)


# ---------- DB Users (real MySQL users with varied privileges) ----------
@app.route('/db-users', methods=['GET', 'POST'])
@role_required('admin')
def db_users():
    result = None
    error = None
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        role = request.form['db_role']  # admin/app_user/trainer_user
        host = request.form.get('host', '%')
        db = os.getenv('DB_NAME', 'GymMemberShip_WorkOutTracker')
        try:
            # Create user
            execute_query(f"CREATE USER IF NOT EXISTS `{username}`@`{host}` IDENTIFIED BY %s", (password,), commit=True)
            # Revoke all first (idempotent try)
            try:
                execute_query(f"REVOKE ALL PRIVILEGES, GRANT OPTION FROM `{username}`@`{host}`", commit=True)
            except Exception:
                pass
            # Grant per role
            if role == 'admin':
                execute_query(f"GRANT ALL PRIVILEGES ON `{db}`.* TO `{username}`@`{host}`", commit=True)
            elif role == 'app_user':
                execute_query(f"GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON `{db}`.* TO `{username}`@`{host}`", commit=True)
            elif role == 'trainer_user':
                # trainer: read most data + execute routines
                execute_query(f"GRANT SELECT, EXECUTE ON `{db}`.* TO `{username}`@`{host}`", commit=True)
            execute_query("FLUSH PRIVILEGES", commit=True)
            result = 'User/privileges updated'
            flash(result, 'success')
        except Exception as e:
            error = str(e)
            flash(error, 'danger')
    return render_template('admin/db_users.html', result=result, error=error)


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.getenv('PORT', 5000)), debug=True)


