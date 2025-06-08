# FreeRADIUS 3 Setup Script

A comprehensive setup script for installing and configuring FreeRADIUS 3 on Ubuntu VPS with MySQL backend.

## Features

- ✅ Automated FreeRADIUS 3 installation
- ✅ MySQL database integration
- ✅ Secure random credential generation
- ✅ UFW firewall configuration
- ✅ Sample user creation
- ✅ Configuration testing
- ✅ Service management

## Requirements

- Ubuntu server (any recent version)
- Root access
- Internet connection

## Installation

1. Download the setup script:
   ```bash
   wget https://raw.githubusercontent.com/iamfafakkk/freeRadius/refs/heads/main/setup.sh
   # or copy the setup.sh file to your server
   ```

2. Make the script executable:
   ```bash
   chmod +x setup.sh
   ```

3. Run the installation as root:
   ```bash
   sudo ./setup.sh
   ```

## What the Script Does

1. **System Update**: Updates all packages to latest versions
2. **Package Installation**: Installs FreeRADIUS, MySQL, and utilities
3. **MySQL Configuration**: Creates database and user with random credentials
4. **FreeRADIUS Setup**: Configures SQL backend and clients
5. **Firewall Setup**: Configures UFW with necessary ports
6. **Sample Users**: Creates test users for verification
7. **Service Management**: Starts and enables all services
8. **Testing**: Validates the installation

## Default Configuration

### Network Clients
- **localhost**: `127.0.0.1` with secret `testing123`
- **private-network-1**: `192.168.0.0/16` with secret `testing123`
- **private-network-2**: `10.0.0.0/8` with secret `testing123`

### Sample Users
- `testuser` / `testpass`
- `john` / `johnpass`

### Firewall Ports
- SSH (port 22)
- RADIUS Authentication (port 1812/udp)
- RADIUS Accounting (port 1813/udp)

## Important Files

- **Credentials**: `/root/freeradius-credentials.txt`
- **Main Config**: `/etc/freeradius/3.0/`
- **Clients Config**: `/etc/freeradius/3.0/clients.conf`
- **SQL Config**: `/etc/freeradius/3.0/mods-available/sql`

## Useful Commands

### Testing Authentication
```bash
echo "User-Name = testuser, Cleartext-Password = testpass" | radclient localhost:1812 auth testing123
```

### Debug Mode
```bash
freeradius -X
```

### Service Management
```bash
systemctl restart freeradius
systemctl status freeradius
systemctl stop freeradius
```

### View Logs
```bash
tail -f /var/log/freeradius/radius.log
```

### View Credentials
```bash
cat /root/freeradius-credentials.txt
```

## Security Notes

⚠️ **Important Security Reminders:**

1. Change default passwords in production environments
2. Update client secrets from default `testing123`
3. Configure proper network access controls
4. Regularly update system packages
5. Monitor logs for suspicious activity

## Troubleshooting

### Check Service Status
```bash
systemctl status freeradius
systemctl status mysql
```

### Test Configuration
```bash
freeradius -C  # Test config syntax
```

### Check MySQL Connection
```bash
mysql -u [username] -p[password] [database_name]
```

### View Detailed Logs
```bash
journalctl -u freeradius -f
```

## Database Schema

The script automatically imports the FreeRADIUS MySQL schema with tables:
- `radcheck` - User authentication data
- `radreply` - User authorization data  
- `radacct` - Accounting data
- `radpostauth` - Post-authentication logging
- `radgroupcheck` - Group authentication data
- `radgroupreply` - Group authorization data
- `radusergroup` - User-to-group mappings
- `nas` - Network Access Server definitions

## License

This script is provided as-is for educational and production use.

## Support

For issues or questions:
1. Check the logs: `/var/log/freeradius/radius.log`
2. Test configuration: `freeradius -C`
3. Run in debug mode: `freeradius -X`

---

**Generated on**: June 8, 2025  
**Compatible with**: Ubuntu (all recent versions)
