#!/bin/bash

# --- Configuration Variables ---
APT_CONF_FILE="/etc/apt/apt.conf.d/00proxy"
PROXY_SERVER=""
PROXY_PORT=""
SOCKS_PORT=""
PROXY_URI=""

# --- Functions ---

# Function to get user input
get_proxy_input() {
    echo "This script will set the APT proxy and the GNOME/GTK System Proxy."
    read -rp "Enter the proxy server address (e.g., proxy.example.com or 192.168.1.1): " PROXY_SERVER
    read -rp "Enter the proxy port number (e.g., 8080 or 3128): " PROXY_PORT
    read -rp "Enter the SOCKS5 port number(e.g. 9095) :" SOCKS_PORT

    if [[ -z "$PROXY_SERVER" || -z "$PROXY_PORT" || -z "$SOCKS_PORT" ]]; then
        echo "❌ Error: Both server address and port are required."
        exit 1
    fi
    PROXY_URI="http://${PROXY_SERVER}:${PROXY_PORT}/"
}

# Function to set APT proxy (requires sudo)
set_apt_proxy() {
    echo "🔧 Setting APT proxy..."

    local PROXY_LINE="Acquire::http::Proxy \"${PROXY_URI}\";"

    # Write to the APT configuration file using sudo
    echo "$PROXY_LINE" | sudo tee "$APT_CONF_FILE" > /dev/null

    if [ $? -eq 0 ]; then
        echo "✅ APT Proxy set in ${APT_CONF_FILE}"
    else
        echo "❌ Failed to set APT Proxy. Check your sudo permissions."
        exit 1
    fi
}

# Function to set GNOME System Proxy (using gsettings)
set_gnome_system_proxy() {
    echo "💻 Setting GNOME/GTK System HTTP/HTTPS Proxy (The 'Network Settings' proxy)..."

    if ! command -v gsettings &> /dev/null; then
        echo "⚠️ Warning: 'gsettings' command not found. This feature is likely only available on GNOME/GTK desktop environments."
        echo "   Skipping system proxy configuration."
        return
    fi
    
    # 1. Set proxy mode to 'manual'
    gsettings set org.gnome.system.proxy mode 'manual'
    
    # 2. Set HTTP proxy
    gsettings set org.gnome.system.proxy.http host "$PROXY_SERVER"
    gsettings set org.gnome.system.proxy.http port "$PROXY_PORT"

    # 3. Set HTTPS proxy (often uses the same settings as HTTP)
    gsettings set org.gnome.system.proxy.https host "$PROXY_SERVER"
    gsettings set org.gnome.system.proxy.https port "$PROXY_PORT"

    # 4. Set SOCKS proxy (for ALL_PROXY/SOCKS5 functionality)
    # Note: GNOME uses 'socks' for all traffic types that use SOCKS.
    gsettings set org.gnome.system.proxy.socks host "$PROXY_SERVER"
    gsettings set org.gnome.system.proxy.socks port "$SOCKS_PORT"


    echo "✅ System HTTP, HTTPS, and SOCKS5 proxies set for the current user's desktop environment."
    echo "💡 You can verify this in your Network Settings panel."
}

# --- Main Script Execution ---

echo "🚀 System Proxy Configuration Script (APT & GNOME/GTK)"
echo "--------------------------------------------------------"


get_proxy_input

set_apt_proxy

set_gnome_system_proxy

echo "--------------------------------------------------------"
echo "Configuration Summary:"
echo "APT Proxy: $(cat "$APT_CONF_FILE" 2>/dev/null)"
echo "GNOME Proxy Mode: $(gsettings get org.gnome.system.proxy mode 2>/dev/null)"
echo "GNOME HTTP Proxy: $(gsettings get org.gnome.system.proxy.http host 2>/dev/null):$(gsettings get org.gnome.system.proxy.http port 2>/dev/null)"
echo "GNOME SOCKS Proxy: $(gsettings get org.gnome.system.proxy.socks host 2>/dev/null):$(gsettings get org.gnome.system.proxy.socks port 2>/dev/null)"
echo "Script finished."
