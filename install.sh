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
            echo -e "${yellow}The official CentOS mirror is unavailable, trying to switch to Tsinghua or Aliyun mirror...${plain}"
            echo -e "${yellow}检测到官方源不可用，尝试切换到清华或阿里云镜像源...${plain}"
            # 优先切换到清华源
            if curl -s --connect-timeout 3 https://mirrors.tuna.tsinghua.edu.cn/centos/8/os/x86_64/repodata/repomd.xml >/dev/null; then
                sed -e 's|^mirrorlist=|#mirrorlist=|g' \
                    -e 's|^#baseurl=http://mirror.centos.org|baseurl=https://mirrors.tuna.tsinghua.edu.cn|g' \
                    -i.bak \
                    /etc/yum.repos.d/CentOS-*.repo
                echo -e "${green}Switched to Tsinghua mirror.${plain}"
                echo -e "${green}已切换到清华镜像源${plain}"
            else
                # 切换到阿里云
                sed -e 's|^mirrorlist=|#mirrorlist=|g' \
                    -e 's|^#baseurl=http://mirror.centos.org|baseurl=https://mirrors.aliyun.com|g' \
                    -i.bak \
                    /etc/yum.repos.d/CentOS-*.repo
                echo -e "${green}Switched to Aliyun mirror.${plain}"
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
        yum -y update && yum install -y -q wget curl tar tzdata socat
        ;;
    fedora | amzn)
        dnf -y update && dnf install -y -q wget curl tar tzdata socat
        ;;
    ubuntu | debian | armbian)
        apt-get update && apt-get install -y -q wget curl tar tzdata socat
        ;;
    arch | manjaro | parch)
        pacman -Syu && pacman -Syu --noconfirm wget curl tar tzdata socat
        ;;
    opensuse-tumbleweed)
        zypper refresh && zypper -q install -y wget curl tar timezone socat
        ;;
    *)
        apt-get update && apt install -y -q wget curl tar tzdata socat
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
    # 修正端口号为0或空的情况
    if [[ -z "$existing_port" || "$existing_port" == "0" ]]; then
        # 尝试从配置文件读取端口
        if [[ -f /usr/local/x-ui/data/config.json ]]; then
            existing_port=$(grep -o '"port":[ ]*[0-9]\+' /usr/local/x-ui/data/config.json | head -n1 | grep -o '[0-9]\+')
        fi
        # 如果还是没有，给一个默认端口
        if [[ -z "$existing_port" || "$existing_port" == "0" ]]; then
            existing_port="54321"
        fi
    fi

    # 检查是否有用户输入的域名
    local panel_domain=""
    if [[ -f /tmp/xui_panel_domain ]]; then
        panel_domain=$(cat /tmp/xui_panel_domain)
    fi

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
            # 更新端口变量
            existing_port="${config_port}"
            # 保存信息到临时文件
            {
                echo "###############################################"
                echo -e "${green}Username: ${config_username}${plain}"
                echo -e "${green}Password: ${config_password}${plain}"
                echo -e "${green}Port: ${config_port}${plain}"
                echo -e "${green}WebBasePath: ${config_webBasePath}${plain}"
                if [[ -n "$panel_domain" ]]; then
                    echo -e "${green}Access URL: http://${panel_domain}:${config_port}/${config_webBasePath}${plain}"
                else
                    echo -e "${green}Access URL: http://${server_ip}:${config_port}/${config_webBasePath}${plain}"
                fi
                echo "###############################################"
            } > /tmp/xui_install_info
            # 更新端口变量
            existing_port="${config_port}"
            echo -e "This is a fresh installation, generating random login info for security concerns:"
            echo -e "###############################################"
            echo -e "${green}Username: ${config_username}${plain}"
            echo -e "${green}Password: ${config_password}${plain}"
            echo -e "${green}Port: ${config_port}${plain}"
            echo -e "${green}WebBasePath: ${config_webBasePath}${plain}"
            if [[ -n "$panel_domain" ]]; then
                echo -e "${green}Access URL: http://${panel_domain}:${config_port}/${config_webBasePath}${plain}"
            else
                echo -e "${green}Access URL: http://${server_ip}:${config_port}/${config_webBasePath}${plain}"
            fi
            echo -e "###############################################"
            echo -e "${yellow}If you forgot your login info, you can type 'x-ui settings' to check${plain}"
        else
            local config_webBasePath=$(gen_random_string 15)
            echo -e "${yellow}WebBasePath is missing or too short. Generating a new one...${plain}"
            /usr/local/x-ui/x-ui setting -webBasePath "${config_webBasePath}"
            echo -e "${green}New WebBasePath: ${config_webBasePath}${plain}"
            # 保存信息到临时文件
            {
                echo "###############################################"
                echo -e "${green}WebBasePath: ${config_webBasePath}${plain}"
                if [[ -n "$panel_domain" ]]; then
                    echo -e "${green}Access URL: http://${panel_domain}:${existing_port}/${config_webBasePath}${plain}"
                else
                    echo -e "${green}Access URL: http://${server_ip}:${existing_port}/${config_webBasePath}${plain}"
                fi
                echo "###############################################"
            } > /tmp/xui_install_info
        fi
    else
        if [[ "$existing_username" == "admin" && "$existing_password" == "admin" ]]; then
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)

            echo -e "${yellow}Default credentials detected. Security update required...${plain}"
            /usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}"
            # 保存信息到临时文件
            {
                echo "###############################################"
                echo -e "${green}Username: ${config_username}${plain}"
                echo -e "${green}Password: ${config_password}${plain}"
                echo "###############################################"
            } > /tmp/xui_install_info
            echo -e "${yellow}If you forgot your login info, you can type 'x-ui settings' to check${plain}"
        else
            echo -e "${green}Username, Password, and WebBasePath are properly set. Exiting...${plain}"
            # 保存信息到临时文件
            {
                echo "###############################################"
                echo -e "${green}Username, Password, and WebBasePath are properly set.${plain}"
                echo "###############################################"
            } > /tmp/xui_install_info
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
            echo -e "${green}The firewall has automatically opened port 80 and port 443. If you need to close them, please execute:,防火墙已自动开放80端口和443端口，如需关闭请执行：\n${close_cmds}${plain}"
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
            echo -e "${green}The firewall has automatically opened port 80 and port 443. If you need to close them, please execute:.防火墙已自动开放80端口和443端口，如需关闭请执行：\n${close_cmds}${plain}"
        fi
    fi
}

