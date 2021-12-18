#/bin/bash
#scipt install LEMP (Compile nginx, PHP)
#Author: 


RELEASE=`cat /etc/redhat-release`
isCent6=false
isCent7=false
isphp5=false
isphp7=false

yum install -y epel* 
yum install -y wget git perl-ExtUtils-Embed pam-devel gcc gcc-c++ make geoip-devel
#For PHP compile

yum groupinstall -y 'Development Tools'
yum install -y libxml2-devel libXpm-devel gmp-devel libicu-devel t1lib-devel aspell-devel openssl-devel \
bzip2-devel libcurl-devel libjpeg-devel libvpx-devel libpng-devel freetype-devel readline-devel libtidy-devel\
libxslt-devel libmcrypt-devel pcre-devel curl-devel mysql-devel ncurses-devel gettext-devel\
net-snmp-devel libevent-devel libtool-ltdl-devel libc-client-devel postgresql-devel


#Build GCC Ver 4.8
#rpm --import http://linuxsoft.cern.ch/cern/slc68/i386/RPM-GPG-KEY-cern
#wget -O /etc/yum.repos.d/slc6-devtoolset.repo https://linux.web.cern.ch/linux/scientific6/docs/repository/cern/devtoolset/slc6-devtoolset.repo
#yum install devtoolset-2-gcc-c++ devtoolset-2-binutils -y
#wget http://people.centos.org/tru/devtools-2/devtools-2.repo -O /etc/yum.repos.d/devtools-2.repo
#yum install devtoolset-2-gcc devtoolset-2-binutils -y
#yum install devtoolset-2-gcc-c++ devtoolset-2-gcc-gfortran -y

#before install
cd ~
script_pwd=`pwd`
script_source="${script_pwd}/src"

if [ ! -d "${script_source}" ]; then
	mkdir -p "${script_source}"
fi

wget https://ftp.pcre.org/pub/pcre/pcre-8.42.tar.gz -P ${script_source}
wget https://ftp.openssl.org/source/old/1.0.2/openssl-1.0.2k.tar.gz -P ${script_source}
wget https://download.videolan.org/contrib/zlib/zlib-1.2.11.tar.gz -P ${script_source}
cd ${script_source}
git clone git://github.com/vozlt/nginx-module-vts.git
git clone git://github.com/FRiCKLE/ngx_cache_purge.git
git clone git://github.com/kyprizel/testcookie-nginx-module.git

#extract file
tar -xvzf pcre-8.42.tar.gz
tar -xvzf openssl-1.0.2k.tar.gz
tar -xvzf zlib-1.2.11.tar.gz

cd - > /dev/null

RUN_COMPILE_NGINX() {
	./configure \
		--user=nginx \
		--group=nginx \
		--prefix=/etc/nginx \
		--sbin-path=/usr/sbin/nginx \
		--conf-path=/etc/nginx/nginx.conf \
		--error-log-path=/var/log/nginx/error.log \
		--http-log-path=/var/log/nginx/access.log \
		--pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock \
		--http-client-body-temp-path=/var/cache/nginx/client_temp \
		--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
		--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
		--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
		--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
		--with-file-aio \
		--with-http_gzip_static_module \
		--with-http_stub_status_module \
		--with-http_ssl_module \
		--with-http_realip_module \
		--with-http_addition_module \
		--with-http_sub_module \
		--with-http_dav_module \
		--with-http_gunzip_module \
		--with-http_degradation_module \
		--with-http_perl_module \
		--with-debug \
		--with-http_v2_module \
		--with-http_geoip_module \
		--without-http_empty_gif_module \
		--without-http_browser_module \
		--without-http_uwsgi_module \
		--without-http_scgi_module \
		--with-pcre=${script_source}/pcre-8.42 \
		--with-zlib=${script_source}/zlib-1.2.11 \
		--with-openssl=${script_source}/openssl-1.0.2k \
		--add-module=${script_source}/nginx-module-vts \
		--add-module=${script_source}/ngx_cache_purge \
		--add-module=${script_source}/testcookie-nginx-module
}

