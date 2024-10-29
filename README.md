# Automated LAMP & Captive Portal Setup Script
This repository contains a bash script that automates the setup of a LAMP (Linux, Apache, MySQL, PHP) stack with a captive portal environment for a Mikrotik Hotspot. This script is ideal for quickly deploying a secure, configurable web-based captive portal backed by a MySQL database and administered via phpMyAdmin. It also supports Let's Encrypt SSL for both the primary and captive portal domains.

## Features
### Automated System Update: Keeps the system up-to-date with the latest patches.
- **Apache & PHP Installation:** Installs Apache, PHP, and all required PHP extensions.
- **MySQL Database Setup:** Secures MySQL installation, creates a new database, and a user with permissions.
- **Component Removal**: Removes component_validate_password from MySQL to prevent conflicts.
- **phpMyAdmin Installation:** Provides an easy interface to manage the MySQL database.
- **Git Repository Clone:** Clones the specified captive portal repository.
- **Environment Setup:** Configures environment variables for the cloned project.
- **Composer Installation:** Sets up Composer to handle PHP dependencies.
- **Apache Virtual Host Configuration:** Creates virtual hosts for both primary and captive portal domains.
- **Optional SSL Setup:** Uses Let's Encrypt to secure connections with an SSL certificate.
- **Error Handling and Logging:** Provides feedback at each step to simplify troubleshooting.
Usage
Clone this repository:

```
Copy code
git clone https://github.com/sheriyar59/Automated-LAMP-Captive-Portal-Setup-Script
cd Automated-LAMP-Captive-Portal-Setup-Script/
chmod +x setup_script.sh 
sudo ./setup_script.sh
```
Follow the on-screen prompts to provide necessary configuration details like MySQL credentials, domain names, and email for SSL registration.

## Prerequisites
- Ubuntu-based system
- Root access (or sudo privileges)
- A configured Mikrotik router for Hotspot functionality
## Customization
- Database Credentials: Modify the MySQL credentials by changing variables in the script (DB_NAME, DB_USER, DB_PASS).
- Git Repository URL: Update the REPO_URL variable to use a different captive portal repository.
- SSL Configuration: Uncomment the SSL section if SSL certificates are required.
## Important Notes
- Ensure that the captive portal repository is compatible with the LAMP stack configuration.
- Make sure to verify Apache and MySQL installations for compatibility with your environment.
## Disclaimer
- This script is provided "as-is" without any warranties. Use at your own risk, and verify all commands before running them in a production environment.
