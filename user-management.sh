#!/bin/bash

# FreeRADIUS Bulk User Management Script
# Script untuk menambah, menghapus, dan mengelola user secara bulk

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Database credentials - read from credentials file
get_db_credentials() {
    if [[ -f "/root/freeradius-credentials.txt" ]]; then
        DB_NAME=$(grep "Database Name:" /root/freeradius-credentials.txt | cut -d: -f2 | xargs)
        DB_USER=$(grep "Database User:" /root/freeradius-credentials.txt | cut -d: -f2 | xargs)
        DB_PASS=$(grep "Database Password:" /root/freeradius-credentials.txt | cut -d: -f2 | xargs)
    else
        error "Credentials file not found! Make sure FreeRADIUS is installed properly."
        exit 1
    fi
}

# Initialize database credentials
get_db_credentials

# Functions
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

# Add single user
add_user() {
    local username=$1
    local password=$2
    local group=${3:-"default"}
    
    if [[ -z "$username" || -z "$password" ]]; then
        error "Username and password are required"
        return 1
    fi
    
    # Check if user already exists
    existing=$(mysql -u $DB_USER -p$DB_PASS -se "SELECT COUNT(*) FROM $DB_NAME.radcheck WHERE username='$username';")
    
    if [ "$existing" -gt 0 ]; then
        warning "User $username already exists"
        return 1
    fi
    
    # Add user
    mysql -u $DB_USER -p$DB_PASS -e "
    USE $DB_NAME;
    INSERT INTO radcheck (username, attribute, op, value) VALUES ('$username', 'Cleartext-Password', ':=', '$password');
    INSERT INTO radreply (username, attribute, op, value) VALUES ('$username', 'Framed-Protocol', '=', 'PPP');
    INSERT INTO radusergroup (username, groupname, priority) VALUES ('$username', '$group', 1);
    "
    
    if [ $? -eq 0 ]; then
        log "✅ User $username added successfully"
    else
        error "❌ Failed to add user $username"
    fi
}

# Delete user
delete_user() {
    local username=$1
    
    if [[ -z "$username" ]]; then
        error "Username is required"
        return 1
    fi
    
    # Check if user exists
    existing=$(mysql -u $DB_USER -p$DB_PASS -se "SELECT COUNT(*) FROM $DB_NAME.radcheck WHERE username='$username';")
    
    if [ "$existing" -eq 0 ]; then
        warning "User $username does not exist"
        return 1
    fi
    
    # Delete user
    mysql -u $DB_USER -p$DB_PASS -e "
    USE $DB_NAME;
    DELETE FROM radcheck WHERE username='$username';
    DELETE FROM radreply WHERE username='$username';
    DELETE FROM radusergroup WHERE username='$username';
    DELETE FROM radacct WHERE username='$username';
    DELETE FROM radpostauth WHERE username='$username';
    "
    
    if [ $? -eq 0 ]; then
        log "✅ User $username deleted successfully"
    else
        error "❌ Failed to delete user $username"
    fi
}

# List users
list_users() {
    log "Current FreeRADIUS Users:"
    mysql -u $DB_USER -p$DB_PASS -e "
    SELECT 
        rc.username,
        rc.value as password,
        COALESCE(rug.groupname, 'no-group') as usergroup
    FROM $DB_NAME.radcheck rc
    LEFT JOIN $DB_NAME.radusergroup rug ON rc.username = rug.username
    WHERE rc.attribute = 'Cleartext-Password'
    ORDER BY rc.username;
    "
}

# Import users from CSV
import_csv() {
    local csv_file=$1
    
    if [[ -z "$csv_file" || ! -f "$csv_file" ]]; then
        error "CSV file not found: $csv_file"
        return 1
    fi
    
    log "Importing users from $csv_file..."
    
    # Skip header line and process each user
    tail -n +2 "$csv_file" | while IFS=',' read -r username password group email; do
        # Remove quotes and whitespace
        username=$(echo "$username" | tr -d '"' | xargs)
        password=$(echo "$password" | tr -d '"' | xargs)
        group=$(echo "$group" | tr -d '"' | xargs)
        email=$(echo "$email" | tr -d '"' | xargs)
        
        if [[ -n "$username" && -n "$password" ]]; then
            add_user "$username" "$password" "${group:-default}"
        else
            warning "Skipping invalid line: $username,$password,$group,$email"
        fi
    done
    
    log "Import completed"
}

