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
fi

# Start Synapse normally
echo "Starting Synapse server..."
exec /start.py
