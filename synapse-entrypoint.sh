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

# Enable registration (set to false after creating admin user)
# WARNING: This allows anyone to create accounts on your server!
# After creating your admin user, disable registration in homeserver.yaml:
#   1. Edit synapse_data/homeserver.yaml
#   2. Set: enable_registration: false
#   3. Restart: docker-compose restart synapse
enable_registration: true
enable_registration_without_verification: true
EOF
        echo "PostgreSQL configuration added successfully"
    else
        echo "WARNING: POSTGRES_PASSWORD not set, using default SQLite database"
        echo "For production use, please configure PostgreSQL in your .env file"
    fi
fi

# Start Synapse normally
echo "Starting Synapse server..."
exec /start.py
