#!/bin/bash

#===============================================================================
# Ubuntu Server Setup Script
# Version: 2.0
# Description: Comprehensive Ubuntu server installation and configuration script
# Compatible: Ubuntu 20.04 LTS, 22.04 LTS
# Author: System Administrator
# License: MIT
#===============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

#===============================================================================
# CONFIGURATION SECTION - Customize these variables as needed
#===============================================================================

# Basic Configuration
readonly SCRIPT_NAME="Ubuntu Server Setup"
readonly SCRIPT_VERSION="2.0"
readonly LOG_FILE="/var/log/server-setup.log"
readonly BACKUP_DIR="/root/server-setup-backup-$(date +%Y%m%d-%H%M%S)"

# User Configuration
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"  # Leave empty to generate random password
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-}"  # SSH public key for admin user

# Security Configuration
SSH_PORT="${SSH_PORT:-22}"
DISABLE_ROOT_LOGIN="${DISABLE_ROOT_LOGIN:-true}"
ENABLE_UFW="${ENABLE_UFW:-true}"
INSTALL_FAIL2BAN="${INSTALL_FAIL2BAN:-true}"

# Service Configuration
TIMEZONE="${TIMEZONE:-UTC}"
INSTALL_DOCKER="${INSTALL_DOCKER:-false}"
INSTALL_NGINX="${INSTALL_NGINX:-false}"
INSTALL_NODEJS="${INSTALL_NODEJS:-false}"
NODEJS_VERSION="${NODEJS_VERSION:-18}"

# Feature Toggles
SKIP_UPDATES="${SKIP_UPDATES:-false}"
SKIP_SECURITY="${SKIP_SECURITY:-false}"
SKIP_MONITORING="${SKIP_MONITORING:-false}"
SKIP_CLEANUP="${SKIP_CLEANUP:-false}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

#===============================================================================
# UTILITY FUNCTIONS
#===============================================================================

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

# Print colored output
print_status() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
    log "INFO" "${message}"
}

# Print section header
print_header() {
    local title="$1"
    echo
    print_status "${PURPLE}" "==============================================================================="
    print_status "${PURPLE}" " ${title}"
    print_status "${PURPLE}" "==============================================================================="
}

# Print progress
print_progress() {
    local message="$1"
    print_status "${BLUE}" "➤ ${message}"
}

# Print success
print_success() {
    local message="$1"
    print_status "${GREEN}" "✓ ${message}"
}

# Print warning
print_warning() {
    local message="$1"
    print_status "${YELLOW}" "⚠ ${message}"
}

# Print error and exit
print_error() {
    local message="$1"
    print_status "${RED}" "✗ ERROR: ${message}"
    log "ERROR" "${message}"
    exit 1
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if package is installed
package_installed() {
    dpkg -l "$1" >/dev/null 2>&1
}

# Generate random password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Backup file if it exists
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        mkdir -p "${BACKUP_DIR}"
        cp "$file" "${BACKUP_DIR}/$(basename "$file").backup"
        print_progress "Backed up $file"
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
    fi
}

# Detect Ubuntu version
detect_ubuntu_version() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" != "ubuntu" ]]; then
            print_error "This script is designed for Ubuntu only. Detected: $ID"
        fi
        
        case "$VERSION_ID" in
            "20.04"|"22.04")
                print_success "Detected Ubuntu $VERSION_ID LTS"
                ;;
            *)
                print_warning "Ubuntu version $VERSION_ID may not be fully supported"
                ;;
        esac
    else
        print_error "Cannot detect Ubuntu version"
    fi
}

#===============================================================================
# VALIDATION FUNCTIONS
#===============================================================================

