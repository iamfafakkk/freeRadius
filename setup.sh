#!/bin/bash

# FreeRADIUS 3 Setup Script for Ubuntu VPS
# This script installs and configures FreeRADIUS 3 on Ubuntu
# Author: Setup Script Generator
# Date: June 8, 2025

set -euo pipefail  # Enhanced error handling

# Generate random database credentials
DB_USER="radius_$(openssl rand -hex 4)"
DB_PASS="$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)"
DB_NAME="radius_$(openssl rand -hex 3)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root."
        error "Please run with: sudo ./setup.sh"
        exit 1
    fi
}

# Check Ubuntu version
check_ubuntu_version() {
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot determine OS version"
        exit 1
    fi
    
    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        error "This script is designed for Ubuntu only"
        exit 1
    fi
    
    log "Detected Ubuntu $VERSION_ID"
}

# Update system packages
update_system() {
    log "Updating system packages..."
    apt update && apt upgrade -y
}

# Install required packages
install_packages() {
    log "Installing FreeRADIUS and required packages..."
    
    # Install FreeRADIUS packages
    apt install -y \
        freeradius \
        freeradius-mysql \
        freeradius-utils \
        freeradius-common \
        freeradius-config \
        mysql-server \
        mysql-client \
        wget \
        curl \
        nano \
        htop \
        ufw
        
    log "Packages installed successfully"
}

# Configure MySQL
configure_mysql() {
    log "Configuring MySQL..."
    
    # Generate root password if MySQL is fresh install
    MYSQL_ROOT_PASS=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
    
    # Set MySQL root password for new installations
    if ! mysql -u root -e "SELECT 1" &>/dev/null; then
        log "Setting MySQL root password..."
        mysql -u root << EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASS';
FLUSH PRIVILEGES;
EOF
        echo "MySQL Root Password: $MYSQL_ROOT_PASS" >> /root/freeradius-credentials.txt
    fi
    
    # Create FreeRADIUS database
    log "Creating FreeRADIUS database..."
    mysql -u root -p$MYSQL_ROOT_PASS << EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

    # Import FreeRADIUS schema
    log "Importing FreeRADIUS schema..."
    mysql -u $DB_USER -p$DB_PASS $DB_NAME < /etc/freeradius/3.0/mods-config/sql/main/mysql/schema.sql
}

# Configure FreeRADIUS
configure_freeradius() {
    log "Configuring FreeRADIUS..."
    
    # Backup original configuration
    cp -r /etc/freeradius/3.0 /etc/freeradius/3.0.backup
    
    # Enable SQL module
    ln -sf /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-enabled/
    
    # Configure SQL module
    tee /etc/freeradius/3.0/mods-available/sql > /dev/null << EOF
sql {
    dialect = "mysql"
    driver = "rlm_sql_mysql"
    
    # Connection info
    server = "localhost"
    port = 3306
    login = "$DB_USER"
    password = "$DB_PASS"
    radius_db = "$DB_NAME"
    
    # Database table configuration
    acct_table1 = "radacct"
    acct_table2 = "radacct"
    postauth_table = "radpostauth"
    authcheck_table = "radcheck"
    authreply_table = "radreply"
    groupcheck_table = "radgroupcheck"
    groupreply_table = "radgroupreply"
    usergroup_table = "radusergroup"
    
    # Remove stale session finding queries
    delete_stale_sessions = yes
    
    pool {
        start = 5
        min = 4
        max = 32
        spare = 3
        uses = 0
        retry_delay = 30
        lifetime = 0
        idle_timeout = 60
    }
    
    # Read database-specific queries
    read_clients = yes
    client_table = "nas"
}
EOF

    # Configure clients
    tee /etc/freeradius/3.0/clients.conf > /dev/null << 'EOF'
client localhost {
    ipaddr = 127.0.0.1
    secret = testing123
    require_message_authenticator = no
    nas_type = other
}

client private-network-1 {
    ipaddr = 192.168.0.0/16
    secret = testing123
}

client private-network-2 {
    ipaddr = 10.0.0.0/8
    secret = testing123
}
EOF

    # Configure default site
    sed -i 's/#.*sql/sql/' /etc/freeradius/3.0/sites-available/default
    sed -i 's/#.*sql/sql/' /etc/freeradius/3.0/sites-available/inner-tunnel
    
    # Set proper permissions
    chown -R freerad:freerad /etc/freeradius/3.0/
    chmod 640 /etc/freeradius/3.0/clients.conf
}

# Configure firewall
configure_firewall() {
    log "Configuring UFW firewall..."
    
    ufw --force enable
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH
    ufw allow ssh
    
    # Allow FreeRADIUS ports
    ufw allow 1812/udp  # Authentication
    ufw allow 1813/udp  # Accounting
    
    ufw reload
    log "Firewall configured"
}

