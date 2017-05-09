#!/bin/bash
# Transmission auto install  v0.1
#安装说明参见 https://sadsu.com/?p=16
#----------------------------------------------------------#
#                  Variables&Functions                     #
#----------------------------------------------------------#
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
[[ $EUID -ne 0 ]] && echo -e "${red}Error:${plain} This script must be run as root!" && exit 1
#[[ -d "/proc/vz" ]] && echo -e "${red}Error:${plain} Your VPS is based on OpenVZ, not be supported." && exit 1
if [ -f /etc/redhat-release ]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
fi

#安装程序只支持centos
[ $release != "centos" ] &&	echo -e "${red}Error:${plain} This script only support centos!" && exit 1
release_version=$(grep -o "[0-9]" /etc/redhat-release |head -n1)


get_char() {
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}

get_opsy(){
    [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

hostip=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${hostip} ] && hostip=$(ip route get 8.8.8.8 | awk 'NR==1 {print $NF}')
get_os_info(){
    local cname=$( awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
    local cores=$( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo )
    local freq=$( awk -F: '/cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
    local tram=$( free -m | awk '/Mem/ {print $2}' )
    local swap=$( free -m | awk '/Swap/ {print $2}' )
    local up=$( awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60;d=$1%60} {printf("%ddays, %d:%d:%d\n",a,b,c,d)}' /proc/uptime )
    local load=$( w | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//' )
    local opsy=$( get_opsy )
    local arch=$( uname -m )
    local lbit=$( getconf LONG_BIT )
    local host=$( hostname )
    local kern=$( uname -r )

    echo "########## System Information ##########"
    echo 
    echo "CPU model            : ${cname}"
    echo "Number of cores      : ${cores}"
    echo "CPU frequency        : ${freq} MHz"
    echo "Total amount of ram  : ${tram} MB"
    echo "Total amount of swap : ${swap} MB"
    echo "System uptime        : ${up}"
    echo "Load average         : ${load}"
    echo "OS                   : ${opsy}"
    echo "Arch                 : ${arch} (${lbit} Bit)"
    echo "Kernel               : ${kern}"
    echo "Hostname             : ${host}"
    echo "IPv4 address         : ${hostip}"
    echo 
    echo "########################################"
}



install_pre(){
echo -e "${plain} "
echo -e "${plain} "
echo -e "${plain}============================================================"
echo -e "${yellow}开始安装Transmission源以及必要组件"
echo -e "${plain}============================================================"
cd /tmp
yum install wget unzip psmisc epel-release -y
if [ "$release_version" -eq 5 ]; then
	wget http://geekery.altervista.org/geekery/el5/x86_64/geekery-release-5-1.noarch.rpm
	rpm -ivh geekery-release-5-1.noarch.rpm
	rm geekery-release-5-1.noarch.rpm -f
elif [ "$release_version" -eq 6 ]; then
	wget http://geekery.altervista.org/geekery/el6/x86_64/geekery-release-6-1.noarch.rpm
	rpm -ivh geekery-release-6-1.noarch.rpm
	rm geekery-release-6-1.noarch.rpm -f
elif [ "$release_version" -eq 7 ]; then
	wget http://geekery.altervista.org/geekery/el7/x86_64/geekery-release-7-1.noarch.rpm
	rpm -ivh geekery-release-7-1.noarch.rpm
	rm geekery-release-7-1.noarch.rpm -f
fi
cd ~
}

install_transmission(){
echo -e "${plain} "
echo -e "${plain} "
echo -e "${plain}============================================================"
echo -e "${yellow}开始安装Transmission"
echo -e "${plain}============================================================"
yum install  transmission transmission-daemon -y
}

conf_transmission(){
#启动transmission，生成配置文件
service transmission-daemon start &
#结束transmission进程，准备修改配置文件
service transmission-daemon stop
killall transmission-daemon
echo -e "${plain} "
echo -e "${plain} "
echo -e "${plain}============================================================"
echo -e "${yellow}开始修改Transmission配置"
echo -e "${plain}============================================================"
#修改/var/lib/transmission/settings.json配置项
sed -i 's/"rpc-authentication-required": false/"rpc-authentication-required": true/g' /var/lib/transmission/settings.json
sed -i 's/"rpc-username": ""/"rpc-username": "'$username'"/g' /var/lib/transmission/settings.json
sed -i 's/"rpc-whitelist-enabled": true/"rpc-whitelist-enabled": false/g' /var/lib/transmission/settings.json
sed -i "/"rpc-password"/d" /var/lib/transmission/settings.json
sed -i '/"rpc-enabled": true,/a\    "rpc-password": "'$upwd'",' /var/lib/transmission/settings.json
mkdir /var/lib/transmission/Downloads
chown -R transmission:transmission /var/lib/transmission/Downloads
#安装美化插件
wget https://github.com/ronggang/transmission-web-control/raw/master/release/tr-control-easy-install-en-http.sh --no-check-certificate
bash tr-control-easy-install-en-http.sh
}

#修改防火墙配置
config_firewall() {
    if [ "$release_version" -eq 5 ]; then
        /etc/init.d/iptables status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            iptables -L -n | grep -i 51413 > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                iptables -I INPUT -m multiport -p tcp --dport 9091,51413,49153:65534 -j ACCEPT
                /etc/init.d/iptables save
                /etc/init.d/iptables restart
            else
                echo -e "${green}Info:${plain} port ${green}9091 51413 ${plain} already be enabled."
            fi
        else
            echo -e "${yellow}Warning:${plain} iptables looks like shutdown or not installed, please enable port 9091 51413 manually if necessary."
        fi
    elif [ "$release_version" -eq 6 ]; then
        /etc/init.d/iptables status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            iptables -L -n | grep -i 51413 > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                iptables -I INPUT -m multiport -p tcp --dport 9091,51413,49153:65534 -j ACCEPT
                /etc/init.d/iptables save
                /etc/init.d/iptables restart
            else
                echo -e "${green}Info:${plain} port ${green}9091 51413${plain} already be enabled."
            fi
        else
            echo -e "${yellow}Warning:${plain} iptables looks like shutdown or not installed, please enable port 9091 51413 manually if necessary."
        fi
    elif [ "$release_version" -eq 7 ]; then
        systemctl status firewalld > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            firewall-cmd --permanent --zone=public --add-port=9091/tcp
			firewall-cmd --permanent --zone=public --add-port=51413/tcp
			firewall-cmd --permanent --zone=public --add-port=49153-65534/tcp
            firewall-cmd --reload
        else
		   systemctl status iptables > /dev/null 2>&1
		   if [ $? -eq 0 ]; then
				iptables -L -n | grep -i 51413 > /dev/null 2>&1
				if [ $? -ne 0 ]; then
					iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 51413 -j ACCEPT
					/usr/libexec/iptables/iptables.init save
					service iptables restart
				fi
		   else
				echo -e "${yellow}Warning:${plain} firewalld looks like not running, try to start..."
				systemctl start firewalld
				if [ $? -eq 0 ]; then
					firewall-cmd --permanent --zone=public --add-port=9091/tcp
					firewall-cmd --permanent --zone=public --add-port=51413/tcp
					firewall-cmd --permanent --zone=public --add-port=49153-65534/tcp
					firewall-cmd --reload
				else
					echo -e "${yellow}Warning:${plain} Start firewalld failed, please enable port 9091 51413 manually if necessary."
				fi
		   fi
        fi
    fi
}

show_end(){
echo -e "========================================================================"
echo -e "=                 Transmission安装完毕,已启动                          ="
echo -e "=           前往http://$hostip:9091/服务器开始bt吧              ="
echo -e "=                                                                      ="
echo -e "========================================================================"
}


clear

echo
echo "###############################################################"
echo "# Transmission Auto Installer                                 #"
echo "# System Supported: CentOS 5+                                 #"
echo "# Intro: https://sadsu.com/?p=16                              #"
echo "# Author: kevin <yanglc@sadsu.com>                           #"
echo "###############################################################"
echo
echo -e "${yellow}"
echo  "目前已知在centos7环境中启动transmission服务端可能会卡死         "
echo  "如果你安装tr_install.sh卡死在                     	     "
echo  "Starting transmission-daemon (via systemctl):                "
echo  "可按ctrl+C强行跳出                                            "
echo  "再运行centos7补丁进行修复即可                                  "
echo  "运行补丁程序 ：                                               "
echo  "wget https://raw.githubusercontent.com/kevin-cn/rotorrent-install-for-centos7/master/tr_centos7_patch.sh   "
echo  "chmod +x tr_centos7_patch.sh"
echo  "./tr_centos7_patch.sh"
echo -e "${plain}"
echo

get_os_info

echo "  请输入访问Transmission的用户名:"
    read -p "(默认用户名: admin):" username
    [ -z ${username} ] && username="admin"
	
echo "  请输入访问Transmission的密码:"
    read -p "(默认地址: admin):" upwd
    [ -z ${upwd} ] && upwd="admin"



echo -e "===========================================================
                         程序准备安装	
     你的Transmission访问设置如下：
     ${plain}用户名  : ${yellow}${username} 
     ${plain}密  码  : ${yellow}${upwd}      
${plain}==========================================================="
echo "按任意键开始安装 Ctrl+C 取消"
char=`get_char`	

#安装yum源以及必须软件
install_pre
#安装transmission
install_transmission
conf_transmission
config_firewall
service transmission-daemon start &
show_end
