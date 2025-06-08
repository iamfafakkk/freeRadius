#!/bin/bash

# FreeRADIUS Maintenance Script
# Script untuk maintenance dan monitoring FreeRADIUS

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Get database credentials
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

# Check services status
check_services() {
    log "Checking services status..."
    
    services=("freeradius" "mysql" "apache2")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet $service; then
            echo -e "✅ $service: ${GREEN}Running${NC}"
        else
            echo -e "❌ $service: ${RED}Stopped${NC}"
        fi
    done
}

# Show system resources
show_resources() {
    log "System Resources:"
    
    # Memory usage
    echo "Memory Usage:"
    free -h
    echo ""
    
    # Disk usage
    echo "Disk Usage:"
    df -h | grep -E "(Filesystem|/dev/)"
    echo ""
    
    # CPU load
    echo "CPU Load:"
    uptime
    echo ""
}

# Show FreeRADIUS statistics
show_radius_stats() {
    log "FreeRADIUS Statistics:"
    
    # Total users
    user_count=$(mysql -u $DB_USER -p$DB_PASS -se "SELECT COUNT(*) FROM $DB_NAME.radcheck WHERE attribute='Cleartext-Password';")
    echo "Total Users: $user_count"
    
    # Recent authentications (last 24 hours)
    recent_auth=$(mysql -u $DB_USER -p$DB_PASS -se "SELECT COUNT(*) FROM $DB_NAME.radpostauth WHERE authdate >= DATE_SUB(NOW(), INTERVAL 24 HOUR);")
    echo "Authentications (24h): $recent_auth"
    
    # Active sessions
    active_sessions=$(mysql -u $DB_USER -p$DB_PASS -se "SELECT COUNT(*) FROM $DB_NAME.radacct WHERE acctstoptime IS NULL;")
    echo "Active Sessions: $active_sessions"
    
    # Database size
    db_size=$(mysql -u $DB_USER -p$DB_PASS -se "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 1) AS 'DB Size (MB)' FROM information_schema.tables WHERE table_schema='$DB_NAME';")
    echo "Database Size: ${db_size}MB"
}

# Test authentication
test_auth() {
    log "Testing authentication..."
    
    # Test with sample user
    result=$(echo "User-Name = testuser, Cleartext-Password = testpass" | radclient localhost:1812 auth testing123 2>/dev/null)
    
    if [[ $result == *"Access-Accept"* ]]; then
        echo -e "✅ Authentication: ${GREEN}OK${NC}"
    else
        echo -e "❌ Authentication: ${RED}FAILED${NC}"
        echo "Result: $result"
    fi
}

# Show recent logs
show_logs() {
    log "Recent FreeRADIUS logs (last 20 lines):"
    tail -20 /var/log/freeradius/radius.log
}

# Backup database
backup_database() {
    log "Creating database backup..."
    
    backup_dir="/opt/backups/freeradius"
    mkdir -p $backup_dir
    
    backup_file="$backup_dir/radius-backup-$(date +%Y%m%d_%H%M%S).sql"
    
    if mysqldump -u $DB_USER -p$DB_PASS $DB_NAME > $backup_file; then
        echo -e "✅ Backup created: ${GREEN}$backup_file${NC}"
        
        # Compress backup
        gzip $backup_file
        echo -e "✅ Backup compressed: ${GREEN}$backup_file.gz${NC}"
        
        # Remove old backups (keep last 7 days)
        find $backup_dir -name "*.sql.gz" -mtime +7 -delete
        info "Old backups cleaned up"
    else
        error "Backup failed!"
    fi
}

# Restart services
restart_services() {
    log "Restarting FreeRADIUS services..."
    
    services=("freeradius" "mysql" "apache2")
    
    for service in "${services[@]}"; do
        if systemctl restart $service; then
            echo -e "✅ $service: ${GREEN}Restarted${NC}"
        else
            echo -e "❌ $service: ${RED}Failed to restart${NC}"
        fi
    done
}

# Clean old sessions
clean_old_sessions() {
    log "Cleaning old sessions..."
    
    # Remove sessions older than 30 days
    old_sessions=$(mysql -u $DB_USER -p$DB_PASS -se "SELECT COUNT(*) FROM $DB_NAME.radacct WHERE acctstarttime < DATE_SUB(NOW(), INTERVAL 30 DAY);")
    
    if [ "$old_sessions" -gt 0 ]; then
        mysql -u $DB_USER -p$DB_PASS -e "DELETE FROM $DB_NAME.radacct WHERE acctstarttime < DATE_SUB(NOW(), INTERVAL 30 DAY);"
        log "Removed $old_sessions old sessions"
    else
        info "No old sessions to clean"
    fi
    
    # Remove old postauth logs
    old_postauth=$(mysql -u $DB_USER -p$DB_PASS -se "SELECT COUNT(*) FROM $DB_NAME.radpostauth WHERE authdate < DATE_SUB(NOW(), INTERVAL 30 DAY);")
    
    if [ "$old_postauth" -gt 0 ]; then
        mysql -u $DB_USER -p$DB_PASS -e "DELETE FROM $DB_NAME.radpostauth WHERE authdate < DATE_SUB(NOW(), INTERVAL 30 DAY);"
        log "Removed $old_postauth old postauth records"
    else
        info "No old postauth records to clean"
    fi
}

# Show help
show_help() {
    echo "FreeRADIUS Maintenance Script"
    echo ""
    echo "Usage: $0 [option]"
    echo ""
    echo "Options:"
    echo "  status      - Check services status"
    echo "  resources   - Show system resources"
    echo "  stats       - Show FreeRADIUS statistics"
    echo "  test        - Test authentication"
    echo "  logs        - Show recent logs"
    echo "  backup      - Create database backup"
    echo "  restart     - Restart all services"
    echo "  clean       - Clean old sessions and logs"
    echo "  monitor     - Full monitoring (all above)"
    echo "  help        - Show this help"
    echo ""
}

# Full monitoring
full_monitor() {
    log "=== FreeRADIUS Full Monitoring ==="
    echo ""
    
    check_services
    echo ""
    
    show_resources
    echo ""
    
    show_radius_stats
    echo ""
    
    test_auth
    echo ""
    
    show_logs
}

# Main logic
case "$1" in
    "status")
        check_services
        ;;
    "resources")
        show_resources
        ;;
    "stats")
        show_radius_stats
        ;;
    "test")
        test_auth
        ;;
    "logs")
        show_logs
        ;;
    "backup")
        backup_database
        ;;
    "restart")
        restart_services
        ;;
    "clean")
        clean_old_sessions
        ;;
    "monitor")
        full_monitor
        ;;
    "help"|"")
        show_help
        ;;
    *)
        error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
