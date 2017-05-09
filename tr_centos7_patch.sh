#!/bin/bash
# Transmission auto install centos7_patch v0.1
#安装说明参见 https://sadsu.com/?p=16
#----------------------------------------------------------#
#                  Variables&Functions                     #
#----------------------------------------------------------#
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
hostip=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${hostip} ] && hostip=$(ip route get 8.8.8.8 | awk 'NR==1 {print $NF}')

	get_char() {
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}

	
conf_transmission(){
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
echo -e "=                 Transmission centos7补丁打完                         ="
echo -e "=           前往http://$hostip:9091/服务器开始bt吧                     ="
echo -e "=                                                                      ="
echo -e "========================================================================"
}


echo
echo "###############################################################"
echo "# Transmission Auto Installer Centos 7 patch                  #"
echo "# System Supported: CentOS 7                                 #"
echo "# Intro: https://sadsu.com/?p=16                              #"
echo "# Author: kevin <yanglci@sadsu.com>                           #"
echo "###############################################################"
echo
echo  "如果你安装tr_install卡死在                                   "
echo  "Starting transmission-daemon (via systemctl):                "
echo  "按ctrl+C强行跳出后，会导致后面的配置文件以及防火墙未被修改   "
echo  "需要运行本补丁进行修复，                                     "
echo  "如果你正常安装完程序是不需要运行本补丁的.                    "
echo  "本补丁运行完会再次启动transmission，可能还会卡住，           "
echo  "ctrl+C  后不需关注，程序已后台运行中                         "
echo



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


conf_transmission
config_firewall
show_end
service transmission-daemon start
