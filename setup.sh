#!/bin/bash
set -e

# =============================================================================
# Interactive Matrix Server Setup
# =============================================================================
# This script sets up a Matrix server on a fresh Ubuntu instance.
# It can be run directly via curl after networking and DNS are configured:
#
#   curl -sSL https://raw.githubusercontent.com/papaknee/simple-matrix-selfhost/main/setup.sh | sudo bash
#
# Or cloned and run locally:
#
#   git clone https://github.com/papaknee/simple-matrix-selfhost.git
#   cd simple-matrix-selfhost
#   sudo ./setup.sh
#
# What this script does:
#   1. Installs git (if needed)
#   2. Clones the repository to /opt/matrix-server
#   3. Prompts you for configuration values (domain, email, passwords)
#   4. Runs the full installation (Docker, SSL certs, Synapse, etc.)
# =============================================================================

INSTALL_DIR="/opt/matrix-server"
REPO_URL="https://github.com/papaknee/simple-matrix-selfhost.git"
REPO_BRANCH="main"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

echo ""
echo "========================================="
echo "  Matrix Server Interactive Setup"
echo "========================================="
echo ""
echo "This will set up a complete Matrix chat server with:"
echo "  - Synapse (Matrix homeserver)"
echo "  - Element Web (chat client)"
echo "  - PostgreSQL (database)"
echo "  - Nginx (reverse proxy with SSL)"
echo "  - Admin Console (web management)"
echo ""
echo "Before continuing, make sure you have:"
echo "  1. Created your Lightsail instance"
echo "  2. Attached a static IP"
echo "  3. Opened firewall ports (80, 443, 8448)"
echo "  4. Pointed your domain's DNS to the static IP"
echo "  5. Waited for DNS to propagate (5-10 minutes)"
echo ""
read -p "Ready to continue? (y/n): " READY
if [[ "$READY" != "y" && "$READY" != "Y" ]]; then
    echo "Setup cancelled. Run this script again when ready."
    exit 0
fi

echo ""
echo "-----------------------------------------"
echo "  Step 1: Server Configuration"
echo "-----------------------------------------"
echo ""

# Prompt for domain
while true; do
    read -p "Enter your Matrix domain (e.g., matrix.yourdomain.com): " MATRIX_DOMAIN
    if [[ -z "$MATRIX_DOMAIN" || "$MATRIX_DOMAIN" == *" "* ]]; then
        echo "Error: Domain cannot be empty or contain spaces."
    else
        break
    fi
done

# Derive SERVER_NAME from MATRIX_DOMAIN (strip first subdomain)
DEFAULT_SERVER_NAME=$(echo "$MATRIX_DOMAIN" | sed 's/^[^.]*\.//')
read -p "Enter your server name [$DEFAULT_SERVER_NAME]: " SERVER_NAME
SERVER_NAME="${SERVER_NAME:-$DEFAULT_SERVER_NAME}"

# Prompt for email
while true; do
    read -p "Enter admin email (for SSL certificates and notifications): " ADMIN_EMAIL
    if [[ -z "$ADMIN_EMAIL" || ! "$ADMIN_EMAIL" == *"@"* ]]; then
        echo "Error: Please enter a valid email address."
    else
        break
    fi
done

echo ""
echo "-----------------------------------------"
echo "  Step 2: Passwords"
echo "-----------------------------------------"
echo ""

# Database password
while true; do
    read -sp "Enter a database password (press Enter to auto-generate): " POSTGRES_PASSWORD
    echo ""
    if [[ -z "$POSTGRES_PASSWORD" ]]; then
        POSTGRES_PASSWORD=$(openssl rand -hex 16)
        echo "Auto-generated database password."
    fi
    break
done

# Admin console credentials
read -p "Enter admin console username [admin]: " ADMIN_CONSOLE_USERNAME
ADMIN_CONSOLE_USERNAME="${ADMIN_CONSOLE_USERNAME:-admin}"

while true; do
    read -sp "Enter admin console password: " ADMIN_CONSOLE_PASSWORD
    echo ""
    if [[ -z "$ADMIN_CONSOLE_PASSWORD" ]]; then
        echo "Error: Password cannot be empty."
    else
        break
    fi
done

# Auto-generate secret key
ADMIN_CONSOLE_SECRET_KEY=$(openssl rand -hex 32)

echo ""
echo "-----------------------------------------"
echo "  Step 3: Optional Settings"
echo "-----------------------------------------"
echo ""

read -p "Enable user registration? (y/n) [y]: " ENABLE_REG
if [[ "$ENABLE_REG" == "n" || "$ENABLE_REG" == "N" ]]; then
    ENABLE_REGISTRATION="false"
else
    ENABLE_REGISTRATION="true"
fi

read -p "Enable federation with other Matrix servers? (y/n) [n]: " ENABLE_FED
if [[ "$ENABLE_FED" == "y" || "$ENABLE_FED" == "Y" ]]; then
    ENABLE_FEDERATION="true"
else
    ENABLE_FEDERATION="false"
fi

echo ""
echo "-----------------------------------------"
echo "  Configuration Summary"
echo "-----------------------------------------"
echo ""
echo "  Domain:        $MATRIX_DOMAIN"
echo "  Server Name:   $SERVER_NAME"
echo "  Admin Email:   $ADMIN_EMAIL"
echo "  Console User:  $ADMIN_CONSOLE_USERNAME"
echo "  Registration:  $ENABLE_REGISTRATION"
echo "  Federation:    $ENABLE_FEDERATION"
echo ""
read -p "Proceed with installation? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Setup cancelled."
    exit 0
fi

echo ""
echo "-----------------------------------------"
echo "  Installing..."
echo "-----------------------------------------"
echo ""

# Install git if needed
if ! command -v git &> /dev/null; then
    echo "Installing git..."
    apt-get update -y
    apt-get install -y git
fi

# Clone or update repository
if [ -d "$INSTALL_DIR" ]; then
    echo "Directory $INSTALL_DIR already exists, updating..."
    cd "$INSTALL_DIR"
    git pull origin "$REPO_BRANCH" || true
else
    echo "Cloning repository..."
    git clone --branch "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# Create .env file
echo "Creating configuration file..."
cat > "$INSTALL_DIR/.env" << EOF
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
MATRIX_DOMAIN=$MATRIX_DOMAIN
ADMIN_EMAIL=$ADMIN_EMAIL
SERVER_NAME=$SERVER_NAME
ADMIN_CONSOLE_USERNAME=$ADMIN_CONSOLE_USERNAME
ADMIN_CONSOLE_PASSWORD=$ADMIN_CONSOLE_PASSWORD
ADMIN_CONSOLE_SECRET_KEY=$ADMIN_CONSOLE_SECRET_KEY
ENABLE_REGISTRATION=$ENABLE_REGISTRATION
ENABLE_FEDERATION=$ENABLE_FEDERATION
EOF

# Run the main installation
echo "Running installation..."
chmod +x install.sh create-admin-user.sh update.sh
bash install.sh

echo ""
echo "========================================="
echo "  Setup Complete!"
echo "========================================="
echo ""
echo "Your Matrix server is now running at:"
echo "  Element Web:    https://$MATRIX_DOMAIN"
echo "  Admin Console:  https://$MATRIX_DOMAIN/admin/"
echo ""
echo "Next step - create your admin user:"
echo "  cd $INSTALL_DIR"
echo "  sudo ./create-admin-user.sh"
echo ""
echo "Then log in to Element Web with:"
echo "  Username: @yourusername:$SERVER_NAME"
echo "  Password: (the password you set during user creation)"
echo ""
