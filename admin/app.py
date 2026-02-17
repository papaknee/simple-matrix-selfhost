#!/usr/bin/env python3
"""
Matrix Server Admin Console
A simple web interface for managing Matrix server operations.
"""

import os
import json
import subprocess
import logging
import re
import yaml
from datetime import datetime
from pathlib import Path
from functools import wraps

from flask import Flask, render_template, request, jsonify, session, redirect, url_for
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
import boto3
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.secret_key = os.environ.get('ADMIN_CONSOLE_SECRET_KEY', 'change-this-secret-key')

# Configuration
ADMIN_USERNAME = os.environ.get('ADMIN_CONSOLE_USERNAME', 'admin')
ADMIN_PASSWORD = os.environ.get('ADMIN_CONSOLE_PASSWORD', 'admin')
PROJECT_DIR = Path('/app/project')
DOCKER_COMPOSE_FILE = PROJECT_DIR / 'docker-compose.yml'
SCHEDULES_FILE = Path('/app/data/schedules.json')
ENV_FILE = PROJECT_DIR / '.env'
HOMESERVER_YAML = PROJECT_DIR / 'synapse_data' / 'homeserver.yaml'

# Constants
MAX_LOG_LINES = 10000
DEFAULT_LOG_LINES = 100

# Warn about insecure defaults
if app.secret_key == 'change-this-secret-key':
    logger.warning("Using default secret key - this is insecure! Set ADMIN_CONSOLE_SECRET_KEY in .env")
if ADMIN_PASSWORD == 'admin':
    logger.warning("Using default admin password - this is insecure! Set ADMIN_CONSOLE_PASSWORD in .env")

# Initialize scheduler
scheduler = BackgroundScheduler()
scheduler.start()