# Test FreeRADIUS - Fix the testing function
test_freeradius() {
    log "Testing FreeRADIUS configuration..."
    
    # Test configuration syntax
    if ! freeradius -C; then
        error "FreeRADIUS configuration test failed!"
        return 1
    fi
    
    # Start service for testing
    systemctl start freeradius
    sleep 3
    
    # Test authentication
    log "Testing user authentication..."
    if echo "User-Name = testuser, Cleartext-Password = testpass" | radclient localhost:1812 auth testing123 | grep -q "Access-Accept"; then
        log "✅ Authentication test successful"
    else
        warning "❌ Authentication test failed"
    fi
}

# Create sample users
create_sample_users() {
    log "Creating sample users..."
    
    mysql -u $DB_USER -p$DB_PASS << EOF
USE $DB_NAME;

INSERT INTO radcheck (username, attribute, op, value) VALUES ('testuser', 'Cleartext-Password', ':=', 'testpass');
INSERT INTO radreply (username, attribute, op, value) VALUES ('testuser', 'Framed-Protocol', '=', 'PPP');

INSERT INTO radcheck (username, attribute, op, value) VALUES ('john', 'Cleartext-Password', ':=', 'johnpass');
INSERT INTO radreply (username, attribute, op, value) VALUES ('john', 'Framed-Protocol', '=', 'PPP');
EOF

    log "Sample users created: testuser/testpass, john/johnpass"
}

# Start and enable services
start_services() {
    log "Starting and enabling services..."
    
    systemctl start mysql
    systemctl enable mysql
    
    systemctl start freeradius
    systemctl enable freeradius
    
    log "Services started and enabled"
}

# Save database credentials
save_credentials() {
    log "Saving database credentials..."
    
    # Create credentials file
    tee /root/freeradius-credentials.txt > /dev/null << EOF
===========================================
FreeRADIUS Installation Credentials
===========================================
Generated on: $(date)

DATABASE CREDENTIALS:
- Database Name: $DB_NAME
- Database User: $DB_USER
- Database Password: $DB_PASS

SAMPLE USERS:
- testuser / testpass
- john / johnpass

IMPORTANT FILES:
- Credentials: /root/freeradius-credentials.txt
- Config: /etc/freeradius/3.0/
- SQL Config: /etc/freeradius/3.0/mods-available/sql

SECURITY REMINDER:
- Change default passwords in production!
- Secure MySQL root password
- Configure firewall rules properly
===========================================
EOF

    chmod 600 /root/freeradius-credentials.txt
    log "✅ Credentials saved to: /root/freeradius-credentials.txt"
}

# Display information
display_info() {
    log "Installation completed successfully!"
    echo ""
    echo "=========================================="
    echo "FreeRADIUS 3 Installation Summary"
    echo "=========================================="
    echo ""
    echo "Services Status:"
    echo "- FreeRADIUS: $(systemctl is-active freeradius)"
    echo "- MySQL: $(systemctl is-active mysql)"
    echo ""
    echo "Configuration Files:"
    echo "- Main config: /etc/freeradius/3.0/"
    echo "- Clients: /etc/freeradius/3.0/clients.conf"
    echo "- SQL config: /etc/freeradius/3.0/mods-available/sql"
    echo ""
    echo "Database Information:"
    echo "- Database: $DB_NAME"
    echo "- Username: $DB_USER"
    echo "- Password: $DB_PASS"
    echo ""
    echo "Sample Users:"
    echo "- testuser / testpass"
    echo "- john / johnpass"
    echo ""
    echo "Useful Commands:"
    echo "- Test config: freeradius -X"
    echo "- Test auth: echo 'User-Name = testuser, Cleartext-Password = testpass' | radclient localhost:1812 auth testing123"
    echo "- View logs: tail -f /var/log/freeradius/radius.log"
    echo "- Restart service: systemctl restart freeradius"
    echo "- View credentials: cat /root/freeradius-credentials.txt"
    echo ""
    warning "🔐 IMPORTANT: Database credentials saved to /root/freeradius-credentials.txt"
    warning "📝 Remember to change default passwords in production!"
    echo ""
    info "🎉 Installation completed! Your FreeRADIUS server is ready to use."
}

# Main installation function
main() {
    log "Starting FreeRADIUS 3 installation on Ubuntu..."
    
    check_root
    check_ubuntu_version
    update_system
    install_packages
    configure_mysql
    configure_freeradius
    configure_firewall
    create_sample_users
    start_services
    save_credentials
    test_freeradius
    display_info
    
    log "FreeRADIUS 3 installation completed successfully!"
}

# Run main function
main "$@"
