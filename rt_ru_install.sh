#!/bin/bash
# rtorrent&Rutorrent/CentOS7 installer v.01
#----------------------------------------------------------#
#                  Variables&Functions                     #
#----------------------------------------------------------#
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
[[ $EUID -ne 0 ]] && echo -e "${red}Error:${plain} This script must be run as root!" && exit 1
[[ -d "/proc/vz" ]] && echo -e "${red}Error:${plain} Your VPS is based on OpenVZ, not be supported." && exit 1
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

if [ $release != "centos" ]; then
	echo -e "${red}Error:${plain} This script only support centos!" && exit 1
fi

get_opsy() {
    [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}
get_char() {
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}

opsy=$( get_opsy )
arch=$( uname -m )
lbit=$( getconf LONG_BIT )
kern=$( uname -r )
hostip=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
[ -z ${hostip} ] && hostip=$(ip route get 8.8.8.8 | awk 'NR==1 {print $NF}')


[[ $opsy =~ "5." ]] && echo -e "${red}Error:${plain} This script only didn't support centos5!" && exit 1
[[ $opsy =~ "6." ]] && echo -e "${red}Error:${plain} This script only didn't support centos6!" && exit 1

install_pre(){
echo -e "${plain} "
echo -e "${plain} "
echo -e "${plain}============================================================"
echo -e "${yellow}开始安装支持程序"
echo -e "${plain}============================================================"
#安装需求配件
yum install -y gcc-c++ libtool libsigc++20 libsigc++20-devel openssl-devel ncurses* xmlrpc-c-devel epel-release zip unzip
#安装ffmpeg以及mediainfo
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
rpm --import http://li.nux.ro/download/nux/RPM-GPG-KEY-nux.ro
rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-1.el7.nux.noarch.rpm
#安装 ffmpeg，mediainfo
yum install -y ffmpeg mediainfo
#安装rar
cd /tmp
wget http://www.rarsoft.com/rar/rarlinux-x64-5.5.b1.tar.gz
tar zxf rarlinux-x64-5.5.b1.tar.gz
cd rar
make
cd /tmp
rm rar* -rf
}

install_libtorrent(){
echo -e "${plain} "
echo -e "${plain} "
echo -e "${plain}============================================================"
echo -e "${yellow}开始安装libtorrent"
echo -e "${plain}============================================================"
cd /tmp
wget http://rtorrent.net/downloads/libtorrent-0.13.6.tar.gz
tar -zxf libtorrent-0.13.6.tar.gz
cd libtorrent-0.13.6
./configure
make && make install
#清理安装文件
cd /tmp
rm libtorrent-0.13.6* -rf
}

install_rtorrent(){
echo -e "${plain} "
echo -e "${plain} "
echo -e "${plain}============================================================"
echo -e "${yellow}开始安装rtorrent"
echo -e "${plain}============================================================"
cd /tmp
#配置ld
echo "/usr/local/lib/" >> /etc/ld.so.conf
ldconfig
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
wget http://rtorrent.net/downloads/rtorrent-0.9.6.tar.gz
tar -zxf rtorrent-0.9.6.tar.gz
cd rtorrent-0.9.6
./configure --with-xmlrpc-c
make && make install
#清理安装文件
cd /tmp
rm rtorrent-0.9.6* -rf
}

rtorrent_config(){
echo -e "${plain} "
echo -e "${plain} "
echo -e "${plain}============================================================"
echo -e "${yellow}开始rtorrent配置"
echo -e "${plain}============================================================"

#rtorrent.rc配置文件下载
cd /root
wget --no-check-certificate https://raw.githubusercontent.com/kevin-cn/rotorrent-install-for-centos7/master/.rtorrent.rc
webroot_tt=${webroot//\//\\\/}
sed -i 's/\/home\/wwwroot\/default/'$webroot_tt'/g' .rtorrent.rc

#主应用目录
mkdir /home/rtorrent 
#下载文件存放目录
mkdir /home/rtorrent/download 
#种子存储目录以及过程目录
mkdir /home/rtorrent/.session 
#监控目录，用于rss下载，存放到这个目录里面的文件会自动被下载，设置轮询时长目前是30分钟，可以在.rottent.rc文件中自定义修改
mkdir /home/rtorrent/.watch 

if [ $webtype = "lnmp" ]; then
    chown -R www:www /home/rtorrent
elif [ $webtype = "vestacp(nginx)" ]; then
    chown -R admin:admin /home/rtorrent
elif [ $webtype = "vestacp(nginx+apache)" ]; then
    chown -R admin:admin /home/rtorrent
elif [ $webtype = "apache+phpfpm" ]; then
    chown -R apache:apache /home/rtorrent    
elif [ $webtype = "other" ]; then
    chown -R www:www /home/rtorrent
fi



#开机启动文件下载
cd /etc/init.d
#避免二次下载重复
wget --no-check-certificate https://raw.githubusercontent.com/kevin-cn/rotorrent-install-for-centos7/master/rtorrent
chmod 755 rtorrent
chkconfig --add rtorrent
chkconfig rtorrent on

}

install_rutorrent(){
echo -e "${plain} "
echo -e "${plain} "
echo -e "${plain}============================================================"
echo -e "${yellow}开始安装ruTorrent"
echo -e "${plain}============================================================"
cd /tmp
rm ruTorrent-3.7.zip -f
rm ruTorrent-master -rf
wget -O ruTorrent-3.7.zip https://bintray.com/novik65/generic/download_file?file_path=ruTorrent-3.7.zip
unzip -q ruTorrent-3.7.zip
rm ruTorrent-master/.htaccess -f
mv ruTorrent-master ${webroot}/rutorrent
rm ruTorrent-* -rf
}

rutorrent_config(){
echo -e "${plain} "
echo -e "${plain} "
echo -e "${plain}============================================================"
echo -e "${yellow}开始rutorrent配置"
echo -e "${plain}============================================================"
if [ $webtype = "lnmp" ]; then
    config_lnmp
elif [ $webtype = "vestacp(nginx)" ]; then
    config_vestacp_1
elif [ $webtype = "vestacp(nginx+apache)" ]; then
    config_vestacp_2
elif [ $webtype = "apache+phpfpm" ]; then
    config_apache    
elif [ $webtype = "other" ]; then
    show_howto
fi
}

config_lnmp(){
#设置目录读取权限
sed -i 's/:\/tmp\/:\/proc\//:\/tmp\/:\/proc\/:\/usr\/bin\/:\/usr\/local\/bin\/:\/home\/rtorrent/g' /usr/local/nginx/conf/fastcgi.conf
#设置RPC2/节点
sed -i '/include enable-php.conf;/a\        location \/RPC2   \{  include scgi_params;scgi_pass localhost:5000; \}' /usr/local/nginx/conf/nginx.conf
#重启nginx
service nginx restart
}

config_vestacp_1(){
#设置目录读取权限
sed -i '/fastcgi_param  REDIRECT_STATUS    200;/a\        fastcgi_param PHP_ADMIN_VALUE "open_basedir=$document_root\/:\/tmp\/:\/proc\/:\/usr\/bin\/:\/usr\/local\/bin\/:\/home\/rtorrent";' /etc/nginx/fastcgi_params
#设置RPC2/节点
sed -i '/error_page  403 \/error\/404.html;/a\    location \/RPC2   \{  include scgi_params;scgi_pass localhost:5000; \}' /home/admin/conf/web/nginx.conf
#重启nginx
service nginx restart
}

config_vestacp_2(){
#设置目录读取权限
sed -i 's/\/public_html:\/home\/admin\/tmp/\/public_html:\/home\/admin\/tmp:\/usr\/bin\/:\/usr\/local\/bin\/:\/home\/rtorrent/g' /home/admin/conf/web/httpd.conf
#设置RPC2/节点
sed -i '/.error.log error;/a\    location \/RPC2   \{  include scgi_params;scgi_pass localhost:5000; \}' /home/admin/conf/web/nginx.conf
#重启nginx,apache
service nginx restart
service httpd restart
}

config_apache(){
#设置目录读取权限
echo "php_admin_value open_basedir \"/var/www/html/:/tmp/:/proc/:/usr/bin/:/usr/local/bin/:/home/rtorrent\"" >> /etc/httpd/conf.d/php.conf
#设置RPC2/节点
echo "ProxyPass /RPC2 scgi://localhost:5000/" >> /etc/httpd/conf.d/php.conf
#重启apache
service httpd restart
}

show_howto(){
echo "程序安装已结束，请到https://sadsu.com/?p=210查看如何配置RFC2节点以及设置php_admin_value open_basedir的目录访问权限"
}

show_end(){
service rtorrent start
echo -e "========================================================================"
echo -e "=                rtorrent && rutorrent 安装完毕                         ="
echo -e "= 使用   ${yellow}http://$hostip/rutorrent ${plain}开始访问你的页面吧    ="
echo -e "=                                                                      ="
echo -e "========================================================================"
}

clear
echo "---------- System Information ----------"
echo " OS      : $opsy"
echo " Arch    : $arch ($lbit Bit)"
echo " Kernel  : $kern"
echo "----------------------------------------"
echo " Auto install rTorrent&ruTorrent For centos7"
echo
echo " URL: https://sadsu.com/?p=210"
echo "----------------------------------------"
echo


echo "  请输入web网址根目录:"
    read -p "(默认地址: /home/wwwroot/default):" webroot
    [ -z ${webroot} ] && webroot="/home/wwwroot/default"

echo && echo -e "  请选择web服务器类型
  
 ${yellow}1.${plain} LNMP环境
 ————————————
 ${yellow}2.${plain} VestaCP环境（nginx）
 ———————————— 
 ${yellow}3.${plain} VestaCP环境（nginx+Apache）
 ————————————
 ${yellow}4.${plain} 其他环境
 ———————————— " && echo
	stty erase '^H' && read -p " 请输入数字 [1-5]:" num
case "$num" in
	1)
	webtype="lnmp"
	;;
	2)
	webtype="vestacp(nginx)"
	;;
	3)
	webtype="vestacp(nginx+apache)"
	;;
	4)
	webtype="apache+phpfpm"
	;;
	5)
	webtype="other"
	;;
	*)
	echo "${plain}输入数字不正确，脚本中止" && exit 1 
	;;
esac

clear
echo -e "===========================================================
                         程序准备安装	
     你的服务器环境变量如下：
     ${plain}web服务器根目录  : ${yellow}${webroot} 
     ${plain}web服务器环境    : ${yellow}${webtype}      
${plain}==========================================================="
echo "按任意键开始安装 Ctrl+C 取消"
char=`get_char`	 

install_pre

install_libtorrent

install_rtorrent

rtorrent_config

install_rutorrent

rutorrent_config

show_end