# Export users to CSV
export_csv() {
    local output_file=${1:-"freeradius_users_$(date +%Y%m%d_%H%M%S).csv"}
    
    log "Exporting users to $output_file..."
    
    # Create CSV header
    echo "username,password,group,created_date" > "$output_file"
    
    # Export users
    mysql -u $DB_USER -p$DB_PASS -se "
    SELECT 
        CONCAT('\"', rc.username, '\"'),
        CONCAT('\"', rc.value, '\"'),
        CONCAT('\"', COALESCE(rug.groupname, 'default'), '\"'),
        CONCAT('\"', NOW(), '\"')
    FROM $DB_NAME.radcheck rc
    LEFT JOIN $DB_NAME.radusergroup rug ON rc.username = rug.username
    WHERE rc.attribute = 'Cleartext-Password'
    ORDER BY rc.username;
    " | sed 's/\t/,/g' >> "$output_file"
    
    log "✅ Users exported to $output_file"
}

# Change user password
change_password() {
    local username=$1
    local new_password=$2
    
    if [[ -z "$username" || -z "$new_password" ]]; then
        error "Username and new password are required"
        return 1
    fi
    
    # Check if user exists
    existing=$(mysql -u $DB_USER -p$DB_PASS -se "SELECT COUNT(*) FROM $DB_NAME.radcheck WHERE username='$username';")
    
    if [ "$existing" -eq 0 ]; then
        error "User $username does not exist"
        return 1
    fi
    
    # Update password
    mysql -u $DB_USER -p$DB_PASS -e "
    USE $DB_NAME;
    UPDATE radcheck SET value='$new_password' WHERE username='$username' AND attribute='Cleartext-Password';
    "
    
    if [ $? -eq 0 ]; then
        log "✅ Password for user $username updated successfully"
    else
        error "❌ Failed to update password for user $username"
    fi
}

# Generate random users for testing
generate_test_users() {
    local count=${1:-10}
    
    log "Generating $count test users..."
    
    for i in $(seq 1 $count); do
        username="testuser$(printf "%03d" $i)"
        password=$(openssl rand -base64 8 | tr -d "=+/" | cut -c1-8)
        
        add_user "$username" "$password" "test"
    done
    
    log "✅ Generated $count test users"
}

# Show user statistics
show_stats() {
    log "User Statistics:"
    
    total_users=$(mysql -u $DB_USER -p$DB_PASS -se "SELECT COUNT(*) FROM $DB_NAME.radcheck WHERE attribute='Cleartext-Password';")
    echo "Total Users: $total_users"
    
    # Users by group
    echo ""
    echo "Users by Group:"
    mysql -u $DB_USER -p$DB_PASS -e "
    SELECT 
        COALESCE(rug.groupname, 'no-group') as 'Group',
        COUNT(*) as 'Count'
    FROM $DB_NAME.radcheck rc
    LEFT JOIN $DB_NAME.radusergroup rug ON rc.username = rug.username
    WHERE rc.attribute = 'Cleartext-Password'
    GROUP BY rug.groupname
    ORDER BY COUNT(*) DESC;
    "
    
    # Recent authentications
    echo ""
    echo "Recent Authentication Summary (last 7 days):"
    mysql -u $DB_USER -p$DB_PASS -e "
    SELECT 
        DATE(authdate) as 'Date',
        COUNT(*) as 'Authentications',
        COUNT(DISTINCT username) as 'Unique Users'
    FROM $DB_NAME.radpostauth 
    WHERE authdate >= DATE_SUB(NOW(), INTERVAL 7 DAY)
    GROUP BY DATE(authdate)
    ORDER BY Date DESC;
    "
}

# Show help
show_help() {
    echo "FreeRADIUS Bulk User Management Script"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  add <username> <password> [group]  - Add single user"
    echo "  delete <username>                  - Delete user"
    echo "  list                              - List all users"
    echo "  import <csv_file>                 - Import users from CSV"
    echo "  export [output_file]              - Export users to CSV"
    echo "  password <username> <new_password> - Change user password"
    echo "  generate [count]                  - Generate test users (default: 10)"
    echo "  stats                             - Show user statistics"
    echo "  help                              - Show this help"
    echo ""
    echo "CSV Format for import:"
    echo "  username,password,group,email"
    echo "  user1,pass1,staff,user1@example.com"
    echo "  user2,pass2,student,user2@example.com"
    echo ""
    echo "Examples:"
    echo "  $0 add john johnpass staff"
    echo "  $0 import users.csv"
    echo "  $0 export backup_users.csv"
    echo "  $0 password john newpass123"
    echo "  $0 generate 50"
    echo ""
}

# Main logic
case "$1" in
    "add")
        add_user "$2" "$3" "$4"
        ;;
    "delete")
        delete_user "$2"
        ;;
    "list")
        list_users
        ;;
    "import")
        import_csv "$2"
        ;;
    "export")
        export_csv "$2"
        ;;
    "password")
        change_password "$2" "$3"
        ;;
    "generate")
        generate_test_users "$2"
        ;;
    "stats")
        show_stats
        ;;
    "help"|"")
        show_help
        ;;
    *)
        error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
