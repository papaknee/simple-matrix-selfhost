# Summary of Changes

## What Changed

The setup flow and documentation were restructured to fix a critical issue: the Lightsail startup script previously tried to run the full installation (including SSL certificate acquisition) on instance boot, before networking (static IP, firewall) and DNS were configured. This caused the installation to fail.

## New Setup Flow

The setup now follows a correct order of operations:

1. **Create Lightsail instance** — optionally with a launch script that only pre-installs dependencies
2. **Configure networking** — attach a static IP and open firewall ports in the Lightsail console
3. **Configure DNS** — point your domain to the static IP and wait for propagation
4. **Run the setup script** — SSH in and run a single command that interactively configures and installs everything

## Files Changed

### New Files
- **setup.sh** — Interactive setup script that prompts for configuration values (domain, email, passwords), creates the `.env` file, and runs the installation. Can be run via a one-liner: `curl -sSL .../setup.sh | sudo bash`

### Modified Files
- **README.md** — Rewritten with a single, clear linear flow (no more two overlapping paths). Simplified from ~1070 lines to ~400 lines while keeping all essential information.
- **lightsail-startup.sh** — Now only pre-installs dependencies and clones the repo on boot. No longer attempts the full installation, since networking and DNS aren't ready yet.
- **install.sh** — Now installs systemd timers for auto-updates and scheduled reboots (previously only done by `lightsail-startup.sh`).
- **SUMMARY.md** — Updated to reflect the new changes.

## Key Improvements

- **Correct order of operations**: Networking and DNS are configured before running the install, so SSL certificates succeed on the first try
- **Interactive setup**: Users with little command line knowledge can follow prompts instead of manually editing config files
- **Single path**: One clear set of steps instead of two overlapping flows (Quick Start vs Manual)
- **Auto-generated secrets**: Database password and admin console secret key are auto-generated if not provided
- **Simpler documentation**: README is significantly shorter and more focused
