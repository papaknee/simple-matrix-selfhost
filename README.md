# Simple Matrix Self-Hosting for AWS Lightsail

Complete toolkit for deploying a private Matrix chat and voice server on AWS Lightsail with Element Web client.

## Features

✨ **Easy Setup** - Interactive setup script guides you through configuration  
🔒 **Secure** - SSL/TLS encryption via Let's Encrypt  
📧 **Admin Notifications** - Email alerts for new user registrations (requires SMTP setup)  
🎛️ **Admin Console** - Web-based management interface for updates, backups, and scheduling  
🐳 **Docker-Based** - Simple deployment with Docker Compose  
💬 **Full-Featured** - Chat, voice, and video calling support  
👥 **Flexible Registration** - Enable/disable user registration with admin email notifications (enabled by default)  
🌐 **Federation Control** - Choose to connect with other Matrix servers or stay private (disabled by default)

## Table of Contents

- [Prerequisites](#prerequisites)
- [Step 1: Purchase a Domain](#step-1-purchase-a-domain)
- [Step 2: Create a Lightsail Instance](#step-2-create-a-lightsail-instance)
- [Step 3: Configure Networking](#step-3-configure-networking)
- [Step 4: Configure DNS](#step-4-configure-dns)
- [Step 5: Run the Setup Script](#step-5-run-the-setup-script)
- [Step 6: Create Admin User](#step-6-create-admin-user)
- [Admin Console](#admin-console)
- [Configure Email Notifications](#configure-email-notifications)
- [Setting Up S3 Backups](#setting-up-s3-backups)
- [Accessing Your Server](#accessing-your-server)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)

## Prerequisites

- AWS account with a credit card on file
- A domain name (can be purchased from AWS Route 53, Namecheap, etc.)

## Step 1: Purchase a Domain

You need a domain name for your Matrix server.

### Option A: AWS Route 53 (Recommended)

1. Go to [AWS Route 53](https://console.aws.amazon.com/route53/)
2. Click "Registered domains" → "Register domain"
3. Search for and purchase a domain (e.g., `yourdomain.com`, ~$12-15/year for .com)

### Option B: Other Registrars

- [Namecheap](https://www.namecheap.com) - Good prices, easy to use
- [Porkbun](https://porkbun.com) - Affordable with free WHOIS privacy
- [Cloudflare](https://www.cloudflare.com/products/registrar/) - At-cost pricing

## Step 2: Create a Lightsail Instance

1. Go to [AWS Lightsail](https://lightsail.aws.amazon.com/) and click **"Create instance"**
2. **Location**: Choose a region closest to your users (e.g., "US East - N. Virginia")
3. **Image**: Select **Linux/Unix** → **OS Only** → **Ubuntu 22.04 LTS**
4. **Launch Script** *(optional but recommended)*: Expand "Add launch script" and paste the following — this pre-installs dependencies while you configure networking, saving time later:
   ```bash
   #!/bin/bash
   curl -sSL https://raw.githubusercontent.com/papaknee/simple-matrix-selfhost/main/lightsail-startup.sh | bash
   ```
5. **Plan**: Select a plan based on your team size:
   - **$5/month** (1 GB RAM) — small teams (1-5 users)
   - **$10/month** (2 GB RAM) — recommended for most setups
   - **$20/month** (4 GB RAM) — 10+ users
6. Name your instance `matrix-server` and click **"Create instance"**

## Step 3: Configure Networking

While your instance starts up, configure the network settings:

### Attach a Static IP

1. In the Lightsail console, go to the **"Networking"** tab
2. Click **"Create static IP"**
3. Attach it to your `matrix-server` instance
4. Name it `matrix-server-ip` and click **"Create"**
5. **Write down the IP address** — you'll need it for DNS (e.g., `12.34.56.78`)

### Open Firewall Ports

1. Go to your instance → **"Networking"** tab
2. Under **"IPv4 Firewall"**, add these rules:
   | Type | Protocol | Port |
   |------|----------|------|
   | HTTP | TCP | 80 |
   | HTTPS | TCP | 443 |
   | Custom | TCP | 8448 |
   | SSH | TCP | 22 *(already exists)* |

## Step 4: Configure DNS

Point your domain to the static IP you just created.

### If Using AWS Route 53

1. Go to [Route 53 Console](https://console.aws.amazon.com/route53/) → "Hosted zones" → Select your domain
2. Click **"Create record"**:
   - **Record name**: `matrix` (this creates `matrix.yourdomain.com`)
   - **Record type**: `A`
   - **Value**: Your static IP (e.g., `12.34.56.78`)
   - **TTL**: `300`
3. Click **"Create records"**

### If Using Another Registrar

1. Log in to your domain registrar and find "DNS Management"
2. Add an **A record**:
   - **Host**: `matrix`
   - **Type**: `A`
   - **Value**: Your static IP
   - **TTL**: `300`

### Verify DNS (Wait 5-10 Minutes)

Before continuing, confirm DNS is working:
```bash
nslookup matrix.yourdomain.com
```
You should see your static IP address in the response.

## Step 5: Run the Setup Script

Now that networking and DNS are configured, connect to your instance and run the setup.

### Connect to Your Instance

In Lightsail, click your instance and then click **"Connect using SSH"** (opens a browser-based terminal).

### Run Setup

Run this single command and follow the prompts:
```bash
curl -sSL https://raw.githubusercontent.com/papaknee/simple-matrix-selfhost/main/setup.sh | sudo bash
```

The script will ask you for:
- Your Matrix domain (e.g., `matrix.yourdomain.com`)
- Your email address
- Database and admin console passwords
- Whether to enable registration and federation

The installation takes about **5-10 minutes**. It will:
- Install Docker
- Generate Matrix Synapse configuration
- Obtain an SSL certificate from Let's Encrypt
- Start all services (PostgreSQL, Synapse, Element Web, Nginx, Admin Console)

> **Tip:** If you used the optional launch script in Step 2, the setup will be faster since dependencies are already installed.

### Alternative: Manual Setup

If you prefer to configure manually instead of using the interactive prompts:
```bash
# If the repo isn't already cloned (skip if you used the launch script)
sudo apt-get update && sudo apt-get install -y git
sudo git clone https://github.com/papaknee/simple-matrix-selfhost.git /opt/matrix-server

cd /opt/matrix-server
sudo cp .env.example .env
sudo nano .env    # Edit with your values, then save with Ctrl+X → Y → Enter
sudo ./install.sh
```

## Step 6: Create Admin User

After installation completes, create your admin account:

```bash
cd /opt/matrix-server
sudo ./create-admin-user.sh
```

When prompted, enter a username and password. You can then log in at `https://matrix.yourdomain.com` with:
- **Username**: `@yourusername:yourdomain.com`
- **Password**: the password you just set

## Admin Console

The admin console provides a web interface for managing your server.

![Admin Console Screenshot](https://github.com/user-attachments/assets/9e5707ef-758b-4bbc-8ab7-7002c177e850)

**Access it at**: `https://matrix.yourdomain.com/admin/`

Log in with the admin console credentials you set during setup (default username: `admin`).

### Features

- **Server Configuration** — Toggle user registration and federation with one click
- **Check for Updates** — Pull latest changes from GitHub
- **Update Docker Images** — Update all services or individual ones
- **Manage Services** — Start, stop, and restart services
- **Schedule Tasks** — Automatic updates and reboots
- **Backup to S3** — Create and schedule backups (requires AWS credentials)
- **View Logs** — Monitor services and troubleshoot

### Secret Key

The admin console uses a secret key for session security. The interactive setup script auto-generates this. If you need to regenerate it:

```bash
cd /opt/matrix-server
# Generate a new key
NEW_KEY=$(openssl rand -hex 32)
# Update .env with the new key
sed -i "s/^ADMIN_CONSOLE_SECRET_KEY=.*/ADMIN_CONSOLE_SECRET_KEY=$NEW_KEY/" .env
# Restart the admin console
docker compose restart admin
```

> **Note:** Changing the secret key will log out all active admin sessions.

## Configure Email Notifications

To receive email alerts when new users register, configure SMTP in `synapse_data/homeserver.yaml`:

### Using Gmail

1. Create a [Gmail App Password](https://myaccount.google.com/security) (enable 2-Step Verification first, then search for "App passwords")
2. Edit the Synapse config:
   ```bash
   cd /opt/matrix-server
   nano synapse_data/homeserver.yaml
   ```
3. Add or update the email section:
   ```yaml
   email:
     smtp_host: smtp.gmail.com
     smtp_port: 587
     smtp_user: your.email@gmail.com
     smtp_pass: your-app-password
     require_transport_security: true
     notif_from: "Matrix Server <your.email@gmail.com>"
     enable_notifs: true
     notif_for_new_users: true
   ```
4. Restart Synapse:
   ```bash
   docker compose restart synapse
   ```

## Setting Up S3 Backups

S3 backups let you save your Matrix server data to Amazon S3 for disaster recovery.

### Create an S3 Bucket

1. Go to [AWS S3 Console](https://s3.console.aws.amazon.com/s3/) → **"Create bucket"**
2. **Bucket name**: `your-matrix-backups` (must be globally unique)
3. **Region**: Same as your Lightsail instance
4. **Block all public access**: Yes (keep enabled)
5. Click **"Create bucket"**

### Create an IAM User

1. Go to [IAM Console](https://console.aws.amazon.com/iam/) → "Policies" → "Create policy"
2. Switch to JSON and paste:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": ["s3:PutObject", "s3:GetObject", "s3:ListBucket"],
         "Resource": [
           "arn:aws:s3:::your-matrix-backups",
           "arn:aws:s3:::your-matrix-backups/*"
         ]
       }
     ]
   }
   ```
3. Name it `MatrixS3BackupPolicy`
4. Go to "Users" → "Create user" → attach the policy
5. Create an access key and **save the credentials**

### Configure Backups

Edit your `.env` file and add:
```bash
cd /opt/matrix-server
nano .env
```
```bash
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_S3_BUCKET=your-matrix-backups
AWS_REGION=us-east-1
```

Restart the admin console:
```bash
docker compose restart admin
```

Test via the admin console at `https://matrix.yourdomain.com/admin/` → "Create Backup Now".

## Accessing Your Server

### Element Web (Browser)

Go to `https://matrix.yourdomain.com` and log in.

### Mobile Apps

Install the Element app ([iOS](https://apps.apple.com/app/element-messenger/id1083446067) / [Android](https://play.google.com/store/apps/details?id=im.vector.app)):
1. Tap "Change server"
2. Enter `https://matrix.yourdomain.com`
3. Log in with your credentials

### Desktop App

Download [Element Desktop](https://element.io/download) and connect to your server.

## Maintenance

### View Logs

```bash
cd /opt/matrix-server
docker compose logs -f          # All services
docker compose logs -f synapse  # Synapse only
```

### Restart Services

```bash
docker compose restart          # All services
docker compose restart synapse  # Synapse only
```

### Update

**Using the Admin Console** (easiest): Go to `https://matrix.yourdomain.com/admin/` and use the update buttons.

**Manually:**
```bash
cd /opt/matrix-server
git pull origin main
docker compose pull
docker compose up -d
```

> **Note:** Auto-updates run weekly (Sundays at 3 AM) and the server reboots monthly (1st of each month at 4 AM) via systemd timers installed during setup.

### Manual Backup

```bash
cd /opt/matrix-server
docker compose down
tar -czf ~/matrix-backup-$(date +%Y%m%d).tar.gz synapse_data/ .env
docker compose up -d
```

### Check Resource Usage

```bash
df -h          # Disk usage
free -h        # Memory usage
docker stats   # Container resource usage
```

## Troubleshooting

### Can't Access the Server

1. **Verify DNS**: `nslookup matrix.yourdomain.com` — should show your static IP
2. **Check services**: `docker compose ps` — all should show "Up"
3. **Check logs**: `docker compose logs nginx`

### SSL Certificate Error

```bash
cd /opt/matrix-server
docker compose down
docker run -it --rm \
  -v $(pwd)/ssl:/etc/letsencrypt \
  -v $(pwd)/certbot_data:/var/www/certbot \
  -p 80:80 \
  certbot/certbot renew
docker compose up -d
```

### Docker Permission Denied

```bash
sudo usermod -aG docker $USER
newgrp docker   # Apply immediately (or log out and back in)
```

### Synapse Container Stuck Restarting

1. Check logs: `docker compose logs synapse | tail -50`
2. Common fixes:
   - Wait 2-3 minutes for PostgreSQL to initialize
   - Check `synapse_data/homeserver.yaml` for YAML syntax errors
   - Restart everything: `docker compose down && docker compose up -d`

### Complete Reset

If nothing else works, back up your data and start fresh:

```bash
cd /opt/matrix-server
sudo tar -czf ~/matrix-backup-$(date +%Y%m%d).tar.gz synapse_data/ .env
docker compose down -v
sudo docker system prune -a --volumes   # Type 'y' to confirm
sudo systemctl restart docker
sudo ./install.sh
```

> **Recovery tip:** If something goes badly wrong, you can always delete the Lightsail instance entirely and create a new one. Just re-run the setup script — your domain and DNS settings stay the same.

## Cost Estimate

| Service | Monthly Cost |
|---------|--------------|
| AWS Lightsail ($10 plan) | $10.00 |
| Domain name (annual/12) | $1.00-2.00 |
| **Total** | **~$11-12/month** |

## Security Best Practices

1. ✅ Use strong passwords for all accounts
2. ✅ Disable public registration after creating your users
3. ✅ Enable 2FA for your AWS account
4. ✅ Create regular backups (S3 recommended)
5. ✅ Monitor logs for suspicious activity

## Advanced Configuration

### Enable/Disable Registration

**Via Admin Console** (easiest): Toggle "User Registration" in the Server Configuration section.

**Via environment variable:**
```bash
cd /opt/matrix-server
nano .env
# Set ENABLE_REGISTRATION=false
docker compose restart synapse
```

### Enable/Disable Federation

Federation allows your server to communicate with other Matrix servers (e.g., matrix.org).

**Via Admin Console** (easiest): Toggle "Federation" in the Server Configuration section.

**Via environment variable:**
```bash
cd /opt/matrix-server
nano .env
# Set ENABLE_FEDERATION=true
docker compose restart synapse
```

**Note:** When federation is enabled, port 8448 must be open (already configured in Step 3).

### Add TURN Server (Better Voice/Video)

For improved voice/video call quality through NAT/firewalls:
1. Install [coturn](https://github.com/coturn/coturn)
2. Update `synapse_data/homeserver.yaml` with TURN credentials

## Support

- **Matrix Synapse Docs**: https://matrix-org.github.io/synapse/
- **Element Docs**: https://element.io/help
- **Issues**: https://github.com/papaknee/simple-matrix-selfhost/issues

## License

MIT License - see [LICENSE](LICENSE) file for details

---

**Made with ❤️ for easy self-hosting**