CREATE_USER_NGINX() {
	if [ ! `cat /etc/passwd | grep nginx` ]; then
		groupadd -r nginx 
        useradd -r -s /sbin/nologin -M -c "nginx service" -g nginx nginx
		echo "Finished create user nginx, continues create startup script..."
		sleep 5
	else
		echo "existed user nginx, continues create startup script..."
		sleep 5
fi
}

CREATE_STARTUP_SCRIPT_NGX() {
	if [ $isCent6 == true ]; then
		cat << 'EOF' >> /etc/init.d/nginx
#!/bin/sh
#
# nginx - this script starts and stops the nginx daemon
#
# chkconfig:   - 85 15
# description:  NGINX is an HTTP(S) server, HTTP(S) reverse \
#               proxy and IMAP/POP3 proxy server
# processname: nginx
# config:      /etc/nginx/nginx.conf
# config:      /etc/sysconfig/nginx
# pidfile:     /var/run/nginx.pid

# Source function library.
. /etc/rc.d/init.d/functions

# Source networking configuration.
. /etc/sysconfig/network

# Check that networking is up.
[ "$NETWORKING" = "no" ] && exit 0

nginx="/usr/sbin/nginx"
prog=$(basename $nginx)

NGINX_CONF_FILE="/etc/nginx/nginx.conf"

[ -f /etc/sysconfig/nginx ] && . /etc/sysconfig/nginx

lockfile=/var/lock/subsys/nginx

make_dirs() {
   # make required directories
   user=`$nginx -V 2>&1 | grep "configure arguments:.*--user=" | sed 's/[^*]*--user=\([^ ]*\).*/\1/g' -`
   if [ -n "$user" ]; then
      if [ -z "`grep $user /etc/passwd`" ]; then
         useradd -M -s /bin/nologin $user
      fi
      options=`$nginx -V 2>&1 | grep 'configure arguments:'`
      for opt in $options; do
          if [ `echo $opt | grep '.*-temp-path'` ]; then
              value=`echo $opt | cut -d "=" -f 2`
              if [ ! -d "$value" ]; then
                  # echo "creating" $value
                  mkdir -p $value && chown -R $user $value
              fi
          fi
       done
    fi
}

start() {
    [ -x $nginx ] || exit 5
    [ -f $NGINX_CONF_FILE ] || exit 6
    make_dirs
    echo -n $"Starting $prog: "
    daemon $nginx -c $NGINX_CONF_FILE
    retval=$?
    echo
    [ $retval -eq 0 ] && touch $lockfile
    return $retval
}

stop() {
    echo -n $"Stopping $prog: "
    killproc $prog -QUIT
    retval=$?
    echo
    [ $retval -eq 0 ] && rm -f $lockfile
    return $retval
}

restart() {
    configtest || return $?
    stop
    sleep 1
    start
}

reload() {
    configtest || return $?
    echo -n $"Reloading $prog: "
    killproc $nginx -HUP
    RETVAL=$?
    echo
}

force_reload() {
    restart
}

configtest() {
  $nginx -t -c $NGINX_CONF_FILE
}

rh_status() {
    status $prog
}

rh_status_q() {
    rh_status >/dev/null 2>&1
}

case "$1" in
    start)
        rh_status_q && exit 0
        $1
        ;;
    stop)
        rh_status_q || exit 0
        $1
        ;;
    restart|configtest)
        $1
        ;;
    reload)
        rh_status_q || exit 7
        $1
        ;;
    force-reload)
        force_reload
        ;;
    status)
        rh_status
        ;;
    condrestart|try-restart)
        rh_status_q || exit 0
            ;;
    *)
        echo $"Usage: $0 {start|stop|status|restart|condrestart|try-restart|reload|force-reload|configtest}"
        exit 2
esac

EOF
		chmod +x /etc/init.d/nginx
		chkconfig nginx on
		/etc/init.d/nginx stop
		mkdir -p /var/cache/nginx/
		mkdir -p /var/log/nginx/domains/
		mv /etc/nginx/html/index.html /etc/nginx/html/index.html.bak
		cat << 'EOF' > /etc/nginx/html/index.html
