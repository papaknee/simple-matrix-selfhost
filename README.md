# Simple Matrix Self-Hosting for AWS Lightsail

Complete toolkit for deploying a private Matrix chat and voice server on AWS Lightsail with Element Web client.

## Features

✨ **Easy Setup** - One-command installation script  
🔒 **Secure** - SSL/TLS encryption via Let's Encrypt  
📧 **Admin Notifications** - Email alerts for new users and system events  
🔄 **Auto-Updates** - Scheduled weekly updates and monthly reboots  
🐳 **Docker-Based** - Simple deployment with Docker Compose  
💬 **Full-Featured** - Chat, voice, and video calling support  
🌐 **Federation Ready** - Connect with other Matrix servers (optional)

## Table of Contents

- [Prerequisites](#prerequisites)
- [Step 1: Purchase a Domain](#step-1-purchase-a-domain)
- [Step 2: Set Up AWS Lightsail Instance](#step-2-set-up-aws-lightsail-instance)
- [Step 3: Configure DNS](#step-3-configure-dns)
- [Step 4: Install Matrix Server](#step-4-install-matrix-server)
- [Step 5: Create Admin User](#step-5-create-admin-user)
- [Step 6: Configure Admin Notifications](#step-6-configure-admin-notifications)
- [Step 7: Enable Auto-Updates and Scheduled Reboots](#step-7-enable-auto-updates-and-scheduled-reboots)
- [Accessing Your Server](#accessing-your-server)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)

## Prerequisites

- AWS account
- Domain name (can be purchased from AWS Route 53, Namecheap, Google Domains, etc.)
- Credit card for AWS and domain purchase
- Basic command line knowledge

## Step 1: Purchase a Domain

You'll need a domain name for your Matrix server. Here are some popular options:

### Option A: AWS Route 53 (Recommended for AWS Lightsail)

1. Go to [AWS Route 53](https://console.aws.amazon.com/route53/)
2. Click "Registered domains" → "Register domain"
3. Search for available domain names (e.g., `yourdomain.com`)
4. Follow the checkout process (~$12-15/year for .com domains)

### Option B: Other Domain Registrars

Popular alternatives:
- [Namecheap](https://www.namecheap.com) - Good prices, easy to use
- [Porkbun](https://porkbun.com) - Affordable with free WHOIS privacy
- [Cloudflare](https://www.cloudflare.com/products/registrar/) - At-cost pricing

## Step 2: Set Up AWS Lightsail Instance

### Create the Instance

1. **Log in to AWS Console**
   - Go to [AWS Lightsail](https://lightsail.aws.amazon.com/)
   - Click "Create instance"

2. **Select Instance Location**
   - Choose a region closest to your users
   - Example: "US East (N. Virginia)"

3. **Pick Instance Image**
   - Platform: **Linux/Unix**
   - Blueprint: **OS Only** → **Ubuntu 22.04 LTS**

4. **Choose Instance Plan**
   - Recommended: **$10/month plan** (2 GB RAM, 1 vCPU, 60 GB SSD)
   - Minimum: **$5/month plan** (1 GB RAM) - suitable for small teams
   - For 10+ users: **$20/month plan** (4 GB RAM)

5. **Configure Instance**
   - Name your instance: `matrix-server`
   - Click "Create instance"

### Configure Networking

1. **Create Static IP**
   - In Lightsail, go to "Networking" tab
   - Click "Create static IP"
   - Attach it to your `matrix-server` instance
   - Name it `matrix-server-ip`
   - Click "Create"
   - **Note down the IP address** (e.g., `12.34.56.78`)

2. **Configure Firewall**
   - Go to your instance → "Networking" tab
   - Under "IPv4 Firewall", add these rules:
     - HTTP: TCP, Port 80
     - HTTPS: TCP, Port 443
     - Matrix Federation: TCP, Port 8448
     - SSH: TCP, Port 22 (should already exist)

## Step 3: Configure DNS

Point your domain to your Lightsail instance:

### If using AWS Route 53:

1. Go to [Route 53 Console](https://console.aws.amazon.com/route53/)
2. Click "Hosted zones" → Select your domain
3. Click "Create record"
4. Create an **A record**:
   - Record name: `matrix` (creates `matrix.yourdomain.com`)
   - Record type: `A`
   - Value: Your Lightsail static IP (e.g., `12.34.56.78`)
   - TTL: `300`
   - Click "Create records"

### If using other registrars:

1. Log in to your domain registrar
2. Find DNS settings (usually called "DNS Management" or "Nameservers")
3. Add an **A record**:
   - Host: `matrix`
   - Type: `A`
   - Value: Your Lightsail static IP
   - TTL: `300` (5 minutes)

### Verify DNS Propagation

Wait 5-10 minutes, then verify:
```bash
nslookup matrix.yourdomain.com
# or
ping matrix.yourdomain.com
```

You should see your Lightsail IP address.

## Step 4: Install Matrix Server

### Connect to Your Instance

1. In AWS Lightsail, click on your instance
2. Click "Connect using SSH" (browser-based terminal)
   
   *Or use SSH from your computer:*
   ```bash
   ssh ubuntu@matrix.yourdomain.com
   # or
   ssh ubuntu@YOUR_LIGHTSAIL_IP
   ```

### Run Installation

1. **Clone this repository:**
   ```bash
   sudo apt-get update
   sudo apt-get install -y git
   git clone https://github.com/papaknee/simple-matrix-selfhost.git
   cd simple-matrix-selfhost
   ```

2. **Configure environment:**
   ```bash
   cp .env.example .env
   nano .env
   ```
   
   Edit the following values:
   ```bash
   POSTGRES_PASSWORD=YourSecurePassword123!
   MATRIX_DOMAIN=matrix.yourdomain.com
   ADMIN_EMAIL=your.email@gmail.com
   SERVER_NAME=yourdomain.com
   ```
   
   Press `Ctrl+X`, then `Y`, then `Enter` to save.

3. **Run installation:**
   ```bash
   sudo ./install.sh
   ```
   
   This will:
   - Install Docker and Docker Compose
   - Generate Matrix Synapse configuration
   - Obtain SSL certificate from Let's Encrypt
   - Start all services (PostgreSQL, Synapse, Element, Nginx)

   **Note:** The installation will take 5-10 minutes.

4. **Verify installation:**
   ```bash
   sudo docker-compose ps
   ```
   
   All services should show "Up" status.

## Step 5: Create Admin User

After installation completes, create your admin account:

```bash
sudo ./create-admin-user.sh
```

When prompted:
- Enter username: `admin` (or your preferred username)
- Enter password: (choose a strong password)
- Confirm password

You can now log in at `https://matrix.yourdomain.com` with:
- Username: `@admin:yourdomain.com`
- Password: (the password you set)

### Disable Public Registration (Recommended)

After creating your admin user and any other users you need:

1. Edit the Synapse configuration:
   ```bash
   nano synapse_data/homeserver.yaml
   ```

2. Find and change:
   ```yaml
   enable_registration: false
   ```

3. Restart Synapse:
   ```bash
   docker-compose restart synapse
   ```

## Step 6: Configure Admin Notifications

### Email Notifications for New Users

The server is pre-configured to send email notifications. To set up a proper SMTP server:

1. **Option A: Use Gmail (Simple)**
   
   Edit `synapse_data/homeserver.yaml`:
   ```yaml
   email:
     smtp_host: smtp.gmail.com
     smtp_port: 587
     smtp_user: your.email@gmail.com
     smtp_pass: your-app-password  # Use App Password, not regular password
     require_transport_security: true
     notif_from: "Matrix Server <your.email@gmail.com>"
     enable_notifs: true
     notif_for_new_users: true
   ```

   **To create Gmail App Password:**
   - Go to https://myaccount.google.com/security
   - Enable 2-Step Verification
   - Search for "App passwords"
   - Create new app password for "Mail"

2. **Option B: Use AWS SES (Advanced)**
   
   - Set up [AWS Simple Email Service](https://aws.amazon.com/ses/)
   - Verify your email domain
   - Get SMTP credentials
   - Update `homeserver.yaml` with SES SMTP settings

3. **Restart Synapse:**
   ```bash
   docker-compose restart synapse
   ```

### Usage Alerts

Monitor your server with:

```bash
# View logs for errors
docker-compose logs -f synapse

# Check resource usage
docker stats

# Set up CloudWatch (optional)
# Follow AWS Lightsail metrics documentation
```

## Step 7: Enable Auto-Updates and Scheduled Reboots

### Install Auto-Update Service

Move this repository to a permanent location and set up systemd services:

```bash
# Move to permanent location
sudo mv /home/ubuntu/simple-matrix-selfhost /opt/matrix-server
cd /opt/matrix-server

# Install systemd services
sudo cp matrix-update.service /etc/systemd/system/
sudo cp matrix-update.timer /etc/systemd/system/
sudo cp matrix-reboot.service /etc/systemd/system/
sudo cp matrix-reboot.timer /etc/systemd/system/

# Enable services
sudo systemctl daemon-reload
sudo systemctl enable matrix-update.timer
sudo systemctl enable matrix-reboot.timer
sudo systemctl start matrix-update.timer
sudo systemctl start matrix-reboot.timer
```

### Verify Timers

```bash
# Check timer status
sudo systemctl list-timers --all

# You should see:
# - matrix-update.timer: Runs every Sunday at 3 AM
# - matrix-reboot.timer: Reboots monthly on the 1st at 4 AM
```

### Customize Schedule (Optional)

Edit the timer files to change schedules:

```bash
sudo nano /etc/systemd/system/matrix-update.timer
# Change: OnCalendar=Sun *-*-* 03:00:00
# To your preferred schedule

sudo nano /etc/systemd/system/matrix-reboot.timer
# Change: OnCalendar=*-*-01 04:00:00
# To your preferred schedule

# Reload after changes
sudo systemctl daemon-reload
sudo systemctl restart matrix-update.timer
sudo systemctl restart matrix-reboot.timer
```

## Accessing Your Server

### Element Web Client

Open your browser and go to:
```
https://matrix.yourdomain.com
```

Log in with your admin credentials.

### Mobile Apps

Install Element mobile app:
- **iOS**: [App Store](https://apps.apple.com/app/element-messenger/id1083446067)
- **Android**: [Google Play](https://play.google.com/store/apps/details?id=im.vector.app)

When logging in:
1. Tap "Change server"
2. Enter: `https://matrix.yourdomain.com`
3. Use your credentials

### Desktop Apps

Download Element Desktop:
- [Element Desktop](https://element.io/download)

## Maintenance

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f synapse
docker-compose logs -f nginx
```

### Restart Services

```bash
# Restart all services
docker-compose restart

# Restart specific service
docker-compose restart synapse
```

### Backup Your Data

```bash
# Backup script
sudo docker-compose down
sudo tar -czf matrix-backup-$(date +%Y%m%d).tar.gz synapse_data/ postgres_data/ .env
sudo docker-compose up -d

# Copy to S3 (optional)
aws s3 cp matrix-backup-*.tar.gz s3://your-backup-bucket/
```

### Update Manually

```bash
cd /opt/matrix-server
sudo ./update.sh
```

### Check Resource Usage

```bash
# Disk usage
df -h

# Memory usage
free -h

# Docker stats
docker stats
```

## Troubleshooting

### Can't access server at https://matrix.yourdomain.com

1. Verify DNS is pointing to your server:
   ```bash
   nslookup matrix.yourdomain.com
   ```

2. Check if services are running:
   ```bash
   docker-compose ps
   ```

3. Check nginx logs:
   ```bash
   docker-compose logs nginx
   ```

### SSL Certificate Error

```bash
# Renew certificate manually
docker-compose down
docker run -it --rm \
  -v $(pwd)/ssl:/etc/letsencrypt \
  -v $(pwd)/certbot_data:/var/www/certbot \
  -p 80:80 \
  certbot/certbot renew
docker-compose up -d
```

### Can't Create Users

```bash
# Check Synapse logs
docker-compose logs synapse

# Verify registration is enabled
grep "enable_registration" synapse_data/homeserver.yaml
```

### Server Running Slow

1. Check resource usage:
   ```bash
   docker stats
   ```

2. Consider upgrading your Lightsail plan:
   - Go to Lightsail console
   - Click your instance → "Manage" → "Change plan"

### Database Connection Issues

```bash
# Restart PostgreSQL
docker-compose restart postgres

# Check PostgreSQL logs
docker-compose logs postgres
```

### Synapse Container Stuck Restarting

If `docker-compose ps` shows the synapse container constantly restarting:

1. Check the Synapse logs:
   ```bash
   docker-compose logs synapse
   ```

2. Verify the healthcheck status:
   ```bash
   docker-compose ps synapse
   ```
   
   The "State" should show "Up (healthy)" rather than "Restarting".

3. Common causes:
   - Database not ready: Wait for PostgreSQL to be healthy first
   - Configuration error: Check `synapse_data/homeserver.yaml` for syntax errors
   - Port conflict: Ensure port 8008 is not in use by another service

4. Restart the entire stack:
   ```bash
   docker-compose down
   docker-compose up -d
   ```

## Cost Estimate

| Service | Monthly Cost |
|---------|--------------|
| AWS Lightsail ($10 plan) | $10.00 |
| Domain name (annual/12) | $1.00-2.00 |
| **Total** | **~$11-12/month** |

## Security Best Practices

1. ✅ Keep server updated (automatic with this setup)
2. ✅ Use strong passwords for admin accounts
3. ✅ Disable public registration after creating users
4. ✅ Enable 2FA for AWS account
5. ✅ Regular backups
6. ✅ Monitor logs for suspicious activity

## Advanced Configuration

### Enable Federation

To communicate with users on other Matrix servers (matrix.org, etc.):

1. Edit `synapse_data/homeserver.yaml`:
   ```yaml
   federation_domain_whitelist: []  # Empty list = allow all
   ```

2. Restart:
   ```bash
   docker-compose restart synapse
   ```

### Add TURN Server (Better Voice/Video)

For improved voice/video call quality through NAT/firewalls, set up a TURN server:

1. Install coturn:
   ```bash
   # Instructions at: https://github.com/coturn/coturn
   ```

2. Update `synapse_data/homeserver.yaml` with TURN credentials

## Support

- **Matrix Synapse Docs**: https://matrix-org.github.io/synapse/
- **Element Docs**: https://element.io/help
- **This Repository Issues**: https://github.com/papaknee/simple-matrix-selfhost/issues

## License

MIT License - see [LICENSE](LICENSE) file for details

---

**Made with ❤️ for easy self-hosting**
