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

# 生成参数 domain实际需要根据当前主机的域名
domain=${1:-"doyousee.icu"}
trojan_port=$(shuf -i 10000-60000 -n 1)
trojan_user=$(gen_random_string 12)
trojan_pass=$(gen_random_string 16)
# 生成 remark，格式：Trojan_年月日时分秒+4位随机数字
remark="Tr_$(date +%y%m%d%H%M%S)$(gen_random_string 2)"

# 默认值（与后端一致）
listen=""
protocol="trojan"
alpn_default="h3%2Ch2%2Chttp%2F1.1"
network_default="tcp"
security_default="tls"
fp_default="chrome"

trojan_alpn="${alpn_default}"
trojan_network="${network_default}"
trojan_security="${security_default}"
trojan_fp="${fp_default}"

# 允许外部传递 cerfile 和 keyfile
cerfile="${2:-/root/.acme.sh/doyousee.icu_ecc/doyousee.icu.cer}"
keyfile="${3:-/root/.acme.sh/doyousee.icu_ecc/doyousee.icu.key}"

trojan_url="trojan://${trojan_pass}@${domain}:${trojan_port}?type=${trojan_network}&security=${trojan_security}&fp=${trojan_fp}&cerfile=${cerfile}&keyfile=${keyfile}&alpn=${trojan_alpn}#${remark}"

 
echo -e "${yellow}正在添加 Trojan 入站...${plain}"
add_output=$(/usr/local/x-ui/x-ui setting -AddInbound "$trojan_url" 2>&1)
add_status=$?
if [[ $add_status -eq 0 ]]; then
    echo "$add_output"
    echo -e "${green}Trojan 入站已添加，信息如下：${plain}"
    echo "---------------------------------------------"
    echo "Remark: $remark"
    echo "Protocol: $protocol"
    echo "Port: $trojan_port"
    echo "Username: $trojan_user"
    echo "Password: $trojan_pass"
    echo "TLS: enabled"
    echo "ALPN: h3,h2,http/1.1"
    echo "---------------------------------------------"
    echo "Trojan 客户端导入链接如下："
    # 移除 cerfile 和 keyfile 参数，仅保留必要参数
    trojan_url_client="trojan://${trojan_pass}@${domain}:${trojan_port}?type=${trojan_network}&security=${trojan_security}&fp=${trojan_fp}&alpn=${trojan_alpn}#${remark}"
    echo "${green}$trojan_url_client"
  
else
    echo -e "${red}Trojan 入站添加失败，返回信息如下：${plain}"
    echo "$add_output"
fi

