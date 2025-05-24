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

# 获取证书路径
nginx_config_file="/etc/nginx/conf.d/default_site.conf"
cert_file=$(sed -n 's/^\s*ssl_certificate\s*\(.*\);/\1/p' "$nginx_config_file" | head -n1)
key_file=$(sed -n 's/^\s*ssl_certificate_key\s*\(.*\);/\1/p' "$nginx_config_file" | head -n1)

# 生成参数
domain=${1:-"127.0.0.1"}
trojan_port=$(shuf -i 10000-60000 -n 1)
trojan_user=$(gen_random_string 12)
trojan_pass=$(gen_random_string 16)
remark="Trojan_$(date +%y%m%d)$(gen_random_string 5)"

trojan_alpn="h3%2Ch2%2Chttp%2F1.1"
trojan_url="trojan://${trojan_pass}@${domain}:${trojan_port}?type=tcp&security=tls&fp=chrome&alpn=${trojan_alpn}#${remark}"

echo -e "${yellow}即将添加的 Trojan 入站链接如下：${plain}"
echo "$trojan_url"
echo -e "${yellow}正在添加 Trojan 入站...${plain}"
add_output=$(/usr/local/x-ui/x-ui setting -AddInbound "$trojan_url" 2>&1)
add_status=$?
if [[ $add_status -eq 0 ]]; then
    echo "$add_output"
    echo -e "${green}Trojan 入站已添加，信息如下：${plain}"
    echo "---------------------------------------------"
    echo "Remark: $remark"
    echo "Protocol: trojan"
    echo "Port: $trojan_port"
    echo "Username: $trojan_user"
    echo "Password: $trojan_pass"
    echo "TLS: enabled"
    echo "Certificate: $cert_file"
    echo "Key: $key_file"
    echo "ALPN: h3,h2,http/1.1"
    echo "---------------------------------------------"
    echo -e "${green}Trojan 客户端导入链接如下：${plain}"
    echo "$trojan_url"
else
    echo -e "${red}Trojan 入站添加失败，返回信息如下：${plain}"
    echo "$add_output"
fi

# 只生成 Trojan inbound JSON 字符串并输出
generate_trojan_inbound_json() {
    local trojan_port=$(shuf -i 10000-60000 -n 1)
    local trojan_user=$(gen_random_string 12)
    local trojan_pass=$(gen_random_string 16)
    local remark="Trojan_$(date +%y%m%d)$(gen_random_string 5)"
    local cert_file="/path/to/your/cert.crt"
    local key_file="/path/to/your/cert.key"
    local settings_json=$(printf '{"clients":[{"password":"%s","email":"%s","enable":true}]}' "$trojan_pass" "$trojan_user")
    local streamsettings_json=$(printf '{"network":"tcp","security":"tls","tlsSettings":{"alpn":["h3","h2","http/1.1"],"fingerprint":"chrome","certificates":[{"certificateFile":"%s","keyFile":"%s"}]}}' "$cert_file" "$key_file")
    cat <<EOF
{
  "Listen": "",
  "Port": $trojan_port,
  "Protocol": "trojan",
  "Settings": "$settings_json",
  "StreamSettings": "$streamsettings_json",
  "Tag": "$remark",
  "Enable": true,
  "Remark": "$remark"
}
EOF
}

# 调用示例
generate_trojan_inbound_json
