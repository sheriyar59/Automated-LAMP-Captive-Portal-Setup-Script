#!/bin/bash

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please run with sudo."
    exit 1
fi

# Prompt user for MySQL and Apache configuration details
read -p "Enter MySQL database name: " DB_NAME
read -p "Enter MySQL username: " DB_USER
read -s -p "Enter MySQL password: " DB_PASS
echo
echo 
read -p "Enter your primary domain (e.g., example.com): " DOMAIN
read -p "Enter the captive portal domain (e.g., hotspot.example.com): " DOMAIN_NAME
read -p "Enter your email for SSL certificate registration: " EMAIL

# Set additional variables
WEB_ROOT="/var/www"
REPO_URL="https://github.com/splash-networks/mikrotik-yt-radius-portal"
ENV_FILE="$WEB_ROOT/$DOMAIN_NAME/.env"
APACHE_CONF_PATH="/etc/apache2/sites-available/$DOMAIN_NAME.conf"
COMPOSER_INSTALL_URL="https://getcomposer.org/installer"

# Update and upgrade the system
echo "Updating and upgrading the system..."
sudo apt update && sudo apt upgrade -y

# Install Apache, PHP, and required packages
echo "Installing Apache, PHP, and other dependencies..."
sudo apt install -y apache2 nano curl php php-pear php-curl php-dev php-xml php-gd php-mbstring php-zip php-mysql php-xmlrpc libapache2-mod-php mysql-server git certbot python3-certbot-apache

# Secure MySQL installation
echo "Securing MySQL installation..."
sudo mysql_secure_installation <<EOF

n
y
y
y
y
EOF

# MySQL setup: create database and user
echo "Creating MySQL database and user..."
sudo mysql -u root <<MYSQL
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL

# Uninstall component_validate_password
echo "Uninstalling component_validate_password..."
sudo mysql -u root <<MYSQL
UNINSTALL COMPONENT "file://component_validate_password";
MYSQL

# phpmyadmin setup: 

sudo apt install -y phpmyadmin

# Clone the portal repository
echo "Cloning the portal repository..."
sudo git clone $REPO_URL $WEB_ROOT/$DOMAIN_NAME

# Copy .env.example to .env
echo "Setting up environment variables..."
if [ -f "$WEB_ROOT/$DOMAIN_NAME/.env.example" ]; then
  sudo cp "$WEB_ROOT/$DOMAIN_NAME/.env.example" "$ENV_FILE"
  echo "Edit the .env file to configure environment variables."
else
  echo ".env.example not found in the repository."
fi

# Install Composer
echo "Installing Composer..."
curl -sS $COMPOSER_INSTALL_URL -o composer-setup.php
sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm composer-setup.php

# Run Composer install to install dependencies
echo "Running Composer to install dependencies..."
cd "$WEB_ROOT/$DOMAIN_NAME"
sudo php /usr/local/bin/composer install

# Apache site setup for the primary domain
APACHE_PRIMARY_CONF="/etc/apache2/sites-available/$DOMAIN.conf"
if [ ! -f "$APACHE_PRIMARY_CONF" ]; then
    echo "Creating Apache virtual host for primary domain $DOMAIN..."
    sudo tee "$APACHE_PRIMARY_CONF" > /dev/null <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAdmin webmaster@$DOMAIN
    DocumentRoot /var/www/$DOMAIN
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
    sudo mkdir -p /var/www/$DOMAIN
    sudo a2ensite $DOMAIN.conf
    sudo a2dissite 000-default.conf
fi

# Apache site setup for the captive portal domain
if [ ! -f "$APACHE_CONF_PATH" ]; then
    echo "Configuring Apache Virtual Host for captive portal domain $DOMAIN_NAME..."
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

    # Enable the site and reload Apache
    echo "Enabling captive portal site and reloading Apache..."
    sudo a2ensite $DOMAIN_NAME.conf
fi

# Web Security Configuration
echo "Configuring basic web security..."
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

# Restart Apache to apply web security settings
sudo systemctl reload apache2

# Obtain SSL Certificates with Let's Encrypt
echo "Obtaining SSL certificates for $DOMAIN and $DOMAIN_NAME..."
sudo certbot --apache -d $DOMAIN -d $DOMAIN_NAME --agree-tos --non-interactive --email $EMAIL

echo "Setup complete! Please check the configuration and ensure environment variables are set in $ENV_FILE."
