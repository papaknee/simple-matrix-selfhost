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
    /start.py generate
    
    echo "Configuration generated successfully at /data/homeserver.yaml"
    echo "You may want to customize this file before proceeding."
fi

# Start Synapse normally
exec /start.py
