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
    echo "$PROXY_SERVER"
    echo "This script will set the APT proxy and the GNOME/GTK System Proxy."
    echo "If you want to use the defult gateway as your PROXY keep the proxy server address empty"
    read -rp "Enter the proxy server address (e.g., proxy.example.com or 192.168.1.1): " PROXY_SERVER
    read -rp "Enter the proxy port number (e.g., 10808 or 3128): " PROXY_PORT
    read -rp "Enter the SOCKS5 port number(e.g. 9095) :" SOCKS_PORT
    
    if [[ -z "$PROXY_SERVER" ]]; then
	PROXY_SERVER=$(ip r |  grep '^default' | awk '{print $3}')
	echo "$PROXY_SERVER Address will be used"
    fi 
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

set_snap_proxy() {
    if ![ command -v snap &> /dev/null ]; then
        return 1
    fi

    echo "Setting up proxy for snapd"
    sudo snap set system proxy.http="${PROXY_URI}"
    sudo snap set system proxy.https="${PROXY_URI}"
    echo "Snapd Proxy was setup"

    if sudo systemctl restart snapd; then
        echo "✅snapd is reboot scuccsessfully"
    else
        echo "❌snapd didn\'t reboot do it manualy"
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



#turn off the proxy

turn_off_proxy(){
    if [ -f "$APT_CONF_FILE" ]; then
        echo "Found the apt proxy."
        echo "Clearing the proxy file to disable the apt proxy....."
        sudo truncate -s 0 "$APT_CONF_FILE"

        if [ $? -eq 0 ]; then
            echo "✅ apt proxy is disabeld successfully."   
        else
            echo "❌ Erro. Unable to clear the file"
        fi
    else
        echo "⚠️ Warning: File was not found"
    fi

    echo "🆑 Turn off the gonome desktop proxy setting"
    gsettings set org.gnome.system.proxy mode "none"


}

# --- Main Script Execution ---

echo "🚀 System Proxy Configuration Script (APT,SNAP & GNOME/GTK)"
echo "--------------------------------------------------------"

if [ "$1" -eq -1 ]; then
    turn_off_proxy
    exit 1
fi

get_proxy_input

set_apt_proxy

set_snap_proxy

set_gnome_system_proxy

echo "--------------------------------------------------------"
echo "Configuration Summary:"
echo "APT Proxy: $(cat "$APT_CONF_FILE" 2>/dev/null)"
echo "snapd Proxy: $(sudo snap get system proxy 2>/dev/null)"
echo "GNOME Proxy Mode: $(gsettings get org.gnome.system.proxy mode 2>/dev/null)"
echo "GNOME HTTP Proxy: $(gsettings get org.gnome.system.proxy.http host 2>/dev/null):$(gsettings get org.gnome.system.proxy.http port 2>/dev/null)"
echo "GNOME SOCKS Proxy: $(gsettings get org.gnome.system.proxy.socks host 2>/dev/null):$(gsettings get org.gnome.system.proxy.socks port 2>/dev/null)"
echo "Script finished."
