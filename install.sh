#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Fatal error: ${plain} Please run this script with root privilege \n " && exit 1

# Check OS and set release variable。。。
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "Failed to check the system OS, please contact the author!" >&2
    exit 1
fi
echo "The OS release is: $release"

arch() {
    case "$(uname -m)" in
    x86_64 | x64 | amd64) echo 'amd64' ;;
    i*86 | x86) echo '386' ;;
    armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
    armv7* | armv7 | arm) echo 'armv7' ;;
    armv6* | armv6) echo 'armv6' ;;
    armv5* | armv5) echo 'armv5' ;;
    s390x) echo 's390x' ;;
    *) echo -e "${green}Unsupported CPU architecture! ${plain}" && rm -f install.sh && exit 1 ;;
    esac
}

echo "arch: $(arch)"

os_version=""
os_version=$(grep "^VERSION_ID" /etc/os-release | cut -d '=' -f2 | tr -d '"' | tr -d '.')

if [[ "${release}" == "arch" ]]; then
    echo "Your OS is Arch Linux"
elif [[ "${release}" == "parch" ]]; then
    echo "Your OS is Parch Linux"
elif [[ "${release}" == "manjaro" ]]; then
    echo "Your OS is Manjaro"
elif [[ "${release}" == "armbian" ]]; then
    echo "Your OS is Armbian"
elif [[ "${release}" == "alpine" ]]; then
    echo "Your OS is Alpine Linux"
elif [[ "${release}" == "opensuse-tumbleweed" ]]; then
    echo "Your OS is OpenSUSE Tumbleweed"
elif [[ "${release}" == "openEuler" ]]; then
    if [[ ${os_version} -lt 2203 ]]; then
        echo -e "${red} Please use OpenEuler 22.03 or higher ${plain}\n" && exit 1
    fi
