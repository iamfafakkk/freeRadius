#!/bin/bash

# FreeRADIUS Credentials Info Script
# Script untuk menampilkan informasi kredensial FreeRADIUS

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
log() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check if credentials file exists
if [[ ! -f "/root/freeradius-credentials.txt" ]]; then
    error "Credentials file not found!"
    error "Make sure FreeRADIUS installation completed successfully."
    exit 1
fi

# Display credentials
echo ""
echo "===========================================."
echo -e "${GREEN}FreeRADIUS Installation Information${NC}"
echo "===========================================."
echo ""

# Read and display credentials
cat /root/freeradius-credentials.txt

echo ""
echo "===========================================."
echo -e "${BLUE}Service Status:${NC}"
echo "===========================================."

# Check service status
services=("freeradius" "mysql" "apache2")
for service in "${services[@]}"; do
    if systemctl is-active --quiet $service; then
        echo -e "✅ $service: ${GREEN}Running${NC}"
    else
        echo -e "❌ $service: ${RED}Stopped${NC}"
    fi
done

echo ""
echo "===========================================."
echo -e "${BLUE}Quick Test Commands:${NC}"
echo "===========================================."
echo ""
echo "Test Authentication:"
echo "echo 'User-Name = testuser, Cleartext-Password = testpass' | radclient localhost:1812 auth testing123"
echo ""
echo "Check FreeRADIUS Debug:"
echo "freeradius -X"
echo ""
echo "View Logs:"
echo "tail -f /var/log/freeradius/radius.log"
echo ""
echo "Database Access:"
# Get database credentials from file
DB_NAME=$(grep "Database Name:" /root/freeradius-credentials.txt | cut -d: -f2 | xargs)
DB_USER=$(grep "Database User:" /root/freeradius-credentials.txt | cut -d: -f2 | xargs)
echo "mysql -u $DB_USER -p $DB_NAME"
echo ""

echo "===========================================."
echo -e "${YELLOW}Security Reminders:${NC}"
echo "===========================================."
echo "🔐 Change default daloRADIUS password (administrator/radius)"
echo "🔒 Setup SSL certificate for web interface"
echo "🛡️  Configure firewall for production use"
echo "📝 Backup database credentials securely"
echo "🔄 Update system packages regularly"
echo ""

warning "Keep the credentials file secure: /root/freeradius-credentials.txt"
info "For help, run: ./maintenance.sh help"
