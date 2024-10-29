#!/bin/bash

# Colors
RESET='\033[0m'
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'

# Function to print messages in color
info() { echo -e "${GREEN}$1${RESET}"; }
warn() { echo -e "${YELLOW}$1${RESET}"; }
error() { echo -e "${RED}$1${RESET}"; }

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    error "This script must be run as root. Please run with sudo."
    exit 1
fi

# Prompt user for MySQL and Apache configuration details
read -p "Enter MySQL database name: " DB_NAME
read -p "Enter MySQL username: " DB_USER
read -s -p "Enter MySQL password: " DB_PASS
echo
read -p "Enter the captive portal domain (e.g., hotspot.example.com): " DOMAIN_NAME
read -p "Enter your email for SSL certificate registration: " EMAIL
read -p "Enter the repository URL (e.g., https://github.com/splash-networks/mikrotik-yt-radius-portal): " REPO_URL

# Set additional variables
WEB_ROOT="/var/www"
ENV_FILE="$WEB_ROOT/$DOMAIN_NAME/.env"
APACHE_CONF_PATH="/etc/apache2/sites-available/$DOMAIN_NAME.conf"
COMPOSER_INSTALL_URL="https://getcomposer.org/installer"

# Update and upgrade the system
info "Updating and upgrading the system..."
sudo apt update > /dev/null 2>&1 && sudo apt upgrade -y > /dev/null 2>&1 || error "Failed to update and upgrade the system."

# Install Apache, PHP, and required packages
info "Installing Apache, PHP, and other dependencies..."
sudo apt install -y apache2 nano curl php php-mbstring php-mysql mysql-server git certbot python3-certbot-apache > /dev/null 2>&1 || error "Failed to install dependencies."

# Secure MySQL installation
info "Securing MySQL installation..."
sudo mysql_secure_installation <<EOF
n
y
y
y
y
EOF

# MySQL setup: create database and user
info "Creating MySQL database and user..."
if ! sudo mysql -u root -e "
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;" 2>/dev/null; then
    error "Failed to create MySQL database and user."
    exit 1
fi

# Uninstall component_validate_password with if-else
COMPONENT_STATUS=$(sudo mysql -u root -e "SELECT * FROM mysql.component WHERE component_urn='file://component_validate_password';" 2>/dev/null)
if [[ -n "$COMPONENT_STATUS" ]]; then
    info "Uninstalling component_validate_password..."
    sudo mysql -u root -e "UNINSTALL COMPONENT 'file://component_validate_password';" > /dev/null 2>&1
else
    warn "component_validate_password is not installed."
fi

# Install phpMyAdmin if the user opted for it
info "Installing phpMyAdmin..."
{
    echo "phpmyadmin phpmyadmin/dbconfig-install boolean true"
    echo "phpmyadmin phpmyadmin/app-password-confirm password $DB_PASS"
    echo "phpmyadmin phpmyadmin/mysql/admin-pass password $DB_PASS"
    echo "phpmyadmin phpmyadmin/mysql/app-pass password $DB_PASS"
    echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"
} | sudo debconf-set-selections
sudo apt install -y phpmyadmin > /dev/null 2>&1 || error "Failed to install phpMyAdmin."

# Clone the portal repository
info "Cloning the portal repository..."
sudo git clone $REPO_URL $WEB_ROOT/$DOMAIN_NAME > /dev/null 2>&1 || error "Failed to clone repository."

# Copy .env.example to .env
info "Setting up environment variables..."
if [ -f "$WEB_ROOT/$DOMAIN_NAME/.env.example" ]; then
    sudo cp "$WEB_ROOT/$DOMAIN_NAME/.env.example" "$ENV_FILE"
    info "Environment file copied. Configure variables in $ENV_FILE."
else
    error ".env.example not found in the repository."
fi

# Install Composer
info "Installing Composer..."
curl -sS $COMPOSER_INSTALL_URL -o composer-setup.php
sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer > /dev/null 2>&1
rm composer-setup.php || error "Failed to install Composer."

# Run Composer install to install dependencies
info "Running Composer to install dependencies..."
cd "$WEB_ROOT/$DOMAIN_NAME/public" || exit

# Run Composer with debug output
if ! composer install; then
    error "Composer failed to install dependencies."
    echo "Debugging output for Composer installation:"
    composer install --verbose
    exit 1
fi

# Apache site setup for the captive portal domain
if [ ! -f "$APACHE_CONF_PATH" ]; then
    info "Configuring Apache Virtual Host for captive portal domain $DOMAIN_NAME..."
    sudo tee "$APACHE_CONF_PATH" > /dev/null <<EOL
<VirtualHost *:80>
    ServerName $DOMAIN_NAME
    DocumentRoot $WEB_ROOT/$DOMAIN_NAME/public

    <Directory $WEB_ROOT/$DOMAIN_NAME/public>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/${DOMAIN_NAME}_error.log
    CustomLog \${APACHE_LOG_DIR}/${DOMAIN_NAME}_access.log combined
</VirtualHost>
EOL

    sudo a2ensite $DOMAIN_NAME.conf > /dev/null 2>&1
fi

# Web Security Configuration
info "Configuring basic web security..."
sudo tee -a /etc/apache2/apache2.conf > /dev/null <<EOF

<Directory /var/www/>
    Options -Indexes +FollowSymLinks
    AllowOverride All
</Directory>

<Files .env>
    Order allow,deny
    Deny from all
</Files>
EOF
sudo systemctl reload apache2 > /dev/null 2>&1

# Obtain SSL Certificates with Let's Encrypt
info "Obtaining SSL certificates for $DOMAIN_NAME..."
sudo certbot --apache -d $DOMAIN_NAME --agree-tos --non-interactive --email $EMAIL > /dev/null 2>&1

info "Setup complete! Please configure environment variables in $ENV_FILE."