elif [[ "${release}" == "centos" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red} Please use CentOS 8 or higher ${plain}\n" && exit 1
    fi
elif [[ "${release}" == "ubuntu" ]]; then
    if [[ ${os_version} -lt 2004 ]]; then
        echo -e "${red} Please use Ubuntu 20 or higher version!${plain}\n" && exit 1
    fi
elif [[ "${release}" == "fedora" ]]; then
    if [[ ${os_version} -lt 36 ]]; then
        echo -e "${red} Please use Fedora 36 or higher version!${plain}\n" && exit 1
    fi
elif [[ "${release}" == "amzn" ]]; then
    if [[ ${os_version} != "2023" ]]; then
        echo -e "${red} Please use Amazon Linux 2023!${plain}\n" && exit 1
    fi
elif [[ "${release}" == "debian" ]]; then
    if [[ ${os_version} -lt 11 ]]; then
        echo -e "${red} Please use Debian 11 or higher ${plain}\n" && exit 1
    fi
elif [[ "${release}" == "almalinux" ]]; then
    if [[ ${os_version} -lt 80 ]]; then
        echo -e "${red} Please use AlmaLinux 8.0 or higher ${plain}\n" && exit 1
    fi
elif [[ "${release}" == "rocky" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red} Please use Rocky Linux 8 or higher ${plain}\n" && exit 1
    fi
elif [[ "${release}" == "ol" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red} Please use Oracle Linux 8 or higher ${plain}\n" && exit 1
    fi
else
    echo -e "${red}Your operating system is not supported by this script.${plain}\n"
    echo "Please ensure you are using one of the following supported operating systems:"
    echo "- Ubuntu 20.04+"
    echo "- Debian 11+"
    echo "- CentOS 8+"
    echo "- OpenEuler 22.03+"
    echo "- Fedora 36+"
    echo "- Arch Linux"
    echo "- Parch Linux"
    echo "- Manjaro"
    echo "- Armbian"
    echo "- AlmaLinux 8.0+"
    echo "- Rocky Linux 8+"
    echo "- Oracle Linux 8+"
    echo "- OpenSUSE Tumbleweed"
    echo "- Amazon Linux 2023"
    exit 1
fi

install_base() {
    case "${release}" in
    centos | almalinux | rocky | ol)
        # 检查主源可用性
        if ! curl -s --connect-timeout 3 http://mirror.centos.org/centos/8/os/x86_64/repodata/repomd.xml >/dev/null; then
            echo -e "${yellow}检测到官方源不可用，尝试切换到清华或阿里云镜像源...${plain}"
            # 优先切换到清华源
            if curl -s --connect-timeout 3 https://mirrors.tuna.tsinghua.edu.cn/centos/8/os/x86_64/repodata/repomd.xml >/dev/null; then
                sed -e 's|^mirrorlist=|#mirrorlist=|g' \
                    -e 's|^#baseurl=http://mirror.centos.org|baseurl=https://mirrors.tuna.tsinghua.edu.cn|g' \
                    -i.bak \
                    /etc/yum.repos.d/CentOS-*.repo
                echo -e "${green}已切换到清华镜像源${plain}"
            else
                # 切换到阿里云
                sed -e 's|^mirrorlist=|#mirrorlist=|g' \
                    -e 's|^#baseurl=http://mirror.centos.org|baseurl=https://mirrors.aliyun.com|g' \
                    -i.bak \
                    /etc/yum.repos.d/CentOS-*.repo
                echo -e "${green}已切换到阿里云镜像源${plain}"
            fi
            dnf clean all
            dnf makecache
        fi
        # 检查wget/curl/tar是否已安装，否则单独尝试安装
        for pkg in wget curl tar; do
            if ! command -v $pkg >/dev/null 2>&1; then
                yum install -y $pkg
            fi
        done
        yum -y update && yum install -y -q wget curl tar tzdata
        ;;
    fedora | amzn)
        dnf -y update && dnf install -y -q wget curl tar tzdata
        ;;
    ubuntu | debian | armbian)
        apt-get update && apt-get install -y -q wget curl tar tzdata
        ;;
    arch | manjaro | parch)
        pacman -Syu && pacman -Syu --noconfirm wget curl tar tzdata
        ;;
    opensuse-tumbleweed)
        zypper refresh && zypper -q install -y wget curl tar timezone
        ;;
    *)
        apt-get update && apt install -y -q wget curl tar tzdata
        ;;
    esac
}

gen_random_string() {
    local length="$1"
    local random_string=$(LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w "$length" | head -n 1)
    echo "$random_string"
}

config_after_install() {
    local existing_username=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'username: .+' | awk '{print $2}')
    local existing_password=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'password: .+' | awk '{print $2}')
    local existing_webBasePath=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'webBasePath: .+' | awk '{print $2}')
    local existing_port=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'port: .+' | awk '{print $2}')
    local server_ip=$(curl -s https://api.ipify.org)

    if [[ ${#existing_webBasePath} -lt 4 ]]; then
        if [[ "$existing_username" == "admin" && "$existing_password" == "admin" ]]; then
            local config_webBasePath=$(gen_random_string 15)
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)

            read -p "Would you like to customize the Panel Port settings? (If not, a random port will be applied) [y/n]: " config_confirm
            if [[ "${config_confirm}" == "y" || "${config_confirm}" == "Y" ]]; then
                read -p "Please set up the panel port: " config_port
                echo -e "${yellow}Your Panel Port is: ${config_port}${plain}"
            else
                local config_port=$(shuf -i 1024-62000 -n 1)
                echo -e "${yellow}Generated random port: ${config_port}${plain}"
            fi

            /usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}" -port "${config_port}" -webBasePath "${config_webBasePath}"
            echo -e "This is a fresh installation, generating random login info for security concerns:"
            echo -e "###############################################"
            echo -e "${green}Username: ${config_username}${plain}"
            echo -e "${green}Password: ${config_password}${plain}"
            echo -e "${green}Port: ${config_port}${plain}"
            echo -e "${green}WebBasePath: ${config_webBasePath}${plain}"
            echo -e "${green}Access URL: http://${server_ip}:${config_port}/${config_webBasePath}${plain}"
            echo -e "###############################################"
            echo -e "${yellow}If you forgot your login info, you can type 'x-ui settings' to check${plain}"
        else
            local config_webBasePath=$(gen_random_string 15)
            echo -e "${yellow}WebBasePath is missing or too short. Generating a new one...${plain}"
            /usr/local/x-ui/x-ui setting -webBasePath "${config_webBasePath}"
            echo -e "${green}New WebBasePath: ${config_webBasePath}${plain}"
            echo -e "${green}Access URL: http://${server_ip}:${existing_port}/${config_webBasePath}${plain}"
        fi
    else
        if [[ "$existing_username" == "admin" && "$existing_password" == "admin" ]]; then
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)

            echo -e "${yellow}Default credentials detected. Security update required...${plain}"
            /usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}"
            echo -e "Generated new random login credentials:"
            echo -e "###############################################"
            echo -e "${green}Username: ${config_username}${plain}"
            echo -e "${green}Password: ${config_password}${plain}"
            echo -e "###############################################"
            echo -e "${yellow}If you forgot your login info, you can type 'x-ui settings' to check${plain}"
        else
            echo -e "${green}Username, Password, and WebBasePath are properly set. Exiting...${plain}"
        fi
    fi

    /usr/local/x-ui/x-ui migrate
}

