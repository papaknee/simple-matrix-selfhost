#!/bin/bash
set -e

echo "Create Admin User for Matrix Server"
echo "====================================="
echo ""

read -p "Enter admin username (e.g., admin): " USERNAME
read -sp "Enter password: " PASSWORD
echo ""
read -sp "Confirm password: " PASSWORD2
echo ""

if [ "$PASSWORD" != "$PASSWORD2" ]; then
    echo "Error: Passwords do not match"
    exit 1
fi

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "Error: Username and password cannot be empty"
    exit 1
fi

echo "Creating admin user..."

# Register the user
docker compose exec -T synapse register_new_matrix_user \
    -c /data/homeserver.yaml \
    -u "$USERNAME" \
    -p "$PASSWORD" \
    -a \
    http://localhost:8008

echo ""
echo "Admin user '$USERNAME' created successfully!"
echo ""
echo "You can now log in at your Element Web interface with:"
echo "Username: @${USERNAME}:$(grep SERVER_NAME .env | cut -d'=' -f2)"
echo "Password: (the password you entered)"
echo ""
