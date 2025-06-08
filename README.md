# FreeRADIUS 3 Setup untuk Ubuntu VPS

Script ini akan menginstal dan mengkonfigurasi FreeRADIUS 3 pada Ubuntu VPS dengan fitur lengkap termasuk web management interface (daloRADIUS).

## Fitur yang Diinstal

- **FreeRADIUS 3** - Server RADIUS utama
- **MySQL Database** - Backend database untuk menyimpan user dan konfigurasi
- **daloRADIUS** - Web interface untuk management FreeRADIUS
- **Apache2** - Web server untuk daloRADIUS
- **PHP** - Runtime untuk daloRADIUS
- **UFW Firewall** - Konfigurasi keamanan dasar

## Persyaratan Sistem

- Ubuntu 18.04, 20.04, atau 22.04 LTS
- Minimal 1GB RAM
- Minimal 10GB storage
- Root access atau user dengan sudo privileges
- Koneksi internet yang stabil

## Cara Penggunaan

### 1. Upload ke VPS

Upload file `setup.sh` ke VPS Ubuntu Anda:

```bash
# Dari komputer lokal (macOS)
scp setup.sh user@your-vps-ip:~/
```

### 2. Login ke VPS

```bash
ssh user@your-vps-ip
```

### 3. Buat file executable dan jalankan sebagai root

```bash
chmod +x setup.sh
chmod +x maintenance.sh
chmod +x user-management.sh
chmod +x show-info.sh
sudo ./setup.sh
```

### 4. Ikuti prompts

Script akan meminta input untuk:
- MySQL root password (saat mysql_secure_installation)
- Konfirmasi beberapa pengaturan

## Setelah Instalasi

### Melihat Informasi Kredensial

```bash
# Lihat semua informasi instalasi
./show-info.sh

# Atau lihat file kredensial langsung
cat /root/freeradius-credentials.txt
```

### Akses Web Management (daloRADIUS)

- URL: `http://your-vps-ip/daloradius`
- Username: `administrator`
- Password: `radius`

### Default Database Credentials

Database credentials akan di-generate secara random saat instalasi untuk keamanan:
- Database: `radius_XXXXXX` (random)
- Username: `radius_XXXXXXXX` (random)
- Password: `XXXXXXXXXXXXXXXX` (random 16 karakter)

**Kredensial akan disimpan di: `/root/freeradius-credentials.txt`**

### Sample Users yang Dibuat

- Username: `testuser`, Password: `testpass`
- Username: `john`, Password: `johnpass`

## Testing Koneksi

### Test dari command line:

```bash
# Test authentication
echo "User-Name = testuser, Cleartext-Password = testpass" | radclient localhost:1812 auth testing123
```

### Test dari aplikasi lain:

- Server: `your-vps-ip`
- Port: `1812` (Authentication), `1813` (Accounting)
- Secret: `testing123`

## File Konfigurasi Penting

- Main config: `/etc/freeradius/3.0/`
- Clients: `/etc/freeradius/3.0/clients.conf`
- SQL config: `/etc/freeradius/3.0/mods-available/sql`
- daloRADIUS config: `/var/www/html/daloradius/library/daloradius.conf.php`

## Command Berguna

```bash
# Restart FreeRADIUS
systemctl restart freeradius

# Cek status service
systemctl status freeradius
systemctl status mysql
systemctl status apache2

# Debug mode (untuk troubleshooting)
freeradius -X

# Lihat log
tail -f /var/log/freeradius/radius.log

# Test konfigurasi
freeradius -C
```

## Keamanan

⚠️ **PENTING untuk Production:**

1. **Ganti password default:**
   - MySQL radius user password
   - daloRADIUS admin password
   - RADIUS shared secrets

2. **Setup SSL certificate:**
   ```bash
   apt install certbot python3-certbot-apache
   certbot --apache
   ```

3. **Konfigurasi firewall tambahan:**
   ```bash
   # Batasi akses SSH hanya dari IP tertentu
   ufw delete allow ssh
   ufw allow from YOUR_IP to any port 22
   
   # Batasi akses daloRADIUS
   ufw allow from YOUR_IP to any port 80
   ufw allow from YOUR_IP to any port 443
   ```

4. **Update sistem secara berkala:**
   ```bash
   apt update && apt upgrade -y
   ```

## Troubleshooting

### FreeRADIUS tidak start:
```bash
freeradius -X  # Debug mode untuk lihat error
```

### Web interface tidak bisa diakses:
```bash
systemctl status apache2
ufw status  # Cek firewall
```

### Database connection error:
```bash
mysql -u radius -p  # Test koneksi database
```

### Port sudah digunakan:
```bash
netstat -tulpn | grep :1812
netstat -tulpn | grep :1813
```

## Support

Jika ada masalah:
1. Cek log: `tail -f /var/log/freeradius/radius.log`
2. Run debug mode: `freeradius -X`
3. Cek status service: `systemctl status freeradius`

## Struktur File yang Dibuat

```
/etc/freeradius/3.0/          # Konfigurasi FreeRADIUS
├── clients.conf              # Konfigurasi NAS clients
├── mods-available/sql        # Konfigurasi SQL module
└── sites-available/default   # Site konfigurasi

/var/www/html/daloradius/     # Web management interface
├── library/daloradius.conf.php  # Konfigurasi database
└── contrib/db/               # SQL schema files
```

Script ini sudah ditest dan siap untuk production dengan penyesuaian keamanan yang diperlukan.