validate_configuration() {
    print_header "Validating Configuration"
    
    # Validate SSH port
    if [[ ! "$SSH_PORT" =~ ^[0-9]+$ ]] || [[ "$SSH_PORT" -lt 1 ]] || [[ "$SSH_PORT" -gt 65535 ]]; then
        print_error "Invalid SSH port: $SSH_PORT"
    fi
    
    # Validate admin username
    if [[ ! "$ADMIN_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        print_error "Invalid admin username: $ADMIN_USER"
    fi
    
    # Check if admin user already exists
    if id "$ADMIN_USER" &>/dev/null; then
        print_warning "User $ADMIN_USER already exists"
    fi
    
    # Validate timezone
    if [[ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]]; then
        print_error "Invalid timezone: $TIMEZONE"
    fi
    
    print_success "Configuration validation completed"
}

#===============================================================================
# SYSTEM UPDATE FUNCTIONS
#===============================================================================

update_system() {
    if [[ "$SKIP_UPDATES" == "true" ]]; then
        print_warning "Skipping system updates"
        return 0
    fi
    
    print_header "System Updates and Package Management"
    
    print_progress "Updating package lists..."
    apt-get update -qq
    
    print_progress "Upgrading installed packages..."
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
    
    print_progress "Installing essential packages..."
    local essential_packages=(
        curl wget git vim nano htop tree unzip zip
        software-properties-common apt-transport-https ca-certificates
        gnupg lsb-release build-essential dkms linux-headers-generic
        ufw fail2ban logrotate rsyslog cron
        net-tools dnsutils telnet nmap
        sysstat iotop iftop nethogs
        rkhunter chkrootkit lynis
        unattended-upgrades update-notifier-common
    )
    
    for package in "${essential_packages[@]}"; do
        if ! package_installed "$package"; then
            print_progress "Installing $package..."
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$package"
        fi
    done
    
    print_success "System updates completed"
}

configure_automatic_updates() {
    print_header "Configuring Automatic Security Updates"
    
    # Configure unattended-upgrades
    backup_file "/etc/apt/apt.conf.d/50unattended-upgrades"
    
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::Package-Blacklist {
};

Unattended-Upgrade::DevRelease "false";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF

    # Enable automatic updates
    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

    systemctl enable unattended-upgrades
    systemctl start unattended-upgrades
    
    print_success "Automatic security updates configured"
}

#===============================================================================
# USER MANAGEMENT FUNCTIONS
#===============================================================================

setup_admin_user() {
    print_header "User Management and Sudo Configuration"
    
    if ! id "$ADMIN_USER" &>/dev/null; then
        print_progress "Creating admin user: $ADMIN_USER"
        
        # Generate password if not provided
        if [[ -z "$ADMIN_PASSWORD" ]]; then
            ADMIN_PASSWORD=$(generate_password)
            print_warning "Generated password for $ADMIN_USER: $ADMIN_PASSWORD"
            echo "Admin user: $ADMIN_USER" >> "${BACKUP_DIR}/credentials.txt"
            echo "Admin password: $ADMIN_PASSWORD" >> "${BACKUP_DIR}/credentials.txt"
        fi
        
        # Create user
        useradd -m -s /bin/bash "$ADMIN_USER"
        echo "$ADMIN_USER:$ADMIN_PASSWORD" | chpasswd
        
        # Add to sudo group
        usermod -aG sudo "$ADMIN_USER"
        
        print_success "Admin user $ADMIN_USER created"
    else
        print_warning "User $ADMIN_USER already exists"
    fi
    
    # Setup SSH directory and keys
    local ssh_dir="/home/$ADMIN_USER/.ssh"
    if [[ ! -d "$ssh_dir" ]]; then
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
        chown "$ADMIN_USER:$ADMIN_USER" "$ssh_dir"
    fi
    
    # Add SSH public key if provided
    if [[ -n "$SSH_PUBLIC_KEY" ]]; then
        echo "$SSH_PUBLIC_KEY" >> "$ssh_dir/authorized_keys"
        chmod 600 "$ssh_dir/authorized_keys"
        chown "$ADMIN_USER:$ADMIN_USER" "$ssh_dir/authorized_keys"
        print_success "SSH public key added for $ADMIN_USER"
    fi
    
    # Configure sudo without password for admin user (optional)
    if [[ ! -f "/etc/sudoers.d/$ADMIN_USER" ]]; then
        echo "$ADMIN_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$ADMIN_USER"
        chmod 440 "/etc/sudoers.d/$ADMIN_USER"
        print_success "Sudo access configured for $ADMIN_USER"
    fi
}

#===============================================================================
# SECURITY CONFIGURATION FUNCTIONS
#===============================================================================

configure_ssh() {
    if [[ "$SKIP_SECURITY" == "true" ]]; then
        print_warning "Skipping SSH configuration"
        return 0
    fi
    
    print_header "SSH Security Hardening"
    
    backup_file "/etc/ssh/sshd_config"
    
    # SSH hardening configuration
    cat > /etc/ssh/sshd_config << EOF
# SSH Configuration - Security Hardened
Port $SSH_PORT
Protocol 2

# Authentication
PermitRootLogin $([ "$DISABLE_ROOT_LOGIN" == "true" ] && echo "no" || echo "yes")
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Security Settings
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server

# Connection Settings
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 10
LoginGraceTime 60

# Restrict Users
AllowUsers $ADMIN_USER
EOF

    # Test SSH configuration
    if sshd -t; then
        systemctl restart sshd
        print_success "SSH configuration updated (Port: $SSH_PORT)"
    else
        print_error "SSH configuration test failed"
    fi
}

configure_firewall() {
    if [[ "$SKIP_SECURITY" == "true" ]] || [[ "$ENABLE_UFW" != "true" ]]; then
        print_warning "Skipping firewall configuration"
        return 0
    fi
    
    print_header "Firewall Configuration (UFW)"
    
    # Reset UFW to defaults
    ufw --force reset
    
    # Default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH
    ufw allow "$SSH_PORT/tcp" comment "SSH"
    
    # Allow common services if installed
    if [[ "$INSTALL_NGINX" == "true" ]]; then
        ufw allow 80/tcp comment "HTTP"
        ufw allow 443/tcp comment "HTTPS"
    fi
    
    # Enable UFW
    ufw --force enable
    
    print_success "UFW firewall configured and enabled"
}

configure_fail2ban() {
    if [[ "$SKIP_SECURITY" == "true" ]] || [[ "$INSTALL_FAIL2BAN" != "true" ]]; then
        print_warning "Skipping Fail2Ban configuration"
        return 0
    fi
    
    print_header "Fail2Ban Configuration"
    
    # Create custom jail configuration
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

    systemctl enable fail2ban
    systemctl restart fail2ban
    
    print_success "Fail2Ban configured and started"
}

harden_system() {
    if [[ "$SKIP_SECURITY" == "true" ]]; then
        print_warning "Skipping system hardening"
        return 0
    fi
    
    print_header "System Security Hardening"
    
    # Kernel parameter hardening
    backup_file "/etc/sysctl.conf"
    
    cat >> /etc/sysctl.conf << 'EOF'

# Security hardening parameters
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
kernel.exec-shield = 1
kernel.randomize_va_space = 2
EOF

    sysctl -p
    
    # Set proper file permissions
    chmod 644 /etc/passwd
    chmod 600 /etc/shadow
    chmod 644 /etc/group
    chmod 600 /etc/gshadow
    
    print_success "System hardening completed"
}

#===============================================================================
# SYSTEM CONFIGURATION FUNCTIONS
#===============================================================================

configure_timezone() {
    print_header "Network Time Synchronization"
    
    print_progress "Setting timezone to $TIMEZONE"
    timedatectl set-timezone "$TIMEZONE"
    
    print_progress "Configuring NTP synchronization"
    timedatectl set-ntp true
    
    # Install and configure chrony for better time sync
    if ! package_installed chrony; then
        apt-get install -y chrony
    fi
    
    systemctl enable chrony
    systemctl start chrony
    
    print_success "Timezone and NTP configured"
    timedatectl status
}

configure_logging() {
    print_header "Log Rotation Setup"
    
    # Configure logrotate for custom logs
    cat > /etc/logrotate.d/server-setup << 'EOF'
/var/log/server-setup.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF

    # Ensure rsyslog is running
    systemctl enable rsyslog
    systemctl start rsyslog
    
    print_success "Log rotation configured"
}

#===============================================================================
# MONITORING AND TOOLS FUNCTIONS
#===============================================================================

install_monitoring_tools() {
    if [[ "$SKIP_MONITORING" == "true" ]]; then
        print_warning "Skipping monitoring tools installation"
        return 0
    fi
    
    print_header "Installing Monitoring Tools"
    
    local monitoring_packages=(
        glances
        ncdu
        tmux
        screen
        lsof
        strace
        tcpdump
        wireshark-common
    )
    
    for package in "${monitoring_packages[@]}"; do
        if ! package_installed "$package"; then
            print_progress "Installing $package..."
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$package"
        fi
    done
    
    # Configure sysstat
    if package_installed sysstat; then
        sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
        systemctl enable sysstat
        systemctl start sysstat
    fi
    
    print_success "Monitoring tools installed"
}

#===============================================================================
# OPTIONAL SERVICES FUNCTIONS
#===============================================================================

install_docker() {
    if [[ "$INSTALL_DOCKER" != "true" ]]; then
        return 0
    fi
    
    print_header "Installing Docker"
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt-get update -qq
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Add admin user to docker group
    usermod -aG docker "$ADMIN_USER"
    
    # Enable and start Docker
    systemctl enable docker
    systemctl start docker
    
    print_success "Docker installed and configured"
}

install_nginx() {
    if [[ "$INSTALL_NGINX" != "true" ]]; then
        return 0
    fi
    
    print_header "Installing Nginx"
    
    apt-get install -y nginx
    
    # Basic Nginx configuration
    backup_file "/etc/nginx/nginx.conf"
    
    # Enable and start Nginx
    systemctl enable nginx
    systemctl start nginx
    
    # Create a simple index page
    cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Server Ready</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }
        .container { max-width: 600px; margin: 0 auto; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Server Setup Complete</h1>
        <p>Your Ubuntu server has been successfully configured and is ready for use.</p>
        <p>Nginx is running and serving this page.</p>
    </div>
</body>
</html>
EOF

    print_success "Nginx installed and configured"
}

install_nodejs() {
    if [[ "$INSTALL_NODEJS" != "true" ]]; then
        return 0
    fi
    
    print_header "Installing Node.js"
    
    # Install NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_${NODEJS_VERSION}.x | bash -
    
    # Install Node.js
    apt-get install -y nodejs
    
    # Install global packages
    npm install -g pm2 yarn
    
    print_success "Node.js ${NODEJS_VERSION} installed with PM2 and Yarn"
}

#===============================================================================
# CLEANUP AND FINALIZATION FUNCTIONS
#===============================================================================

cleanup_system() {
    if [[ "$SKIP_CLEANUP" == "true" ]]; then
        print_warning "Skipping system cleanup"
        return 0
    fi
    
    print_header "System Cleanup"
    
    print_progress "Removing unnecessary packages..."
    apt-get autoremove -y -qq
    
    print_progress "Cleaning package cache..."
    apt-get autoclean -qq
    
    print_progress "Updating locate database..."
    if command_exists updatedb; then
        updatedb
    fi
    
    print_success "System cleanup completed"
}

generate_report() {
    print_header "Setup Report Generation"
    
    local report_file="${BACKUP_DIR}/setup-report.txt"
    
    cat > "$report_file" << EOF
===============================================================================
Ubuntu Server Setup Report
Generated: $(date)
===============================================================================

SYSTEM INFORMATION:
- OS: $(lsb_release -d | cut -f2)
- Kernel: $(uname -r)
- Hostname: $(hostname)
- IP Address: $(hostname -I | awk '{print $1}')

CONFIGURATION:
- Admin User: $ADMIN_USER
- SSH Port: $SSH_PORT
- Timezone: $TIMEZONE
- UFW Enabled: $ENABLE_UFW
- Fail2Ban Enabled: $INSTALL_FAIL2BAN

INSTALLED SERVICES:
- Docker: $INSTALL_DOCKER
- Nginx: $INSTALL_NGINX
- Node.js: $INSTALL_NODEJS

SECURITY FEATURES:
- Automatic Updates: Enabled
- SSH Hardening: Enabled
- Firewall (UFW): $ENABLE_UFW
- Fail2Ban: $INSTALL_FAIL2BAN
- System Hardening: Enabled

IMPORTANT FILES:
- Setup Log: $LOG_FILE
- Backup Directory: $BACKUP_DIR
- SSH Config: /etc/ssh/sshd_config

NEXT STEPS:
1. Test SSH connection on port $SSH_PORT
2. Configure additional firewall rules if needed
3. Set up SSL certificates for web services
4. Configure backup solutions
5. Set up monitoring and alerting

===============================================================================
EOF

    print_success "Setup report generated: $report_file"
    
    # Display summary
    print_header "Setup Summary"
    echo
    print_success "✓ System updates and security hardening completed"
    print_success "✓ Admin user '$ADMIN_USER' created with sudo access"
    print_success "✓ SSH hardened and configured on port $SSH_PORT"
    [[ "$ENABLE_UFW" == "true" ]] && print_success "✓ UFW firewall enabled"
    [[ "$INSTALL_FAIL2BAN" == "true" ]] && print_success "✓ Fail2Ban configured"
    print_success "✓ Automatic security updates enabled"
    print_success "✓ Monitoring tools installed"
    [[ "$INSTALL_DOCKER" == "true" ]] && print_success "✓ Docker installed"
    [[ "$INSTALL_NGINX" == "true" ]] && print_success "✓ Nginx web server installed"
    [[ "$INSTALL_NODEJS" == "true" ]] && print_success "✓ Node.js runtime installed"
    echo
    print_warning "⚠ Important: Test SSH connection before closing current session!"
    print_warning "⚠ SSH Port: $SSH_PORT"
    [[ -n "$ADMIN_PASSWORD" ]] && print_warning "⚠ Admin password saved in: ${BACKUP_DIR}/credentials.txt"
    echo
}

#===============================================================================
# MAIN EXECUTION FUNCTIONS
#===============================================================================

show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

USAGE:
    sudo bash $0 [OPTIONS]

ENVIRONMENT VARIABLES:
    ADMIN_USER          Admin username (default: admin)
    ADMIN_PASSWORD      Admin password (default: auto-generated)
    SSH_PUBLIC_KEY      SSH public key for admin user
    SSH_PORT            SSH port (default: 22)
    TIMEZONE            System timezone (default: UTC)
    INSTALL_DOCKER      Install Docker (default: false)
    INSTALL_NGINX       Install Nginx (default: false)
    INSTALL_NODEJS      Install Node.js (default: false)
    NODEJS_VERSION      Node.js version (default: 18)

SKIP OPTIONS:
    SKIP_UPDATES        Skip system updates
    SKIP_SECURITY       Skip security configuration
    SKIP_MONITORING     Skip monitoring tools
    SKIP_CLEANUP        Skip system cleanup

EXAMPLES:
    # Basic setup
    sudo bash $0

    # Custom admin user and SSH port
    sudo ADMIN_USER=myuser SSH_PORT=2222 bash $0

    # Install with Docker and Nginx
    sudo INSTALL_DOCKER=true INSTALL_NGINX=true bash $0

    # Skip certain sections
    sudo SKIP_UPDATES=true SKIP_MONITORING=true bash $0

For more information, visit: https://github.com/your-repo/ubuntu-server-setup
EOF
}

main() {
    # Handle help option
    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        show_help
        exit 0
    fi
    
    # Initialize
    print_header "$SCRIPT_NAME v$SCRIPT_VERSION"
    print_progress "Starting Ubuntu server setup..."
    
    # Create log file and backup directory
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$BACKUP_DIR"
    touch "$LOG_FILE"
    
    log "INFO" "Starting $SCRIPT_NAME v$SCRIPT_VERSION"
    log "INFO" "Backup directory: $BACKUP_DIR"
    
    # Pre-flight checks
    check_root
    detect_ubuntu_version
    validate_configuration
    
    # Main setup phases
    update_system
    configure_automatic_updates
    setup_admin_user
    configure_ssh
    configure_firewall
    configure_fail2ban
    harden_system
    configure_timezone
    configure_logging
    install_monitoring_tools
    
    # Optional services
    install_docker
    install_nginx
    install_nodejs
    
    # Finalization
    cleanup_system
    generate_report
    
    print_header "Setup Complete!"
    print_success "Ubuntu server setup completed successfully!"
    print_success "Log file: $LOG_FILE"
    print_success "Backup directory: $BACKUP_DIR"
    
    log "INFO" "Setup completed successfully"
}

#===============================================================================
# SCRIPT EXECUTION
#===============================================================================

# Trap errors and cleanup
trap 'print_error "Script failed at line $LINENO"' ERR

# Execute main function
main "$@"

exit 0