install_x-ui() {
    cd /usr/local/

    if [ $# == 0 ]; then
        tag_version=$(curl -Ls "https://api.github.com/repos/dmulxw/3x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$tag_version" ]]; then
            echo -e "${red}Failed to fetch x-ui version, it may be due to GitHub API restrictions, please try it later${plain}"
            exit 1
        fi
        echo -e "Got x-ui latest version: ${tag_version}, beginning the installation..."
        # 优先用wget，若无wget则尝试curl
        if command -v wget >/dev/null 2>&1; then
            wget -N --no-check-certificate -O /usr/local/x-ui-linux-$(arch).tar.gz https://github.com/dmulxw/3x-ui/releases/download/${tag_version}/x-ui-linux-$(arch).tar.gz
        elif command -v curl >/dev/null 2>&1; then
            curl -Lso /usr/local/x-ui-linux-$(arch).tar.gz https://github.com/dmulxw/3x-ui/releases/download/${tag_version}/x-ui-linux-$(arch).tar.gz
        else
            echo -e "${red}Neither wget nor curl is available, please install one of them first.${plain}"
            echo -e "${yellow}你可以手动下载以下链接并上传到 /usr/local/ 目录：${plain}"
            echo "https://github.com/dmulxw/3x-ui/releases/download/${tag_version}/x-ui-linux-$(arch).tar.gz"
            exit 1
        fi
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Downloading x-ui failed, please be sure that your server can access GitHub ${plain}"
            echo -e "${yellow}你可以手动下载以下链接并上传到 /usr/local/ 目录：${plain}"
            echo "https://github.com/dmulxw/3x-ui/releases/download/${tag_version}/x-ui-linux-$(arch).tar.gz"
            exit 1
        fi
    else
        tag_version=$1
        tag_version_numeric=${tag_version#v}
        min_version="2.3.5"

        if [[ "$(printf '%s\n' "$min_version" "$tag_version_numeric" | sort -V | head -n1)" != "$min_version" ]]; then
            echo -e "${red}Please use a newer version (at least v2.3.5). Exiting installation.${plain}"
            exit 1
        fi

        url="https://github.com/dmulxw/3x-ui/releases/download/${tag_version}/x-ui-linux-$(arch).tar.gz"
        echo -e "Beginning to install x-ui $1"
        if command -v wget >/dev/null 2>&1; then
            wget -N --no-check-certificate -O /usr/local/x-ui-linux-$(arch).tar.gz ${url}
        elif command -v curl >/dev/null 2>&1; then
            curl -Lso /usr/local/x-ui-linux-$(arch).tar.gz ${url}
        else
            echo -e "${red}Neither wget nor curl is available, please install one of them first.${plain}"
            echo -e "${yellow}你可以手动下载以下链接并上传到 /usr/local/ 目录：${plain}"
            echo "${url}"
            exit 1
        fi
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Download x-ui $1 failed, please check if the version exists ${plain}"
            echo -e "${yellow}你可以手动下载以下链接并上传到 /usr/local/ 目录：${plain}"
            echo "${url}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        systemctl stop x-ui
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-$(arch).tar.gz
    rm x-ui-linux-$(arch).tar.gz -f
    cd x-ui
    chmod +x x-ui

    # Check the system's architecture and rename the file accordingly
    if [[ $(arch) == "armv5" || $(arch) == "armv6" || $(arch) == "armv7" ]]; then
        mv bin/xray-linux-$(arch) bin/xray-linux-arm
        chmod +x bin/xray-linux-arm
    fi

    chmod +x x-ui bin/xray-linux-$(arch)
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/dmulxw/3x-ui/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install

    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui ${tag_version}${plain} installation finished, it is running now..."
    echo -e ""
    echo -e "┌───────────────────────────────────────────────────────┐
│  ${blue}x-ui control menu usages (subcommands):${plain}              │
│                                                       │
│  ${blue}x-ui${plain}              - Admin Management Script          │
│  ${blue}x-ui start${plain}        - Start                            │
│  ${blue}x-ui stop${plain}         - Stop                             │
│  ${blue}x-ui restart${plain}      - Restart                          │
│  ${blue}x-ui status${plain}       - Current Status                   │
│  ${blue}x-ui settings${plain}     - Current Settings                 │
│  ${blue}x-ui enable${plain}       - Enable Autostart on OS Startup   │
│  ${blue}x-ui disable${plain}      - Disable Autostart on OS Startup  │
│  ${blue}x-ui log${plain}          - Check logs                       │
│  ${blue}x-ui banlog${plain}       - Check Fail2ban ban logs          │
│  ${blue}x-ui update${plain}       - Update                           │
│  ${blue}x-ui legacy${plain}       - legacy version                   │
│  ${blue}x-ui install${plain}      - Install                          │
│  ${blue}x-ui uninstall${plain}    - Uninstall                        │
└───────────────────────────────────────────────────────┘"
}

check_firewall_ports() {
    local need_open=0
    local close_cmds=""
    # 检查ufw是否安装并启用
    if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
        for port in 80 443; do
            if ! ufw status | grep -qw "$port"; then
                ufw allow $port
                need_open=1
                close_cmds+="ufw delete allow $port\n"
            fi
        done
        if [[ $need_open -eq 1 ]]; then
            echo -e "${green}防火墙已自动开放80端口和443端口，如需关闭请执行：\n${close_cmds}${plain}"
        fi
    fi
    # firewalld
    if command -v firewall-cmd &>/dev/null && firewall-cmd --state &>/dev/null; then
        for port in 80 443; do
            if ! firewall-cmd --list-ports | grep -qw "${port}/tcp"; then
                firewall-cmd --permanent --add-port=${port}/tcp
                firewall-cmd --reload
                need_open=1
                close_cmds+="firewall-cmd --permanent --remove-port=${port}/tcp && firewall-cmd --reload\n"
            fi
        done
        if [[ $need_open -eq 1 ]]; then
            echo -e "${green}防火墙已自动开放80端口和443端口，如需关闭请执行：\n${close_cmds}${plain}"
        fi
    fi
}

check_port_occupied() {
    for port in 80 443; do
        local pinfo
        pinfo=$(lsof -i :$port -sTCP:LISTEN 2>/dev/null | grep -v "COMMAND")
        if [[ -n "$pinfo" ]]; then
            echo -e "${red}端口${port}已被占用，相关进程如下：${plain}"
            echo "$pinfo"
            exit 1
        fi
    done
}

install_acme() {
    # 检查 tar 是否存在，否则尝试自动安装
    if ! command -v tar >/dev/null 2>&1; then
        echo -e "${yellow}未检测到 tar，正在尝试自动安装...${plain}"
        if command -v yum >/dev/null 2>&1; then
            yum install -y tar
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y tar
        elif command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y tar
        elif command -v pacman >/dev/null 2>&1; then
            pacman -Sy --noconfirm tar
        elif command -v zypper >/dev/null 2>&1; then
            zypper install -y tar
        fi
    fi
    if ! command -v tar >/dev/null 2>&1; then
        echo -e "${red}acme.sh 安装失败，系统缺少 tar 工具。${plain}"
        echo -e "${yellow}请手动安装 tar 后再运行本脚本，或参考 acme.sh 官方文档：${plain}"
        echo "https://github.com/acmesh-official/acme.sh/wiki/Install-in-China"
        # 不终止安装，继续往下执行
    fi
    if command -v ~/.acme.sh/acme.sh &>/dev/null; then
        echo -e "${green}acme.sh 已安装${plain}"
        return 0
    fi
    echo -e "${yellow}正在安装 acme.sh...${plain}"
    cd ~ || return 1
    # 优先尝试 acme.sh 官方脚本
    curl -s https://get.acme.sh | sh
    if [ $? -ne 0 ] || [ ! -f ~/.acme.sh/acme.sh ]; then
        echo -e "${red}acme.sh 官方脚本安装失败，尝试使用国内镜像源...${plain}"
        # 尝试使用腾讯云镜像
        curl -s https://cdn.jsdelivr.net/gh/acmesh-official/acme.sh@master/acme.sh > acme.sh && chmod +x acme.sh
        if [ -f acme.sh ]; then
            mkdir -p ~/.acme.sh
            mv acme.sh ~/.acme.sh/
            ln -sf ~/.acme.sh/acme.sh /usr/local/bin/acme.sh
            echo -e "${green}已通过镜像源下载 acme.sh，请手动初始化：~/.acme.sh/acme.sh --install${plain}"
        else
            echo -e "${red}acme.sh 镜像源下载也失败，请参考：https://github.com/acmesh-official/acme.sh/wiki/Install-in-China${plain}"
        fi
        # 不终止安装，继续往下执行
    fi
    return 0
}

generate_default_site() {
    local domain="$1"
    local site_dir="/var/www/default_site"
    mkdir -p "$site_dir"
    local webzip_url="https://github.com/dmulxw/3x-ui/releases/download/trojan/web.zip"
    if curl --head --silent --fail "$webzip_url" >/dev/null; then
        tmpzip="/tmp/web.zip"
        curl -Lso "$tmpzip" "$webzip_url"
        if command -v unzip &>/dev/null; then
            unzip -o "$tmpzip" -d "$site_dir"
        else
            apt-get update && apt-get install -y unzip || yum install -y unzip
            unzip -o "$tmpzip" -d "$site_dir"
        fi
        rm -f "$tmpzip"
    else
        cat >"$site_dir/index.html" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to $domain</title>
    <meta charset="utf-8">
</head>
<body>
    <h1>Welcome to $domain</h1>
    <p>This is a default site for camouflage.</p>
</body>
</html>
EOF
    fi
}

install_nginx_with_cert() {
    local domain="$1"
    local cert="$2"
    local key="$3"
    # 安装 nginx
    if ! command -v nginx &>/dev/null; then
        case "${release}" in
        ubuntu | debian | armbian)
            apt update && apt install -y nginx
            ;;
        centos | almalinux | rocky | ol)
            yum install -y nginx
            ;;
        fedora | amzn)
            dnf install -y nginx
            ;;
        arch | manjaro | parch)
            pacman -Sy --noconfirm nginx
            ;;
        *)
            echo -e "${red}不支持的系统，请手动安装 nginx${plain}"
            return 1
            ;;
        esac
    fi
    generate_default_site "$domain"
    cat >/etc/nginx/conf.d/default_site.conf <<EOF