<h1>Install nginx success!</h1>
Make by Tri Tran		
EOF
		
		/etc/init.d/nginx start
		echo "finished compile nginx, continues compile PHP"
	elif [ $isCent7 == true ]; then
		cat << 'EOF' >> /lib/systemd/system/nginx.service
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network.target remote-fs.target nss-lookup.target
 
[Service]
Type=forking
PIDFile=/var/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true
 
[Install]
WantedBy=multi-user.target		
EOF
		chmod +x /lib/systemd/system/nginx.service
		systemctl enable nginx.service
        systemctl stop nginx.service
		mkdir -p /var/cache/nginx/
		mkdir -p /var/log/nginx/domains/
		mv /etc/nginx/html/index.html /etc/nginx/html/index.html.bak
		cat << 'EOF' > /etc/nginx/html/index.html
<h1>Install nginx success!</h1>
Make by Tri Tran		
EOF
		
        systemctl start nginx.service
		echo "finished compile nginx, continues compile PHP ..."
		echo -e "\n"
	fi
}


COMPILE_NGINX() {
	cd ${script_source}
	wget http://nginx.org/download/nginx-1.13.11.tar.gz
	tar -xvzf nginx-1.13.11.tar.gz
	cd nginx-1.13.11
	RUN_COMPILE_NGINX
	make && make install
	if [ $? == 0 ]; then
		echo "Finished compile nginx from source!"
		sleep 5
		echo "Continue create user nginx"
	else
		echo "Error!"
		break
	fi
	CREATE_USER_NGINX
	CREATE_STARTUP_SCRIPT_NGX
}

#Compile PHP

COMPILE_PHP_5() {
	cd $script_source
	if [ ! -d "php-5.6.35" ]; then
		wget http://mirrors.sohu.com/php/php-5.6.35.tar.gz
	fi
	tar -xvzf php-5.6.35.tar.gz
	cd php-5.6.35
	./configure \
		--prefix=/opt/php-5.6 \
		--with-pdo-pgsql \
		--with-zlib-dir \
		--with-freetype-dir \
		--enable-mbstring \
		--with-libxml-dir=/usr \
		--enable-soap \
		--enable-calendar \
		--with-curl \
		--with-mcrypt \
		--with-zlib \
		--with-gd \
		--with-pgsql \
		--disable-rpath \
		--enable-inline-optimization \
		--with-bz2 \
		--with-zlib \
		--enable-sockets \
		--enable-sysvsem \
		--enable-sysvshm \
		--enable-pcntl \
		--enable-mbregex \
		--with-mhash \
		--enable-zip \
		--with-pcre-regex \
		--with-mysql \
		--with-pdo-mysql \
		--with-mysqli \
		--with-mysql-sock=/var/lib/mysql/mysql.sock \
		--with-jpeg-dir=/usr \
		--with-png-dir=/usr \
		--enable-gd-native-ttf \
		--with-openssl \
		--with-fpm-user=nginx \
		--with-fpm-group=nginx \
		--with-libdir=lib64 \
		--enable-ftp \
		--with-imap \
		--with-imap-ssl \
		--with-kerberos \
		--with-gettext \
		--enable-fpm
	make && make install
	cp -f $script_source/php-5.6.35/php.ini-production /opt/php-5.6/lib/php.ini
	cp -f /opt/php-5.6/etc/php-fpm.conf.default /opt/php-5.6/etc/php-fpm.conf
	sed -i 's|;pid = run/php-fpm.pid|pid = run/php-fpm.pid|g' /opt/php-5.6/etc/php-fpm.conf
	sed -i 's|listen = 127.0.0.1:9000|;listen = 127.0.0.1:9000|g' /opt/php-5.6/etc/php-fpm.conf
	echo -e "listen = /var/run/php5.6-fpm.sock" >> /opt/php-5.6/etc/php-fpm.conf
}

