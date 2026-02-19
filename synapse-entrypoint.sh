#!/bin/bash
set -e

# Check if homeserver.yaml exists
if [ ! -f /data/homeserver.yaml ]; then
    echo "homeserver.yaml not found. Generating initial configuration..."
    
    # Check if required environment variables are set
    if [ -z "$SYNAPSE_SERVER_NAME" ]; then
        echo "ERROR: SYNAPSE_SERVER_NAME environment variable must be set"
        exit 1
    fi
    
    # Generate the configuration
    # The generate command will create the config and exit
    echo "Generating configuration with server name: $SYNAPSE_SERVER_NAME"
    /start.py generate || {
        echo "ERROR: Failed to generate configuration"
        exit 1
    }
    
    echo "Configuration generated successfully at /data/homeserver.yaml"
    
    # Add PostgreSQL database configuration if POSTGRES_PASSWORD is set
    if [ -n "$POSTGRES_PASSWORD" ]; then
        echo "Adding PostgreSQL database configuration..."
        cat >> /data/homeserver.yaml << EOF

# PostgreSQL Database Configuration (auto-added by entrypoint)
database:
  name: psycopg2
  args:
    user: synapse
    password: ${POSTGRES_PASSWORD}
    database: synapse
    host: postgres
    port: 5432
    cp_min: 5
    cp_max: 10

# Enable registration (controlled by ENABLE_REGISTRATION env var)
# When enabled, anyone with the domain link can create a user profile
# Note: Email notifications require SMTP configuration (see README Step 6)
# To disable registration after creating admin user:
#   1. Set ENABLE_REGISTRATION=false in your .env file
#   2. Restart: docker compose restart synapse
enable_registration: ${ENABLE_REGISTRATION:-true}
enable_registration_without_verification: ${ENABLE_REGISTRATION:-true}

# Email notifications for admin
# Note: This requires a working SMTP server. Configure in Step 6 of README.
email:
  smtp_host: localhost
  smtp_port: 25
  notif_from: "Matrix Server <noreply@${SYNAPSE_SERVER_NAME}>"
  enable_notifs: true
  notif_for_new_users: true

# Allow public rooms
allow_public_rooms_without_auth: false
allow_public_rooms_over_federation: ${ENABLE_FEDERATION:-false}

# Media store configuration
max_upload_size: 50M
media_retention:
  remote_media_lifetime: 90d

# Voice/Video calls
turn_uris: []
turn_shared_secret: ""
turn_user_lifetime: 86400000
turn_allow_guests: true

# Rate limiting
rc_message:
  per_second: 10
  burst_count: 50
rc_registration:
  per_second: 0.17
  burst_count: 3
rc_login:
  address:
    per_second: 0.17
    burst_count: 3
  account:
    per_second: 0.17
    burst_count: 3
  failed_attempts:
    per_second: 0.17
    burst_count: 3
EOF
        
        # Add federation configuration based on ENABLE_FEDERATION
        if [ "${ENABLE_FEDERATION:-false}" = "true" ]; then
            cat >> /data/homeserver.yaml << EOF

# Federation enabled - allow all Matrix servers
federation_domain_whitelist: []
EOF
        else
            cat >> /data/homeserver.yaml << EOF

# Federation disabled - block all federation
# To enable federation:
#   1. Set ENABLE_FEDERATION=true in your .env file
#   2. Restart: docker compose restart synapse
federation_domain_whitelist:
  - ${SYNAPSE_SERVER_NAME}
EOF
        fi
        
        echo "PostgreSQL configuration added successfully"
    else
        echo "WARNING: POSTGRES_PASSWORD not set, using default SQLite database"
        echo "For production use, please configure PostgreSQL in your .env file"
    fi
fi

# Ensure data directory ownership matches UID/GID
if [ -n "$UID" ]; then
    DESIRED_OWNER="$UID:${GID:-991}"
    CURRENT_OWNER=$(stat -c '%u:%g' /data 2>/dev/null || echo "")
    if [ "$CURRENT_OWNER" != "$DESIRED_OWNER" ]; then
        echo "Fixing data directory ownership to $DESIRED_OWNER..."
        chown -R "$DESIRED_OWNER" /data 2>/dev/null || true
    fi
fi

# Start Synapse normally
echo "Starting Synapse server..."
exec /start.py