check_port_occupied() {
    for port in 80 443; do
        local pinfo
        pinfo=$(lsof -i :$port -sTCP:LISTEN 2>/dev/null | grep -v "COMMAND")
        if [[ -n "$pinfo" ]]; then
            echo -e "${red} 端口${port}已被占用，相关进程如下：${plain}"
            echo "$pinfo"
            exit 1
        fi
    done
}

install_acme() {
    # 检查 tar 是否存在，否则提示
    if ! command -v tar >/dev/null 2>&1; then
        echo -e "${red}tar not detected, acme.sh and certificate features will not work.${plain}"
        echo -e "${red}未检测到 tar，acme.sh 及证书功能将无法使用。${plain}"
        echo -e "${yellow}Please install tar manually and rerun this script, or refer to the acme.sh official documentation:${plain}"
        echo -e "${yellow}请手动安装 tar 后再运行本脚本，或参考 acme.sh 官方文档：${plain}"
        echo "https://github.com/acmesh-official/acme.sh/wiki/Install-in-China"
        # 不终止，继续尝试后续步骤
    fi
    # 检查 socat 是否存在，否则尝试用 busybox socat 或提示
    if ! command -v socat >/dev/null 2>&1; then
        if command -v busybox >/dev/null 2>&1 && busybox | grep -q socat; then
            alias socat='busybox socat'
            echo -e "${yellow}System socat not detected, trying to use busybox socat as a replacement.${plain}"
            echo -e "${yellow}未检测到系统 socat，尝试使用 busybox socat 兼容。${plain}"
        else
            echo -e "${red}socat not detected, acme.sh certificate issuance will not work in standalone mode.${plain}"
            echo -e "${red}未检测到 socat，acme.sh 证书申请将无法使用 standalone 模式。${plain}"
            echo -e "${yellow}Please install socat manually, otherwise certificate issuance will fail.${plain}"
            echo -e "${yellow}请手动安装 socat，否则证书签发会失败。${plain}"
            echo -e "${yellow}CentOS/RHEL/AlmaLinux/Rocky:  yum install -y socat"
            echo -e "Debian/Ubuntu:                apt-get install -y socat"
            echo -e "If yum/apt sources are unavailable, you can manually download socat rpm or deb packages for offline installation:"
            echo -e "如 yum/apt 源不可用，可手动下载 socat rpm 或 deb 包离线安装："
            echo -e "CentOS 8 rpm: https://mirrors.aliyun.com/centos/8/AppStream/x86_64/os/Packages/socat-1.7.3.3-2.el8.x86_64.rpm"
            echo -e "Debian 11 deb: https://mirrors.edge.kernel.org/debian/pool/main/s/socat/socat_1.7.4.1-3_amd64.deb"
            echo -e "After downloading, execute (for rpm):"
            echo -e "下载后执行（以 rpm 为例）："
            echo -e "rpm -ivh socat-*.rpm"
            echo -e "Or (for deb):"
            echo -e "或（以 deb 为例）："
            echo -e "dpkg -i socat_*.deb"
            echo -e "More ways to get socat: https://pkgs.org/search/?q=socat"
            echo -e "更多获取方式见：https://pkgs.org/search/?q=socat"
            echo -e "${yellow}If you cannot install socat, you can try DNS mode to apply for a certificate, refer to:${plain}"
            echo -e "${yellow}如无法安装 socat，可尝试 DNS 模式申请证书，参考：https://github.com/acmesh-official/acme.sh/wiki/dnsapi${plain}"
            # 不终止，继续尝试后续步骤
        fi
    fi
    # 检查 acme.sh 是否已安装
    if command -v ~/.acme.sh/acme.sh &>/dev/null; then
        echo -e "${green}acme.sh is already installed.${plain}"
        echo -e "${green}acme.sh 已安装${plain}"
        return 0
    fi
    echo -e "${yellow}Installing acme.sh...${plain}"
    echo -e "${yellow}正在安装 acme.sh...${plain}"
    # 优先尝试 acme.sh 官方脚本
    curl -s https://get.acme.sh | sh
    if [ $? -ne 0 ] || [ ! -f ~/.acme.sh/acme.sh ]; then
        echo -e "${red}acme.sh official script installation failed, trying jsdelivr China mirror...${plain}"
        echo -e "${red}acme.sh 官方脚本安装失败，尝试使用 jsdelivr 国内镜像源...${plain}"
        curl -s https://cdn.jsdelivr.net/gh/acmesh-official/acme.sh@master/acme.sh > acme.sh && chmod +x acme.sh
        if [ ! -f acme.sh ]; then
            echo -e "${red}jsdelivr mirror failed, trying fastgit global mirror...${plain}"
            echo -e "${red}jsdelivr 镜失败，尝试使用 fastgit 全球镜像源...${plain}"
            curl -s https://raw.fastgit.org/acmesh-official/acme.sh/master/acme.sh > acme.sh && chmod +x acme.sh
        fi
        if [ -f acme.sh ]; then
            mkdir -p ~/.acme.sh
            mv acme.sh ~/.acme.sh/
            ln -sf ~/.acme.sh/acme.sh /usr/local/bin/acme.sh
            echo -e "${green}acme.sh downloaded via mirror, please initialize manually: ~/.acme.sh/acme.sh --install${plain}"
            echo -e "${green}已通过镜像源下载 acme.sh，请手动初始化：~/.acme.sh/acme.sh --install${plain}"
        else
            echo -e "${red}All acme.sh mirrors failed, please refer to: https://github.com/acmesh-official/acme.sh/wiki/Install-in-China${plain}"
            echo -e "${red}acme.sh 所有镜像源下载均失败，请参考：https://github.com/acmesh-official/acme.sh/wiki/Install-in-China${plain}"
        fi
        # 不终止，继续尝试后续步骤
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
            echo -e "${red}not support system.不支持的系统，请手动安装 nginx${plain}"
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
        echo -e "${yellow}Please enter the domain name for SSL certificate application (e.g. example.com):${plain}"
        echo -e "${yellow}请输入用于申请证书的域名（如 example.com）：${plain}"
        read -r domain < /dev/tty
        # 域名校验：包含至少一个点且不是首尾，且后缀长度>=2
        if [[ "$domain" =~ ^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$ ]]; then
            # 保存域名用于后续 config_after_install 输出
            echo "$domain" > /tmp/xui_panel_domain
            break
        else
            echo -e "${red}Invalid domain format, please try again.${plain}"
            echo -e "${red}域名格式不正确，请重新输入。${plain}"
            retry=$((retry+1))
            if [[ $retry -ge 2 ]]; then
                echo "Too many input errors, setup aborted."
                echo "输入错误次数过多，安装中止。"
                exit 1
            fi
        fi
    done
    retry=0
    while true; do
        echo -e "${yellow}Please enter your email address (for Let's Encrypt notifications):${plain}"
        echo -e "${yellow}请输入联系邮箱（Let's Encrypt 用于通知证书到期）：${plain}"
        read -r email < /dev/tty
        # 邮箱校验：包含@和.，且后缀长度>=2
        if [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            break
        else
            echo -e "${red}Invalid email format, please try again.${plain}"
            echo -e "${red}邮箱格式不正确，请重新输入。${plain}"
            retry=$((retry+1))
            if [[ $retry -ge 2 ]]; then
                echo "Too many input errors, setup aborted."
                echo "输入错误次数过多，安装中止。"
                exit 1
            fi
        fi
    done
    install_acme
    if [ $? -ne 0 ]; then
        echo -e "${red}acme.sh installation failed.${plain}"
        echo -e "${red}acme.sh 安装失败${plain}"
        exit 1
    fi
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    ~/.acme.sh/acme.sh --register-account -m "$email"
    ~/.acme.sh/acme.sh --issue -d "$domain" --standalone --force
    if [ $? -ne 0 ]; then
        echo -e "${red}Certificate application failed, please check domain resolution and port occupation.${plain}"
        echo -e "${red}证书申请失败，请检查域名解析和端口占用${plain}"
        exit 1
    fi
    cert_dir="/root/cert/${domain}"
    mkdir -p "$cert_dir"
    ~/.acme.sh/acme.sh --installcert -d "$domain" \
        --key-file "$cert_dir/privkey.pem" \
        --fullchain-file "$cert_dir/fullchain.pem"

    # 检查acme.sh ECC证书文件是否存在，优先直接写入x-ui配置
    acme_ecc_dir="$HOME/.acme.sh/${domain}_ecc"
    if [[ -f "$acme_ecc_dir/${domain}.cer" && -f "$acme_ecc_dir/${domain}.key" ]]; then
        /usr/local/x-ui/x-ui cert -webCert "$acme_ecc_dir/${domain}.cer" -webCertKey "$acme_ecc_dir/${domain}.key"
        /usr/local/x-ui/x-ui setting -subCertFile "$acme_ecc_dir/${domain}.cer" -subKeyFile "$acme_ecc_dir/${domain}.key"
        cert_file="$acme_ecc_dir/${domain}.cer"
        key_file="$acme_ecc_dir/${domain}.key"
        echo -e "${green}acme.sh ECC certificate used for x-ui.${plain}"
        echo -e "${green}已直接使用acme.sh ECC证书文件配置x-ui${plain}"
        systemctl restart x-ui
    else
        acme_rsa_dir="$HOME/.acme.sh/${domain}"
        if [[ -f "$acme_rsa_dir/fullchain.cer" && -f "$acme_rsa_dir/${domain}.key" ]]; then
            /usr/local/x-ui/x-ui cert -webCert "$acme_rsa_dir/fullchain.cer" -webCertKey "$acme_rsa_dir/${domain}.key"
            /usr/local/x-ui/x-ui setting -subCertFile "$acme_rsa_dir/fullchain.cer" -subKeyFile "$acme_rsa_dir/${domain}.key"
            cert_file="$acme_rsa_dir/fullchain.cer"
            key_file="$acme_rsa_dir/${domain}.key"
            echo -e "${green}acme.sh RSA certificate used for x-ui.${plain}"
            echo -e "${green}已直接使用acme.sh RSA证书文件配置x-ui${plain}"
            systemctl restart x-ui
        else
            echo -e "${red}No valid certificate file found, please check acme.sh output and certificate path manually.${plain}"
            echo -e "${red}未找到可用的证书文件，请手动检查acme.sh输出和证书路径${plain}"
            exit 1
        fi
    fi

    # 自动续期
    if ! crontab -l 2>/dev/null | grep -q 'acme.sh --cron'; then
        (crontab -l 2>/dev/null; echo "0 3 1 */2 * ~/.acme.sh/acme.sh --cron --home ~/.acme.sh > /dev/null") | crontab -
        echo -e "${green}acme.sh auto-renewal scheduled every 2 months.${plain}"
        echo -e "${green}已设置acme.sh自动续期定时任务（每2个月1号凌晨3点自动续期）${plain}"
    fi
    # 安装并配置nginx，传递实际证书路径
    install_nginx_with_cert "$domain" "$cert_file" "$key_file"

    # 安装结束后统一输出登录信息
    if [[ -f /tmp/xui_install_info ]]; then
        echo -e "\n${yellow}Panel login information below, please keep it safe:${plain}"
        echo -e "${yellow}面板登录信息如下，请妥善保存：${plain}"
        cat /tmp/xui_install_info
        # 新增：如果有域名和端口，输出域名登录链接
        if [[ -n "$domain" && -n "$cert_file" ]]; then
            # 获取 webBasePath 和端口
            webBasePath=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'webBasePath: .+' | awk '{print $2}')
            panel_port=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'port: .+' | awk '{print $2}')
            # 默认协议 https
            protocol="https"
            # 如果端口为80则用http
            #//if [[ "$panel_port" == "80" ]]; then
            #//    protocol="http"
            #//fi
            if [[ -n "$webBasePath" && -n "$panel_port" ]]; then
                echo -e "${green}Domain login link: ${protocol}://${domain}:${panel_port}/${webBasePath}${plain}"
                echo -e "${green}域名登录链接：${protocol}://${domain}:${panel_port}/${webBasePath}${plain}"
            fi
        fi
        rm -f /tmp/xui_install_info
    fi

    # 显示客户端下载地址
    echo -e "${green}Client download links:${plain}"
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