def login_required(f):
    """Decorator to require login for routes."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not session.get('logged_in'):
            return jsonify({'error': 'Authentication required'}), 401
        return f(*args, **kwargs)
    return decorated_function


def run_command(cmd, cwd=None):
    """Run a shell command and return output."""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            cwd=cwd or PROJECT_DIR,
            capture_output=True,
            text=True,
            timeout=300
        )
        return {
            'success': result.returncode == 0,
            'stdout': result.stdout,
            'stderr': result.stderr,
            'returncode': result.returncode
        }
    except subprocess.TimeoutExpired:
        return {
            'success': False,
            'stdout': '',
            'stderr': 'Command timed out after 5 minutes',
            'returncode': -1
        }
    except Exception as e:
        logger.error(f"Command failed: {e}")
        return {
            'success': False,
            'stdout': '',
            'stderr': str(e),
            'returncode': -1
        }


def sanitize_service_name(service):
    """Sanitize service name to prevent command injection."""
    if not service:
        return ''
    # Only allow alphanumeric characters, hyphens, and underscores
    if re.match(r'^[a-zA-Z0-9_-]+$', service):
        return service
    raise ValueError(f"Invalid service name: {service}")


def load_schedules():
    """Load scheduled tasks from file."""
    if SCHEDULES_FILE.exists():
        try:
            with open(SCHEDULES_FILE, 'r') as f:
                return json.load(f)
        except Exception as e:
            logger.error(f"Failed to load schedules: {e}")
    return []


def save_schedules(schedules):
    """Save scheduled tasks to file."""
    try:
        SCHEDULES_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(SCHEDULES_FILE, 'w') as f:
            json.dump(schedules, f, indent=2)
        return True
    except Exception as e:
        logger.error(f"Failed to save schedules: {e}")
        return False


def create_scheduled_task(task_type):
    """Create a scheduled task function for a specific task type."""
    if task_type == 'update':
        def task():
            return run_command('docker compose pull && docker compose up -d')
        return task
    elif task_type == 'restart':
        def task():
            return run_command('docker compose restart')
        return task
    elif task_type == 'backup':
        return backup_to_s3
    else:
        raise ValueError(f"Invalid task type: {task_type}")


def backup_to_s3():
    """Create a backup and upload to S3."""
    try:
        # Create backup timestamp
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_filename = f'matrix-backup-{timestamp}.tar.gz'
        backup_path = f'/tmp/{backup_filename}'
        
        # Create backup (synapse_data only, .env not available in container)
        logger.info(f"Creating backup: {backup_filename}")
        result = run_command(
            f'tar -czf {backup_path} -C {PROJECT_DIR} synapse_data',
            cwd=PROJECT_DIR
        )
        
        if not result['success']:
            logger.error(f"Backup creation failed: {result['stderr']}")
            return {'success': False, 'error': 'Failed to create backup'}
        
        # Upload to S3 if configured
        aws_bucket = os.environ.get('AWS_S3_BUCKET')
        if aws_bucket:
            try:
                s3_client = boto3.client(
                    's3',
                    aws_access_key_id=os.environ.get('AWS_ACCESS_KEY_ID'),
                    aws_secret_access_key=os.environ.get('AWS_SECRET_ACCESS_KEY'),
                    region_name=os.environ.get('AWS_REGION', 'us-east-1')
                )
                
                logger.info(f"Uploading to S3: {aws_bucket}/{backup_filename}")
                s3_client.upload_file(backup_path, aws_bucket, backup_filename)
                
                # Clean up local backup
                os.remove(backup_path)
                
                return {
                    'success': True,
                    'message': f'Backup uploaded to S3: {backup_filename}',
                    'filename': backup_filename
                }
            except ClientError as e:
                logger.error(f"S3 upload failed: {e}")
                return {'success': False, 'error': f'S3 upload failed: {str(e)}'}
        else:
            return {
                'success': True,
                'message': f'Backup created locally: {backup_path}',
                'filename': backup_filename,
                'path': backup_path
            }
    except Exception as e:
        logger.error(f"Backup failed: {e}")
        return {'success': False, 'error': str(e)}


def read_env_file():
    """Read .env file and return as dictionary."""
    env_vars = {}
    if ENV_FILE.exists():
        try:
            with open(ENV_FILE, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#') and '=' in line:
                        key, value = line.split('=', 1)
                        # Only strip whitespace from key, preserve value as-is
                        env_vars[key.strip()] = value
        except Exception as e:
            logger.error(f"Failed to read .env file: {e}")
    return env_vars


def update_env_file(key, value):
    """Update a specific key in the .env file."""
    try:
        if not ENV_FILE.exists():
            logger.error(".env file does not exist")
            return False
        
        # Read all lines
        with open(ENV_FILE, 'r') as f:
            lines = f.readlines()
        
        # Find and update the key
        key_found = False
        updated_lines = []
        for line in lines:
            if line.strip() and not line.strip().startswith('#') and '=' in line:
                current_key = line.split('=', 1)[0].strip()
                if current_key == key:
                    updated_lines.append(f"{key}={value}\n")
                    key_found = True
                else:
                    updated_lines.append(line)
            else:
                updated_lines.append(line)
        
        # If key not found, append it
        if not key_found:
            updated_lines.append(f"\n# Auto-added by admin console\n{key}={value}\n")
        
        # Write back
        with open(ENV_FILE, 'w') as f:
            f.writelines(updated_lines)
        
        return True
    except Exception as e:
        logger.error(f"Failed to update .env file: {e}")
        return False


def get_homeserver_config_value(key):
    """Read a value from homeserver.yaml."""
    try:
        if not HOMESERVER_YAML.exists():
            return None
        
        with open(HOMESERVER_YAML, 'r') as f:
            config = yaml.safe_load(f)
        
        return config.get(key)
    except Exception as e:
        logger.error(f"Failed to read homeserver.yaml: {e}")
        return None


@app.route('/')
def index():
    """Admin console home page."""
    if not session.get('logged_in'):
        return redirect(url_for('login'))
    return render_template('index.html')


@app.route('/login', methods=['GET', 'POST'])
def login():
    """Login page."""
    if request.method == 'POST':
        data = request.get_json()
        username = data.get('username')
        password = data.get('password')
        
        if username == ADMIN_USERNAME and password == ADMIN_PASSWORD:
            session['logged_in'] = True
            return jsonify({'success': True})
        else:
            return jsonify({'success': False, 'error': 'Invalid credentials'}), 401
    
    return render_template('login.html')


@app.route('/logout')
def logout():
    """Logout."""
    session.pop('logged_in', None)
    return redirect(url_for('login'))


@app.route('/api/status')
@login_required
def get_status():
    """Get status of all services."""
    result = run_command('docker compose ps --format json')
    
    if not result['success']:
        return jsonify({'error': result['stderr']}), 500
    
    try:
        # Parse docker compose ps output
        services = []
        if result['stdout'].strip():
            for line in result['stdout'].strip().split('\n'):
                if line:
                    service_info = json.loads(line)
                    services.append({
                        'name': service_info.get('Service', service_info.get('Name', '')),
                        'state': service_info.get('State', ''),
                        'status': service_info.get('Status', ''),
                    })
        
        return jsonify({'services': services})
    except Exception as e:
        logger.error(f"Failed to parse service status: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/update-repo', methods=['POST'])
@login_required
def update_repo():
    """Pull latest changes from GitHub repository."""
    logger.info("Pulling latest changes from repository")
    
    # Fetch and pull
    fetch_result = run_command('git fetch origin')
    if not fetch_result['success']:
        return jsonify({
            'success': False,
            'error': f"Git fetch failed: {fetch_result['stderr']}"
        }), 500
    
    pull_result = run_command('git pull origin main')
    
    return jsonify({
        'success': pull_result['success'],
        'output': pull_result['stdout'] + '\n' + pull_result['stderr']
    })


@app.route('/api/update-images', methods=['POST'])
@login_required
def update_images():
    """Pull latest Docker images."""
    data = request.get_json() or {}
    service = data.get('service', '')
    
    logger.info(f"Pulling Docker images for: {service or 'all services'}")
    
    try:
        if service:
            service = sanitize_service_name(service)
        cmd = f'docker compose pull {service}'.strip()
        result = run_command(cmd)
        
        return jsonify({
            'success': result['success'],
            'output': result['stdout'] + '\n' + result['stderr']
        })
    except ValueError as e:
        return jsonify({'success': False, 'error': str(e)}), 400


@app.route('/api/service/<action>', methods=['POST'])
@login_required
def service_action(action):
    """Start, stop, or restart a service."""
    data = request.get_json() or {}
    service = data.get('service', '')
    
    if action not in ['start', 'stop', 'restart']:
        return jsonify({'error': 'Invalid action'}), 400
    
    logger.info(f"Action '{action}' on service: {service or 'all'}")
    
    try:
        if service:
            service = sanitize_service_name(service)
        cmd = f'docker compose {action} {service}'.strip()
        result = run_command(cmd)
        
        return jsonify({
            'success': result['success'],
            'output': result['stdout'] + '\n' + result['stderr']
        })
    except ValueError as e:
        return jsonify({'success': False, 'error': str(e)}), 400


@app.route('/api/logs/<service>')
@login_required
def get_logs(service):
    """Get logs for a service."""
    lines = request.args.get('lines', str(DEFAULT_LOG_LINES))
    
    logger.info(f"Getting logs for service: {service}")
    
    try:
        service = sanitize_service_name(service)
        # Sanitize lines parameter to prevent injection
        try:
            lines_int = int(lines)
            if lines_int < 1 or lines_int > MAX_LOG_LINES:
                lines_int = DEFAULT_LOG_LINES
        except ValueError:
            lines_int = DEFAULT_LOG_LINES
        
        result = run_command(f'docker compose logs --tail={lines_int} {service}')
        
        return jsonify({
            'success': result['success'],
            'logs': result['stdout'] if result['success'] else result['stderr']
        })
    except ValueError as e:
        return jsonify({'success': False, 'error': str(e)}), 400


@app.route('/api/backup', methods=['POST'])
@login_required
def create_backup():
    """Create and optionally upload backup to S3."""
    logger.info("Creating backup")
    
    result = backup_to_s3()
    
    if result['success']:
        return jsonify(result)
    else:
        return jsonify(result), 500


@app.route('/api/schedules', methods=['GET'])
@login_required
def get_schedules():
    """Get all scheduled tasks."""
    schedules = load_schedules()
    
    # Get currently running jobs from APScheduler
    jobs = []
    for job in scheduler.get_jobs():
        jobs.append({
            'id': job.id,
            'name': job.name,
            'next_run': job.next_run_time.isoformat() if job.next_run_time else None
        })
    
    return jsonify({
        'schedules': schedules,
        'active_jobs': jobs
    })


@app.route('/api/schedules', methods=['POST'])
@login_required
def add_schedule():
    """Add a new scheduled task."""
    data = request.get_json()
    
    task_type = data.get('type')  # 'update', 'restart', 'backup'
    schedule = data.get('schedule')  # cron expression or simple format
    enabled = data.get('enabled', True)
    
    if not task_type or not schedule:
        return jsonify({'error': 'Missing required fields'}), 400
    
    # Parse schedule (simple format: "daily", "weekly", "monthly" or cron)
    try:
        if schedule == 'daily':
            trigger = CronTrigger(hour=3, minute=0)
        elif schedule == 'weekly':
            trigger = CronTrigger(day_of_week='sun', hour=3, minute=0)
        elif schedule == 'monthly':
            trigger = CronTrigger(day=1, hour=3, minute=0)
        else:
            # Assume it's a cron expression
            parts = schedule.split()
            if len(parts) == 5:
                trigger = CronTrigger(
                    minute=parts[0],
                    hour=parts[1],
                    day=parts[2],
                    month=parts[3],
                    day_of_week=parts[4]
                )
            else:
                return jsonify({'error': 'Invalid schedule format'}), 400
        
        # Create scheduled task function
        try:
            func = create_scheduled_task(task_type)
        except ValueError as e:
            return jsonify({'error': str(e)}), 400
        
        # Create schedule entry
        schedule_id = f"{task_type}_{datetime.now().strftime('%Y%m%d%H%M%S')}"
        
        if enabled:
            # Add job to scheduler
            scheduler.add_job(
                func=func,
                trigger=trigger,
                id=schedule_id,
                name=f"{task_type.title()} - {schedule}",
                replace_existing=True
            )
        
        # Save to file
        schedules = load_schedules()
        schedules.append({
            'id': schedule_id,
            'type': task_type,
            'schedule': schedule,
            'enabled': enabled,
            'created': datetime.now().isoformat()
        })
        save_schedules(schedules)
        
        return jsonify({
            'success': True,
            'schedule_id': schedule_id
        })
    except Exception as e:
        logger.error(f"Failed to add schedule: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/schedules/<schedule_id>', methods=['DELETE'])
@login_required
def delete_schedule(schedule_id):
    """Delete a scheduled task."""
    try:
        # Remove from scheduler
        if scheduler.get_job(schedule_id):
            scheduler.remove_job(schedule_id)
        
        # Remove from file
        schedules = load_schedules()
        schedules = [s for s in schedules if s['id'] != schedule_id]
        save_schedules(schedules)
        
        return jsonify({'success': True})
    except Exception as e:
        logger.error(f"Failed to delete schedule: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/config/server-settings', methods=['GET'])
@login_required
def get_server_settings():
    """Get current registration and federation settings."""
    try:
        env_vars = read_env_file()
        
        # Get values from .env file (or defaults)
        # Strip whitespace from values for boolean comparison
        enable_registration = env_vars.get('ENABLE_REGISTRATION', 'true').strip().lower() == 'true'
        enable_federation = env_vars.get('ENABLE_FEDERATION', 'false').strip().lower() == 'true'
        
        # Try to get actual values from homeserver.yaml as well
        actual_registration = get_homeserver_config_value('enable_registration')
        actual_federation_whitelist = get_homeserver_config_value('federation_domain_whitelist')
        
        # Empty list means all servers are allowed (federation enabled)
        # Non-empty list or None means federation is restricted/disabled
        actual_federation_allows_all = actual_federation_whitelist == [] if actual_federation_whitelist is not None else None
        
        return jsonify({
            'success': True,
            'settings': {
                'enable_registration': enable_registration,
                'enable_federation': enable_federation,
                'actual_registration': actual_registration,
                'actual_federation_enabled': actual_federation_allows_all
            }
        })
    except Exception as e:
        logger.error(f"Failed to get server settings: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/config/server-settings', methods=['POST'])
@login_required
def update_server_settings():
    """Update registration and federation settings."""
    try:
        data = request.get_json()
        enable_registration = data.get('enable_registration')
        enable_federation = data.get('enable_federation')
        
        # Validate inputs
        if enable_registration is None and enable_federation is None:
            return jsonify({'error': 'No settings provided'}), 400
        
        # Update .env file
        if enable_registration is not None:
            value = 'true' if enable_registration else 'false'
            if not update_env_file('ENABLE_REGISTRATION', value):
                return jsonify({'error': 'Failed to update ENABLE_REGISTRATION in .env'}), 500
            logger.info(f"Updated ENABLE_REGISTRATION to {value}")
        
        if enable_federation is not None:
            value = 'true' if enable_federation else 'false'
            if not update_env_file('ENABLE_FEDERATION', value):
                return jsonify({'error': 'Failed to update ENABLE_FEDERATION in .env'}), 500
            logger.info(f"Updated ENABLE_FEDERATION to {value}")
        
        # Restart synapse to apply changes
        logger.info("Restarting Synapse to apply configuration changes")
        restart_result = run_command('docker compose restart synapse')
        
        if not restart_result['success']:
            return jsonify({
                'success': False,
                'warning': 'Settings updated in .env but Synapse restart failed. Please restart manually.',
                'error': restart_result['stderr']
            }), 500
        
        return jsonify({
            'success': True,
            'message': 'Settings updated successfully. Synapse is restarting...'
        })
    except Exception as e:
        logger.error(f"Failed to update server settings: {e}")
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    # Restore schedules on startup
    schedules = load_schedules()
    for schedule in schedules:
        if schedule.get('enabled'):
            try:
                task_type = schedule['type']
                schedule_str = schedule['schedule']
                
                # Re-add job to scheduler
                if schedule_str == 'daily':
                    trigger = CronTrigger(hour=3, minute=0)
                elif schedule_str == 'weekly':
                    trigger = CronTrigger(day_of_week='sun', hour=3, minute=0)
                elif schedule_str == 'monthly':
                    trigger = CronTrigger(day=1, hour=3, minute=0)
                else:
                    parts = schedule_str.split()
                    if len(parts) == 5:
                        trigger = CronTrigger(
                            minute=parts[0],
                            hour=parts[1],
                            day=parts[2],
                            month=parts[3],
                            day_of_week=parts[4]
                        )
                    else:
                        continue
                
                # Create scheduled task function
                try:
                    func = create_scheduled_task(task_type)
                except ValueError:
                    continue
                
                scheduler.add_job(
                    func=func,
                    trigger=trigger,
                    id=schedule['id'],
                    name=f"{task_type.title()} - {schedule_str}",
                    replace_existing=True
                )
                logger.info(f"Restored schedule: {schedule['id']}")
            except Exception as e:
                logger.error(f"Failed to restore schedule {schedule.get('id')}: {e}")
    
    app.run(host='0.0.0.0', port=5000)
