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
# Admin will receive email notifications for new user registrations
# To disable registration after creating admin user:
#   1. Set ENABLE_REGISTRATION=false in your .env file
#   2. Restart: docker-compose restart synapse
enable_registration: ${ENABLE_REGISTRATION:-true}
enable_registration_without_verification: ${ENABLE_REGISTRATION:-true}

# Email notifications for admin
email:
  smtp_host: localhost
  smtp_port: 25
  notif_from: "Matrix Server <noreply@${SYNAPSE_SERVER_NAME}>"
  enable_notifs: true
  notif_for_new_users: true

# Allow public rooms
allow_public_rooms_without_auth: false
allow_public_rooms_over_federation: ${ENABLE_FEDERATION:-false}
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
#   2. Restart: docker-compose restart synapse
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

# Start Synapse normally
echo "Starting Synapse server..."
exec /start.py
