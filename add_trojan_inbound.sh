#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Fatal error: ${plain} Please run this script with root privilege \n " && exit 1

gen_random_string() {
    local length="$1"
    local random_string=$(LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w "$length" | head -n 1)
    echo "$random_string"
}

# Get panel login info
panel_user=$(/usr/local/x-ui/x-ui setting -show true 2>/dev/null | grep -Eo 'username: .+' | awk '{print $2}')
panel_pass=$(/usr/local/x-ui/x-ui setting -show true 2>/dev/null | grep -Eo 'password: .+' | awk '{print $2}')
webBasePath=$(/usr/local/x-ui/x-ui setting -show true 2>/dev/null | grep -Eo 'webBasePath: .+' | awk '{print $2}')
panel_port=$(/usr/local/x-ui/x-ui setting -show true 2>/dev/null | grep -Eo 'port: .+' | awk '{print $2}')
webBasePath=$(echo "$webBasePath" | sed 's#^/*##;s#/*$##')

if [ -z "$panel_user" ] || [ -z "$panel_pass" ] || [ -z "$panel_port" ]; then
    echo -e "${red}Error: Could not retrieve x-ui panel login information. Please ensure x-ui is installed and running.${plain}"
    exit 1
fi

# Get SSL certificate and key file paths from x-ui settings
cert_file=$(/usr/local/x-ui/x-ui setting -show true 2>/dev/null | grep -Eo 'subCertFile: .+' | awk '{print $2}')
key_file=$(/usr/local/x-ui/x-ui setting -show true 2>/dev/null | grep -Eo 'subKeyFile: .+' | awk '{print $2}')

if [ -z "$cert_file" ] || [ -z "$key_file" ]; then
    echo -e "${red}Error: Could not retrieve SSL certificate and key file paths from x-ui settings. Please ensure SSL is configured in x-ui.${plain}"
    exit 1
fi

# Extract domain from certificate file path (assuming acme.sh structure)
domain=$(basename $(dirname "$cert_file"))

# Generate random port, user, password
trojan_port=$(shuf -i 10000-60000 -n 1)
trojan_user=$(gen_random_string 12)
trojan_pass=$(gen_random_string 16)
remark="Trojan_$(date +%y%m%d)$(gen_random_string 5)"

echo -e "${yellow}Adding Trojan inbound with port ${trojan_port}, user ${trojan_user}, remark ${remark}...${plain}"

# Login to get cookie
curl -s -c /tmp/xui_cookie.txt -d "username=${panel_user}&password=${panel_pass}" \
  "http://127.0.0.1:${panel_port}/${webBasePath}/panel/login" >/dev/null

# Add inbound via API
curl -s -b /tmp/xui_cookie.txt -X POST "http://127.0.0.1:${panel_port}/${webBasePath}/panel/inbound/add" \
  -d "remark=${remark}" \
  -d "enable=true" \
  -d "listen=" \
  -d "port=${trojan_port}" \
  -d "protocol=trojan" \
  -d "settings={\"clients\":[{\"email\":\"${trojan_user}\",\"password\":\"${trojan_pass}\"}]}" \
  -d "streamSettings={\"network\":\"tcp\",\"security\":\"tls\",\"tlsSettings\":{\"certificates\":[{\"certificateFile\":\"${cert_file}\",\"keyFile\":\"${key_file}\"}],\"alpn\":[\"h3\",\"h2\",\"http/1.1\"]}}" \
  -d "sniffing={}" \
  -d "allocate={}" \
  >/tmp/xui_add_inbound_result

# Check API call result
if grep -q '"success":true' /tmp/xui_add_inbound_result; then
    echo -e "${green}Trojan inbound added successfully.${plain}"
    echo -e "${green}Trojan Client URL:${plain}"
    echo -e "${blue}trojan://${trojan_user}@${domain}:${trojan_port}?type=tcp&security=tls&fp=chrome&alpn=h3%2Ch2%2Chttp%2F1.1#${remark}${plain}"
else
    echo -e "${red}Failed to add Trojan inbound.${plain}"
    echo -e "${red}API response:${plain}"
    cat /tmp/xui_add_inbound_result
fi

# Clean up cookie and result files
rm -f /tmp/xui_cookie.txt
rm -f /tmp/xui_add_inbound_result
