#!/bin/bash
#usage:cd /usr/local/x-ui
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

echo -e "${yellow}Please ensure your x-ui panel is running and accessible on port ${plain}${blue}${panel_port}${yellow} before running this script.${plain}"
echo -e "${yellow}You can check panel status with: systemctl status x-ui${plain}"
echo -e "${yellow}You can check listening ports with: ss -tulnp | grep x-ui${plain}"
echo ""

# Get panel login info
panel_user=$(/usr/local/x-ui/x-ui setting -show true 2>/dev/null | grep -Eo 'username: .+' | awk '{print $2}')
panel_pass=$(/usr/local/x-ui/x-ui setting -show true 2>/dev/null | grep -Eo 'password: .+' | awk '{print $2}')
webBasePath=$(/usr/local/x-ui/x-ui setting -show true 2>/dev/null | grep -Eo 'webBasePath: .+' | awk '{print $2}')
panel_port=$(/usr/local/x-ui/x-ui setting -show true 2>/dev/null | grep -Eo 'port: .+' | awk '{print $2}')
webBasePath=$(echo "$webBasePath" | sed 's#^/*##;s#/*$##')

echo "Debug: panel_user = $panel_user"
echo "Debug: panel_pass = $panel_pass"
echo "Debug: panel_port = $panel_port"
echo "Debug: webBasePath = $webBasePath"

if [ -z "$panel_user" ] || [ -z "$panel_pass" ] || [ -z "$panel_port" ]; then
    echo -e "${red}Error: Could not retrieve x-ui panel login information. Please ensure x-ui is installed and running.${plain}"
    exit 1
fi

# Get SSL certificate and key file paths from Nginx config
nginx_config_file="/etc/nginx/conf.d/default_site.conf"

if [ ! -f "$nginx_config_file" ]; then
    echo -e "${red}Error: Nginx config file not found: $nginx_config_file${plain}"
    exit 1
fi

cert_file=$(sed -n 's/^\s*ssl_certificate\s*\(.*\);/\1/p' "$nginx_config_file" | head -n1)
key_file=$(sed -n 's/^\s*ssl_certificate_key\s*\(.*\);/\1/p' "$nginx_config_file" | head -n1)

echo "Debug: cert_file = $cert_file"
echo "Debug: key_file = $key_file"

if [ -z "$cert_file" ] || [ -z "$key_file" ]; then
    echo -e "${red}Error: Could not retrieve SSL certificate and key file paths from Nginx config. Please ensure SSL is configured in Nginx.${plain}"
    #exit 1
fi

# Check if cert and key files exist
if [ ! -f "$cert_file" ]; then
    echo -e "${red}Error: Certificate file not found: $cert_file${plain}"
    #exit 1
fi
if [ ! -f "$key_file" ]; then
    echo -e "${red}Error: Key file not found: $key_file${plain}"
    #exit 1
fi

# Use domain from command line argument or default to localhost
domain=${1:-"127.0.0.1"}

# Generate random port, user, password
trojan_port=$(shuf -i 10000-60000 -n 1)
trojan_user=$(gen_random_string 12)
trojan_pass=$(gen_random_string 16)
remark="Trojan_$(date +%y%m%d)$(gen_random_string 5)"

echo -e "${yellow}Adding Trojan inbound with port ${trojan_port}, user ${trojan_user}, remark ${remark}...${plain}"
login_url="https://${domain}:${panel_port}/${webBasePath}/panel/login"
add_inbound_url="https://${domain}:${panel_port}/${webBasePath}/panel/inbound/add"
echo "Debug: login_url = $login_url"
echo "Debug: add_inbound_url = $add_inbound_url"

# Login to get cookie
login_http_code=$(curl -s -k -c /tmp/xui_cookie.txt -d "username=${panel_user}&password=${panel_pass}" \
  "$login_url" -w "%{http_code}" 2>/dev/null)
echo "Debug: Login HTTP status code: $login_http_code"

# 支持安全令牌登录
# 如果设置了安全令牌，可以用如下方式登录（假设令牌为 $login_secret）
# login_secret="LajRlfEcGEgW4GpRtM1pjhJ2jUfWoRPAT9w"
# login_http_code=$(curl -s -k -c /tmp/xui_cookie.txt -d "username=${panel_user}&password=${panel_pass}&loginSecret=${login_secret}" \
#   "$login_url" -w "%{http_code}" 2>/dev/null)

# Check if cookie file was created and is not empty
if [ ! -s "/tmp/xui_cookie.txt" ]; then
    echo -e "${red}Error: Failed to obtain login cookie. Please check panel username, password, port, and webBasePath.${plain}"
    exit 1
fi

# Add inbound via API
add_inbound_http_code=$(curl -s -k -b /tmp/xui_cookie.txt -X POST "$add_inbound_url" \
  -d "remark=${remark}" \
  -d "enable=true" \
  -d "listen=" \
  -d "port=${trojan_port}" \
  -d "protocol=trojan" \
  -d "settings={\"clients\":[{\"id\":\"${trojan_user}\",\"password\":\"${trojan_pass}\"}],\"fallbacks\":[]}" \
  -d "streamSettings={\"network\":\"tcp\",\"security\":\"tls\",\"tlsSettings\":{\"serverName\":\"${domain}\",\"certificates\":[{\"certificateFile\":\"${cert_file}\",\"keyFile\":\"${key_file}\"}]}}" \
  -d "sniffing={}" \
  -d "allocate={}" \
  -w "%{http_code}" >/tmp/xui_add_inbound_result 2>/dev/null)
echo "Debug: Add Inbound HTTP status code: $add_inbound_http_code"

# Check if API response file was created and is not empty
if [ ! -s "/tmp/xui_add_inbound_result" ]; then
    echo -e "${red}Error: Empty API response. Please check API URL and panel status.${plain}"
    exit 1
fi

echo "Debug: API response content:"
cat /tmp/xui_add_inbound_result
echo "Debug: End of API response content"

# Check API call result based on HTTP status code
if [ "$add_inbound_http_code" -eq 200 ]; then
    echo -e "${green}Trojan inbound added successfully.${plain}"
    echo -e "${green}Trojan Client URL:${plain}"
    echo -e "${blue}trojan://${trojan_user}@${domain}:${trojan_port}?type=tcp&security=tls&fp=chrome&alpn=h3%2Ch2%2Chttp%2F1.1#${remark}${plain}"
else
    echo -e "${red}Failed to add Trojan inbound. HTTP status code: $add_inbound_http_code${plain}"
    echo -e "${red}API response:${plain}"
    cat /tmp/xui_add_inbound_result
fi

# Clean up cookie and result files
rm -f /tmp/xui_cookie.txt
rm -f /tmp/xui_add_inbound_result