SCRIPT_STARTUP_PHP5() {
	cd $script_pwd
	if [ $isCent6 == true ]; then
		#create file startup service for centOS 6
		cat << 'EOF' >> /etc/init.d/php56-fpm
#! /bin/sh
### BEGIN INIT INFO
# Provides:          php-5.6-fpm
# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts php-5.6.30-fpm
# Description:       starts the PHP FastCGI Process Manager daemon
### END INIT INFO
php_fpm_BIN=/opt/php-5.6/sbin/php-fpm
php_fpm_CONF=/opt/php-5.6/etc/php-fpm.conf
php_fpm_PID=/opt/php-5.6/var/run/php-fpm.pid
php_opts="--fpm-config $php_fpm_CONF"

wait_for_pid () {
        try=0
        while test $try -lt 35 ; do
                case "$1" in
                        'created')
                        if [ -f "$2" ] ; then
                                try=''
                                break
                        fi
                        ;;
                        'removed')
                        if [ ! -f "$2" ] ; then
                                try=''
                                break
                        fi
                        ;;
                esac
                echo -n .
                try=`expr $try + 1`
                sleep 1
        done
}
case "$1" in
        start)
                echo -n "Starting php-fpm "
                $php_fpm_BIN $php_opts
                if [ "$?" != 0 ] ; then
                        echo " failed"
                        exit 1
                fi
                wait_for_pid created $php_fpm_PID
                if [ -n "$try" ] ; then
                        echo " failed"
                        exit 1
                else
                        echo " done"
                fi
        ;;
        stop)
                echo -n "Gracefully shutting down php-fpm "
                if [ ! -r $php_fpm_PID ] ; then
                        echo "warning, no pid file found - php-fpm is not running ?"
                        exit 1
                fi
                kill -QUIT `cat $php_fpm_PID`
                wait_for_pid removed $php_fpm_PID
                if [ -n "$try" ] ; then
                        echo " failed. Use force-exit"
                        exit 1
                else
                        echo " done"
                       echo " done"
                fi
        ;;
        force-quit)
                echo -n "Terminating php-fpm "
                if [ ! -r $php_fpm_PID ] ; then
                        echo "warning, no pid file found - php-fpm is not running ?"
                        exit 1
                fi
                kill -TERM `cat $php_fpm_PID`
                wait_for_pid removed $php_fpm_PID
                if [ -n "$try" ] ; then
                        echo " failed"
                        exit 1
                else
                        echo " done"
                fi
        ;;
        restart)
                $0 stop
                $0 start
        ;;
        reload)
                echo -n "Reload service php-fpm "
                if [ ! -r $php_fpm_PID ] ; then
                        echo "warning, no pid file found - php-fpm is not running ?"
                        exit 1
                fi
                kill -USR2 `cat $php_fpm_PID`
                echo " done"
        ;;
        *)
                echo "Usage: $0 {start|stop|force-quit|restart|reload}"
                exit 1
        ;;
esac
EOF
		chmod +x /etc/init.d/php56-fpm
		chkconfig php56-fpm on
		/etc/init.d/php56-fpm stop
		/etc/init.d/php56-fpm start
	elif [ $isCent7 == true ]; then
		#create file startup service for centOS 7
		cat << 'EOF' >> /lib/systemd/system/php56-fpm.service
[Unit]
Description=The PHP 5.6 FastCGI Process Manager
After=network.target

[Service]
Type=simple
PIDFile=/opt/php-5.6/var/run/php-fpm.pid
ExecStart=/opt/php-5.6/sbin/php-fpm --nodaemonize --fpm-config /opt/php-5.6/etc/php-fpm.conf
ExecReload=/bin/kill -USR2 $MAINPID

[Install]
WantedBy=multi-user.target
EOF
		chmod +x /lib/systemd/system/php56-fpm.service
		systemctl enable php56-fpm.service
		systemctl stop php56-fpm.service
		systemctl start php56-fpm.service
	fi	
}

