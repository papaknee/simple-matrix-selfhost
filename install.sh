#!/bin/bash
set -e

echo "========================================="
echo "Matrix Server Setup Script"
echo "========================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

# Load environment variables
if [ ! -f .env ]; then
    echo "Error: .env file not found. Please copy .env.example to .env and configure it."
    exit 1
fi

source .env

if [ -z "$MATRIX_DOMAIN" ] || [ "$MATRIX_DOMAIN" == "matrix.example.com" ]; then
    echo "Error: Please configure MATRIX_DOMAIN in .env file"
    exit 1
fi

if [ -z "$SERVER_NAME" ] || [ "$SERVER_NAME" == "example.com" ]; then
    echo "Error: Please configure SERVER_NAME in .env file"
    exit 1
fi

if [ -z "$ADMIN_EMAIL" ] || [ "$ADMIN_EMAIL" == "admin@example.com" ]; then
    echo "Error: Please configure ADMIN_EMAIL in .env file"
    exit 1
fi

echo "Installing dependencies..."
apt-get update
apt-get install -y docker.io docker-compose curl

echo "Enabling Docker service..."
systemctl enable docker
systemctl start docker

echo "Adding user to docker group..."
# Get the actual user who ran sudo (not root)
ACTUAL_USER="${SUDO_USER:-$USER}"
if [ "$ACTUAL_USER" != "root" ]; then
    usermod -aG docker "$ACTUAL_USER"
    echo "User '$ACTUAL_USER' added to docker group"
    echo "NOTE: You may need to log out and back in for group changes to take effect"
    echo "      Or run: newgrp docker"
else
    echo "WARNING: Running as root. Consider running with sudo instead."
fi

echo "Creating directory structure..."
mkdir -p ssl

echo "Replacing placeholders in configuration files..."
sed -i "s/MATRIX_DOMAIN/${MATRIX_DOMAIN}/g" nginx.conf
sed -i "s/MATRIX_DOMAIN/${MATRIX_DOMAIN}/g" element-config.json
sed -i "s/SERVER_NAME/${SERVER_NAME}/g" element-config.json

echo "Generating initial Synapse configuration..."
docker run --rm \
    -v $(pwd)/synapse_data:/data \
    -e SYNAPSE_SERVER_NAME=${SERVER_NAME} \
    -e SYNAPSE_REPORT_STATS=no \
    matrixdotorg/synapse:latest generate

echo "Configuring Synapse to use PostgreSQL..."
cat >> synapse_data/homeserver.yaml << EOF

# PostgreSQL Database Configuration
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
enable_registration: ${ENABLE_REGISTRATION:-true}
enable_registration_without_verification: ${ENABLE_REGISTRATION:-true}

# Email notifications for admin
email:
  smtp_host: localhost
  smtp_port: 25
  notif_from: "Matrix Server <${ADMIN_EMAIL}>"
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

# Federation (controlled by ENABLE_FEDERATION env var)
# When disabled (default), server operates in private/isolated mode
# When enabled, allows communication with other Matrix servers
EOF

if [ "${ENABLE_FEDERATION:-false}" = "true" ]; then
    cat >> synapse_data/homeserver.yaml << EOF
# Federation enabled - allow all Matrix servers
federation_domain_whitelist: []
EOF
else
    cat >> synapse_data/homeserver.yaml << EOF
# Federation disabled - block all federation
federation_domain_whitelist:
  - ${SERVER_NAME}
EOF
fi

echo "Obtaining SSL certificate from Let's Encrypt..."
docker run --rm \
    -v $(pwd)/ssl:/etc/letsencrypt \
    -v $(pwd)/certbot_data:/var/www/certbot \
    -p 80:80 \
    certbot/certbot certonly \
    --standalone \
    --preferred-challenges http \
    --agree-tos \
    --non-interactive \
    --email ${ADMIN_EMAIL} \
    -d ${MATRIX_DOMAIN}

echo "Starting Matrix services..."
docker-compose up -d

echo ""
echo "========================================="
echo "Installation Complete!"
echo "========================================="
echo ""
echo "Your Matrix server should now be running at: https://${MATRIX_DOMAIN}"
echo ""
echo "Next steps:"
echo "1. Wait a few minutes for all services to start"
echo "2. Create an admin user: ./create-admin-user.sh"
echo "3. Access Element Web at: https://${MATRIX_DOMAIN}"
echo "4. Disable public registration in synapse_data/homeserver.yaml"
echo "5. Run: docker-compose restart synapse"
echo ""
echo "To check service status: docker-compose ps"
echo "To view logs: docker-compose logs -f"
echo ""
