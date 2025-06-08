# FreeRADIUS Configuration Guide

## Advanced Configuration untuk FreeRADIUS 3

### 1. Menambah NAS Client Baru

Edit file `/etc/freeradius/3.0/clients.conf`:

```bash
client your-nas-device {
    ipaddr = 192.168.1.100
    secret = your-strong-secret
    shortname = nas-01
    nas_type = cisco
}
```

### 2. Menambah User via Command Line

```bash
# Insert user baru
mysql -u radius -p -e "
USE radius;
INSERT INTO radcheck (username, attribute, op, value) VALUES ('newuser', 'Cleartext-Password', ':=', 'newpass');
INSERT INTO radreply (username, attribute, op, value) VALUES ('newuser', 'Framed-Protocol', '=', 'PPP');
"
```

### 3. Mengaktifkan Accounting

Edit `/etc/freeradius/3.0/sites-available/default` dan pastikan accounting section tidak dicomment:

```
accounting {
    detail
    sql
    exec
    attr_filter.accounting_response
}
```

### 4. Setup VLAN Assignment

Untuk assign VLAN berdasarkan user:

```bash
mysql -u radius -p -e "
USE radius;
INSERT INTO radreply (username, attribute, op, value) VALUES ('vlanuser', 'Tunnel-Type', '=', 'VLAN');
INSERT INTO radreply (username, attribute, op, value) VALUES ('vlanuser', 'Tunnel-Medium-Type', '=', 'IEEE-802');
INSERT INTO radreply (username, attribute, op, value) VALUES ('vlanuser', 'Tunnel-Private-Group-Id', '=', '100');
"
```

### 5. Rate Limiting per User

```bash
mysql -u radius -p -e "
USE radius;
INSERT INTO radreply (username, attribute, op, value) VALUES ('limituser', 'WISPr-Bandwidth-Max-Down', '=', '1024000');
INSERT INTO radreply (username, attribute, op, value) VALUES ('limituser', 'WISPr-Bandwidth-Max-Up', '=', '512000');
"
```

### 6. Group-based Configuration

Membuat group dan assign user ke group:

```bash
mysql -u radius -p -e "
USE radius;
-- Buat group attributes
INSERT INTO radgroupcheck (groupname, attribute, op, value) VALUES ('staff', 'Auth-Type', ':=', 'Local');
INSERT INTO radgroupreply (groupname, attribute, op, value) VALUES ('staff', 'Service-Type', '=', 'Framed-User');
INSERT INTO radgroupreply (groupname, attribute, op, value) VALUES ('staff', 'Framed-Protocol', '=', 'PPP');

-- Assign user ke group
INSERT INTO radusergroup (username, groupname, priority) VALUES ('staffuser', 'staff', 1);
"
```

### 7. Time-based Access Control

Batasi akses berdasarkan waktu:

```bash
mysql -u radius -p -e "
USE radius;
INSERT INTO radcheck (username, attribute, op, value) VALUES ('timeuser', 'Login-Time', ':=', 'Mo-Fr0800-1800');
"
```

### 8. MAC Address Authentication

```bash
mysql -u radius -p -e "
USE radius;
INSERT INTO radcheck (username, attribute, op, value) VALUES ('00:11:22:33:44:55', 'Auth-Type', ':=', 'Accept');
INSERT INTO radreply (username, attribute, op, value) VALUES ('00:11:22:33:44:55', 'Reply-Message', '=', 'MAC Auth Success');
"
```

### 9. Monitoring dan Logging

#### Enable Detail Logging
Edit `/etc/freeradius/3.0/sites-available/default`:

```
accounting {
    detail
    daily
    sql
}
```

#### Log Rotation
Tambahkan di `/etc/logrotate.d/freeradius`:

```
/var/log/freeradius/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    postrotate
        /etc/init.d/freeradius reload > /dev/null
    endscript
}
```

### 10. Performance Tuning

Edit `/etc/freeradius/3.0/radiusd.conf`:

```
max_requests = 16384
max_request_time = 30
cleanup_delay = 5
max_requests_per_server = 2048

thread pool {
    start_servers = 5
    max_servers = 32
    min_spare_servers = 3
    max_spare_servers = 10
}
```

### 11. SSL/TLS Configuration untuk EAP

Generate certificates:

```bash
cd /etc/freeradius/3.0/certs
make
```

Edit `/etc/freeradius/3.0/mods-available/eap`:

```
eap {
    default_eap_type = peap
    timer_expire = 60
    ignore_unknown_eap_types = no
    
    tls-config tls-common {
        private_key_password = whatever
        private_key_file = ${certdir}/server.pem
        certificate_file = ${certdir}/server.pem
        ca_file = ${cadir}/ca.pem
        cipher_list = "DEFAULT"
        tls_min_version = "1.2"
    }
}
```

### 12. Backup Configuration

Script backup otomatis:

```bash
#!/bin/bash
# backup-freeradius.sh

BACKUP_DIR="/opt/backups/freeradius"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup config files
tar -czf $BACKUP_DIR/freeradius-config-$DATE.tar.gz /etc/freeradius/3.0/

# Backup database
mysqldump -u radius -p radius > $BACKUP_DIR/radius-db-$DATE.sql

# Keep only last 7 days
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
```

### 13. High Availability Setup

Untuk setup HA dengan 2 server:

#### Server 1 (Primary):
```bash
# Replicate database ke server 2
mysql -u root -p -e "
GRANT REPLICATION SLAVE ON *.* TO 'replica'@'server2-ip' IDENTIFIED BY 'replica-password';
FLUSH PRIVILEGES;
"
```

#### Server 2 (Secondary):
```bash
# Setup sebagai slave
mysql -u root -p -e "
CHANGE MASTER TO
MASTER_HOST='server1-ip',
MASTER_USER='replica',
MASTER_PASSWORD='replica-password';
START SLAVE;
"
```

### 14. API Integration

Install REST module untuk API:

```bash
cd /etc/freeradius/3.0/mods-available
ln -s rest ../mods-enabled/
```

Konfigurasi di `/etc/freeradius/3.0/mods-available/rest`:

```
rest {
    tls {
        ca_file = ${certdir}/cacert.pem
        ca_path = ${certdir}
        certificate_file = ${certdir}/client.pem
        private_key_file = ${certdir}/client.key
    }
    
    authorize {
        uri = "http://your-api.com/radius/authorize"
        method = 'post'
        body = 'json'
    }
}
```

### 15. Troubleshooting Commands

```bash
# Debug specific user
echo "User-Name = username" | radclient localhost:1812 auth testing123

# Test accounting
echo "User-Name = username, Acct-Status-Type = Start" | radclient localhost:1813 acct testing123

# Check SQL queries
freeradius -X | grep -i sql

# Monitor real-time
tail -f /var/log/freeradius/radius.log | grep "Auth:"

# Performance monitoring
radclient -r 1 -c 100 localhost:1812 auth testing123 < test_users.txt
```

Ini adalah konfigurasi lanjutan yang bisa disesuaikan dengan kebutuhan spesifik environment Anda.