COMPILE_PHP_7() {
	cd $script_source
	if [ ! -d "php-7.1.16" ]; then
		wget http://mirrors.sohu.com/php/php-7.1.16.tar.gz
	fi
	tar -xvzf php-7.1.16.tar.gz
	cd php-7.1.16
	./configure \
		--prefix=/opt/php-7.1 \
		--with-pdo-pgsql \
		--with-zlib-dir \
		--with-freetype-dir \
		--enable-mbstring \
		--with-libxml-dir=/usr \
		--enable-soap \
		--enable-calendar \
		--with-curl \
		--with-mcrypt \
		--with-gd \
		--with-pgsql \
		--disable-rpath \
		--enable-inline-optimization \
		--with-bz2 \
		--with-zlib \
		--enable-sockets \
		--enable-sysvsem \
		--enable-sysvshm \
		--enable-pcntl \
		--enable-mbregex \
		--with-mhash \
		--enable-zip \
		--with-pcre-regex \
		--with-mysqli \
		--with-mysql-sock=/var/lib/mysql/mysql.sock \
		--with-jpeg-dir=/usr \
		--with-png-dir=/usr \
		--enable-gd-native-ttf \
		--with-openssl \
		--with-fpm-user=nginx \
		--with-fpm-group=nginx \
		--with-libdir=lib64 \
		--enable-ftp \
		--with-imap \
		--with-imap-ssl \
		--with-kerberos \
		--with-gettext \
		--enable-fpm
	make && make install
	cp -f $script_source/php-7.1.16/php.ini-production /opt/php-7.1/lib/php.ini
	cp -f /opt/php-7.1/etc/php-fpm.conf.default /opt/php-7.1/etc/php-fpm.conf
	sed -i 's|;pid = run/php-fpm.pid|pid = run/php-fpm.pid|g' /opt/php-7.1/etc/php-fpm.conf
	##echo -e "listen = /var/run/php7.1-fpm.sock" >> /opt/php-7.1/etc/php-fpm.conf
	cp -f /opt/php-7.1/etc/php-fpm.d/www.conf.default /opt/php-7.1/etc/php-fpm.d/www.conf
}

SCRIPT_STARTUP_PHP7() {
	cd $script_pwd
	if [ $isCent6 == true ]; then
		#create script startup file for centOS 6
		cat << 'EOF' >> /etc/init.d/php71-fpm
#! /bin/sh
### BEGIN INIT INFO
# Provides:          php71-fpm
# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts php71-fpm
# Description:       starts the PHP FastCGI Process Manager daemon
### END INIT INFO
php_fpm_BIN=/opt/php-7.1/sbin/php-fpm
php_fpm_CONF=/opt/php-7.1/etc/php-fpm.conf
php_fpm_PID=/opt/php-7.1/var/run/php-fpm.pid
php_opts="--fpm-config $php_fpm_CONF"

wait_for_pid () {
        try=0
        while test $try -lt 35 ; do
                case "$1" in
                        'created')
                        if [ -f "$2" ] ; then
                                try=''
                                break
                        fi
                        ;;
                        'removed')
                        if [ ! -f "$2" ] ; then
                                try=''
                                break
                        fi
                        ;;
                esac
                echo -n .
                try=`expr $try + 1`
                sleep 1
        done
}
case "$1" in
        start)
                echo -n "Starting php-fpm "
                $php_fpm_BIN $php_opts
                if [ "$?" != 0 ] ; then
                        echo " failed"
                        exit 1
                fi
                wait_for_pid created $php_fpm_PID
                if [ -n "$try" ] ; then
                        echo " failed"
                        exit 1
                else
                        echo " done"
                fi
        ;;
        stop)
                echo -n "Gracefully shutting down php-fpm "
                if [ ! -r $php_fpm_PID ] ; then
                        echo "warning, no pid file found - php-fpm is not running ?"
                        exit 1
                fi
                kill -QUIT `cat $php_fpm_PID`
                wait_for_pid removed $php_fpm_PID
                if [ -n "$try" ] ; then
                        echo " failed. Use force-exit"
                        exit 1
                else
                        echo " done"
                       echo " done"
                fi
        ;;
        force-quit)
                echo -n "Terminating php-fpm "
                if [ ! -r $php_fpm_PID ] ; then
                        echo "warning, no pid file found - php-fpm is not running ?"
                        exit 1
                fi
                kill -TERM `cat $php_fpm_PID`
                wait_for_pid removed $php_fpm_PID
                if [ -n "$try" ] ; then
                        echo " failed"
                        exit 1
                else
                        echo " done"
                fi
        ;;
        restart)
                $0 stop
                $0 start
        ;;
        reload)
                echo -n "Reload service php-fpm "
                if [ ! -r $php_fpm_PID ] ; then
                        echo "warning, no pid file found - php-fpm is not running ?"
                        exit 1
                fi
                kill -USR2 `cat $php_fpm_PID`
                echo " done"
        ;;
        *)
                echo "Usage: $0 {start|stop|force-quit|restart|reload}"
                exit 1
        ;;
