# FreeRADIUS 3 Setup Script

Skrip instalasi otomatis untuk FreeRADIUS 3 pada Ubuntu VPS dengan antarmuka web daloRADIUS.

## Persyaratan

- Ubuntu Server (18.04, 20.04, 22.04, atau lebih baru)
- Akses root atau sudo
- Koneksi internet yang stabil

## Cara Menjalankan

### 1. Download atau Clone Repository

```bash
# Download file setup.sh ke server Ubuntu Anda
wget https://raw.githubusercontent.com/iamfafakkk/freeRadius/refs/heads/main/setup.sh
# atau
curl -O https://raw.githubusercontent.com/iamfafakkk/freeRadius/refs/heads/main/setup.sh
```

### 2. Berikan Permission Execute

```bash
chmod +x setup.sh
```

### 3. Jalankan Script

```bash
sudo ./setup.sh
```

## Yang Akan Diinstal

- **FreeRADIUS 3** - Server RADIUS utama
- **MySQL** - Database server
- **Apache2** - Web server
- **PHP** - Runtime untuk aplikasi web
- **daloRADIUS** - Antarmuka web untuk manajemen FreeRADIUS

## Setelah Instalasi

### Akses Web Management
- URL: `http://IP-SERVER-ANDA/daloradius`
- Username: `administrator`
- Password: `radius`

### User Testing
Script akan membuat 2 user contoh:
- `testuser` / `testpass`
- `john` / `johnpass`

### File Kredensial
Semua informasi login disimpan di: `/root/freeradius-credentials.txt`

## Testing Koneksi

```bash
# Test konfigurasi
sudo freeradius -X

# Test autentikasi user
echo "User-Name = testuser, Cleartext-Password = testpass" | radclient localhost:1812 auth testing123
```

## Troubleshooting

### Cek Status Service
```bash
sudo systemctl status freeradius
sudo systemctl status mysql
sudo systemctl status apache2
```

### Restart Service
```bash
sudo systemctl restart freeradius
sudo systemctl restart mysql
sudo systemctl restart apache2
```

### Lihat Log
```bash
sudo tail -f /var/log/freeradius/radius.log
```

## Keamanan

⚠️ **PENTING**: Setelah instalasi, pastikan untuk:

1. Ganti password default di daloRADIUS
2. Setup SSL certificate untuk akses HTTPS
3. Ganti password MySQL root
4. Konfigurasi firewall sesuai kebutuhan
5. Hapus atau ganti user testing

## Support

Jika mengalami masalah:
1. Cek file log di `/var/log/freeradius/`
2. Verifikasi konfigurasi dengan `sudo freeradius -C`
3. Pastikan semua service berjalan dengan `systemctl status`

## Lokasi File Penting

- Konfigurasi FreeRADIUS: `/etc/freeradius/3.0/`
- Konfigurasi daloRADIUS: `/var/www/html/daloradius/`
- Database credentials: `/root/freeradius-credentials.txt`
- Web directory: `/var/www/html/daloradius/`