server {
    listen 80;
    server_name $domain;
    location / {
        root /var/www/default_site;
        index index.html;
    }
}
server {
    listen 443 ssl;
    server_name $domain;
    ssl_certificate     $cert;
    ssl_certificate_key $key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    location / {
        root /var/www/default_site;
        index index.html;
    }
    location /panel/ {
        proxy_pass http://127.0.0.1:54321/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    mkdir -p /var/www/default_site
    systemctl enable nginx
    systemctl restart nginx
}

auto_ssl_and_nginx() {
    # 检查防火墙
    check_firewall_ports
    # 检查端口占用
    check_port_occupied
    # 申请证书
    local retry=0
    local domain=""
    local email=""
    while true; do
        echo -e "${yellow}请输入用于申请证书的域名（如 example.com）：${plain}"
        read -r domain < /dev/tty
        # 域名校验：包含至少一个点且不是首尾，且后缀长度>=2
        if [[ "$domain" =~ ^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$ ]]; then
            break
        else
            echo -e "${red}域名格式不正确，请重新输入。${plain}"
            retry=$((retry+1))
            if [[ $retry -ge 2 ]]; then
                echo "输入错误次数过多，安装中止。"
                exit 1
            fi
        fi
    done
    retry=0
    while true; do
        echo -e "${yellow}请输入联系邮箱（Let's Encrypt 用于通知证书到期）：${plain}"
        read -r email < /dev/tty
        # 邮箱校验：包含@和.，且后缀长度>=2
        if [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            break
        else
            echo -e "${red}邮箱格式不正确，请重新输入。${plain}"
            retry=$((retry+1))
            if [[ $retry -ge 2 ]]; then
                echo "输入错误次数过多，安装中止。"
                exit 1
            fi
        fi
    done
    install_acme
    if [ $? -ne 0 ]; then
        echo -e "${red}acme.sh 安装失败${plain}"
        exit 1
    fi
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    ~/.acme.sh/acme.sh --register-account -m "$email"
    ~/.acme.sh/acme.sh --issue -d "$domain" --standalone --force
    if [ $? -ne 0 ]; then
        echo -e "${red}证书申请失败，请检查域名解析和端口占用${plain}"
        exit 1
    fi
    cert_dir="/root/cert/${domain}"
    mkdir -p "$cert_dir"
    ~/.acme.sh/acme.sh --installcert -d "$domain" \
        --key-file "$cert_dir/privkey.pem" \
        --fullchain-file "$cert_dir/fullchain.pem"
    # 自动写入证书路径到x-ui配置
    /usr/local/x-ui/x-ui cert -webCert "$cert_dir/fullchain.pem" -webCertKey "$cert_dir/privkey.pem"
    /usr/local/x-ui/x-ui setting -subCertFile "$cert_dir/fullchain.pem" -subKeyFile "$cert_dir/privkey.pem"
    # 自动续期
    if ! crontab -l 2>/dev/null | grep -q 'acme.sh --cron'; then
        (crontab -l 2>/dev/null; echo "0 3 1 */2 * ~/.acme.sh/acme.sh --cron --home ~/.acme.sh > /dev/null") | crontab -
        echo -e "${green}已设置acme.sh自动续期定时任务（每2个月1号凌晨3点自动续期）${plain}"
    fi
    # 安装并配置nginx
    install_nginx_with_cert "$domain" "$cert_dir/fullchain.pem" "$cert_dir/privkey.pem"
    # 显示客户端下载地址
    echo -e "${green}客户端下载地址：${plain}"
    echo "https://github.com/dmulxw/3x-ui/releases/download/trojan/Trojan-Qt5-MacOS.dmg"
    echo "https://github.com/dmulxw/3x-ui/releases/download/trojan/Trojan-Qt5-Linux.AppImage"
    echo "https://github.com/dmulxw/3x-ui/releases/download/trojan/Trojan-Qt5-Windows.7z"
    echo "https://github.com/dmulxw/3x-ui/releases/download/trojan/Igniter-trajon-app-Android-release.apk"
}

echo -e "${green}Running...${plain}"
install_base
install_x-ui $1

# 自动化SSL证书、nginx、默认站点、证书路径写入
auto_ssl_and_nginx
