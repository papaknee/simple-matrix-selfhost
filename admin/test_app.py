"""Tests for admin console login and user statistics."""

import json
import sys
import os
from datetime import datetime
from unittest.mock import patch, MagicMock

import pytest

# Stub out modules not needed for testing
sys.modules['psycopg2'] = MagicMock()
sys.modules['boto3'] = MagicMock()
sys.modules['botocore'] = MagicMock()
sys.modules['botocore.exceptions'] = MagicMock()

os.environ.setdefault('ADMIN_CONSOLE_USERNAME', 'admin')
os.environ.setdefault('ADMIN_CONSOLE_PASSWORD', 'testpass')
os.environ.setdefault('ADMIN_CONSOLE_SECRET_KEY', 'test-secret')

from app import app, SYNAPSE_TIMESTAMP_MULTIPLIER


@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


class TestLogin:
    """Tests for the login endpoint."""

    def test_login_get_returns_page(self, client):
        """GET /login should return the login page."""
        resp = client.get('/login')
        assert resp.status_code == 200

    def test_login_post_valid_credentials(self, client):
        """POST /login with valid JSON credentials should succeed."""
        resp = client.post('/login',
                           data=json.dumps({'username': 'admin', 'password': 'testpass'}),
                           content_type='application/json')
        assert resp.status_code == 200
        data = resp.get_json()
        assert data['success'] is True

    def test_login_post_invalid_credentials(self, client):
        """POST /login with wrong credentials should return 401."""
        resp = client.post('/login',
                           data=json.dumps({'username': 'admin', 'password': 'wrong'}),
                           content_type='application/json')
        assert resp.status_code == 401
        data = resp.get_json()
        assert data['success'] is False

    def test_login_post_non_json_body(self, client):
        """POST /login without JSON content-type should return 400, not crash."""
        resp = client.post('/login',
                           data='username=admin&password=testpass',
                           content_type='application/x-www-form-urlencoded')
        # get_json(silent=True) returns None for non-JSON content
        assert resp.status_code == 400
        data = resp.get_json()
        assert data['success'] is False
        assert 'Invalid request format' in data['error']

    def test_login_post_empty_body(self, client):
        """POST /login with empty body should return 400, not crash."""
        resp = client.post('/login',
                           data='',
                           content_type='application/json')
        assert resp.status_code == 400

    def test_login_post_null_json_body(self, client):
        """POST /login with JSON null body should return 400, not crash."""
        resp = client.post('/login',
                           data=json.dumps(None),
                           content_type='application/json')
        assert resp.status_code == 400
        data = resp.get_json()
        assert data['success'] is False


class TestCreationTimestamp:
    """Tests for correct handling of Synapse's creation_ts (seconds, not ms)."""

    def test_creation_ts_in_seconds_produces_valid_date(self):
        """creation_ts stored in seconds should yield a recent date, not 1970."""
        # Synapse stores creation_ts in seconds since epoch
        creation_ts = 1708000000  # ~2024-02-15
        result = datetime.fromtimestamp(creation_ts).strftime('%Y-%m-%d %H:%M:%S')
        assert result.startswith('2024-02-1')

    def test_creation_ts_divided_by_1000_is_wrong(self):
        """Dividing a seconds timestamp by 1000 gives a 1970 date (the old bug)."""
        creation_ts = 1708000000  # ~2024-02-15 in seconds
        wrong_result = datetime.fromtimestamp(creation_ts / SYNAPSE_TIMESTAMP_MULTIPLIER).strftime('%Y-%m-%d')
        assert wrong_result.startswith('1970-')

    def test_last_seen_in_milliseconds_needs_division(self):
        """last_seen from user_ips is in milliseconds, division by 1000 is correct."""
        last_seen_ms = 1708000000000  # ~2024-02-15 in milliseconds
        result = datetime.fromtimestamp(last_seen_ms / SYNAPSE_TIMESTAMP_MULTIPLIER).strftime('%Y-%m-%d %H:%M:%S')
        assert result.startswith('2024-02-1')