esac
	
EOF
		chmod +x /etc/init.d/php71-fpm
		chkconfig php71-fpm on
		/etc/init.d/php71-fpm stop
		/etc/init.d/php71-fpm start
	elif [ $isCent7 == true ]; then
		#create script startup file for centOS 7
		cat << 'EOF' >> /lib/systemd/system/php71-fpm.service
[Unit]
Description=The PHP FastCGI Process Manager
After=network.target

[Service]
Type=simple
PIDFile=/opt/php-7.1/var/run/php-fpm.pid
ExecStart=/opt/php-7.1/sbin/php-fpm --nodaemonize --fpm-config /opt/php-7.1/etc/php-fpm.conf
ExecReload=/bin/kill -USR2 $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
		
EOF
		chmod +x /lib/systemd/system/php71-fpm.service
		systemctl enable php71-fpm.service
		systemctl stop php71-fpm.service
		systemctl start php71-fpm.service
	fi
}


for i in $RELEASE; do
				if [ ${i:0:1} == "6" ]; then
					echo "OS is CentOS 6"
					isCent6=true
					COMPILE_NGINX
			
				elif [ ${i:0:1} == "7" ]; then
					echo "OS is CentOS 7"
					isCent7=true
					COMPILE_NGINX		
        fi
done

#Install mariaDB 10.2
INSTALL_MARIADB() {
	if [ $isCent6 == true ]; then
		cat << 'EOF' >> /etc/yum.repos.d/MariaDB.repo
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.2/centos6-amd64/
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
	yum repolist
	yum install MariaDB-server MariaDB-client -y
	mv /etc/my.cnf /etc/my.cnf.bak
	cp -f /usr/share/mysql/my-large.cnf /etc/my.cnf
		chkconfig mysql on
		/etc/init.d/mysql stop
		/etc/init.d/mysql start
		echo "Finished install mariadb, use command *mysql_secure_installation* to setting password user root mysql!"
	elif [ $isCent7 == true ]; then
		cat << 'EOF' >> /etc/yum.repos.d/MariaDB.repo
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.2/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
	yum repolist
	yum install MariaDB-server MariaDB-client -y
	mv /etc/my.cnf /etc/my.cnf.bak
	cp -f /usr/share/mysql/my-large.cnf /etc/my.cnf
		systemctl enable mariadb.service
		systemctl stop mariadb.service
		systemctl start mariadb.service
		echo "Finished install mariadb, use command *mysql_secure_installation* to setting password user root mysql!"		
	fi
}



echo -e "====================================================\n"
PS3="Select version PHP, Please: "
echo -e "===================================================="
selection=("PHP 5.6" "PHP 7.1")
	
select i in "${selection[@]}"; do
	case $i in
		"PHP 5.6")
			COMPILE_PHP_5
			SCRIPT_STARTUP_PHP5
			echo "Finshed compile PHP, continues install mariadb ..."
			sleep 10
			INSTALL_MARIADB
			break
			;;
		"PHP 7.1")
			COMPILE_PHP_7
			SCRIPT_STARTUP_PHP7
			echo "Finshed compile PHP, continues install mariadb ..."
			sleep 10
			INSTALL_MARIADB
			break
			;;
			*) echo "invalid option"
	esac
done
