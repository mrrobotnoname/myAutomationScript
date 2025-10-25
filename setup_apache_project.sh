#!/bin/bash

# ==============================================================================
# Apache Project Setup Script (Non-Sudo Execution)
# Usage: ./setup_project.sh <project_name>
# Example: ./setup_project.sh my_php_app
# This script prompts for your password when it needs administrative privileges.
# ==============================================================================



PROJECT_NAME="$1"

if [ -z "$PROJECT_NAME" ]; then
    echo "Error: Please provide a project name."
    echo "Usage: ./setup_project.sh <project_name>"
    exit 1
fi

# Determine the user running the script (since we aren't using sudo initially, this is correct)
REAL_USER=$(whoami)

SERVER_NAME="${PROJECT_NAME}.local"
CONF_NAME="${PROJECT_NAME}.conf"

# The absolute path for the DocumentRoot
PROJECT_PATH="/var/www/${PROJECT_NAME}"

APACHE_CONFIG_DIR="/etc/apache2/sites-available"
APACHE_CONFIG_PATH="${APACHE_CONFIG_DIR}/${CONF_NAME}"


echo "--- Starting Apache Project Setup for ${SERVER_NAME} ---"
echo "Target User: ${REAL_USER}"
echo "Document Root: ${PROJECT_PATH}"
echo "Config File: ${APACHE_CONFIG_PATH}"

# --- 2. Create Project Folder and Set Permissions ---

echo -e "\n[STEP 1/5] Creating project directory and setting permissions..."
sudo mkdir -p "${PROJECT_PATH}"
if [ $? -eq 0 ]; then
    echo "  > Directory created successfully."
    # Ensure the real user owns the folder and set 755 for Apache (no sudo needed here)
    chown -R "${REAL_USER}":"${REAL_USER}" "${PROJECT_PATH}"
    chmod -R 755 "${PROJECT_PATH}"
    echo "  > Ownership and permissions (755) set."
else
    echo "  > ❌ Error: Could not create project directory."
    exit 1
fi

# --- 3. Create Apache Site Configuration (Requires SUDO) ---

echo -e "\n[STEP 2/5] Creating Apache configuration file: ${CONF_NAME} (Requires password)"

# Use 'sudo bash -c' to write the file with root privileges
# This ensures the redirection '>' works on the system directory.
sudo bash -c "cat > ${APACHE_CONFIG_PATH}" <<EOL
<VirtualHost *:80>
    ServerName ${SERVER_NAME}

    DocumentRoot ${PROJECT_PATH}

    <Directory "${PROJECT_PATH}">
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/${PROJECT_NAME}_error.log
    CustomLog \${APACHE_LOG_DIR}/${PROJECT_NAME}_access.log combined
</VirtualHost>
EOL

if [ $? -eq 0 ]; then
    echo "  > Configuration file created successfully."
else
    echo "  > ❌ Error: Could not create config file. Check permissions."
    exit 1
fi

# --- 4. Enable Site and Reload Apache (Requires SUDO) ---

echo -e "\n[STEP 3/5] Enabling site and checking Apache configuration (Requires password)..."
sudo a2ensite "${CONF_NAME}" > /dev/null

echo -e "\n[STEP 4/5] Testing config and reloading Apache service (Requires password)..."
sudo apache2ctl configtest
if [ $? -ne 0 ]; then
    echo "  > ❌ Error: Apache configuration test failed. Check the syntax in ${APACHE_CONFIG_PATH}"
    exit 1
fi

sudo systemctl reload apache2
if [ $? -ne 0 ]; then
    echo "  > ❌ Error: Failed to reload apache2. Check its status."
    exit 1
fi
echo "  > Site enabled and Apache reloaded successfully."

# --- 5. Add Local Domain to /etc/hosts (Requires SUDO) ---

echo -e "\n[STEP 5/5] Updating /etc/hosts for local domain: ${SERVER_NAME} (Requires password)"
HOSTS_LINE="127.0.0.1 ${SERVER_NAME}"

# Check if the entry already exists
if ! grep -q "${HOSTS_LINE}" /etc/hosts; then
   
    echo "${HOSTS_LINE}" | sudo tee -a /etc/hosts > /dev/null
    echo "  > Host entry added: ${SERVER_NAME}"
else
    echo "  > Host entry already exists."
fi

# --- Final Instructions ---
echo -e "\n========================================================="
echo "✅ SETUP COMPLETE! Your project is now configured."
echo "Access it via: http://${SERVER_NAME}"
echo "========================================================="

echo "---------------------------------------------------------"
echo"⚠️  This script use .local domain so if you are using proxy please add .local to the ignore hosts "
echo "---------------------------------------------------------"
