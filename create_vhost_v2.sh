
echo "Input Domain Name: "
read domain_name

echo "domain name is: $domain_name"
user_name=`echo $domain_name | sed -e 's/\.//g'`
echo "user name will create is: $user_name"

mkdir -p /home/$user_name/domains/$domain_name/public_html
useradd $user_name

cat << 'EOF' >> /home/$user_name/domains/$domain_name/public_html/index.php
<?php
	phpinfo();
?>
EOF
chown $user_name: -R /home/$user_name/

#create vhost nginx
CREATE_VHOST_NGINX_1(){
	touch /etc/nginx/conf.d/$domain_name.conf
	cat << 'EOF' >> /etc/nginx/conf.d/$domain_name.conf
fastcgi_cache_path /dev/shm/nginx-cache-user_name levels=1:2 keys_zone=user_name:400m max_size=500m inactive=20m;
#fastcgi_cache_key "$scheme$request_method$host$request_uri";
fastcgi_cache_key "$scheme$request_method$host$request_uri$rt_session";
fastcgi_cache_use_stale error timeout invalid_header http_500;
fastcgi_ignore_headers Cache-Control Expires Set-Cookie;


# limit the number of connections per single IP
limit_conn_zone $binary_remote_addr zone=conn_limit_per_ip:10m;

# limit the number of requests for a given session
limit_req_zone $binary_remote_addr zone=req_limit_per_ip:10m rate=7r/s;

server {
    listen 80 default_server;
    server_name _;
    return 404;
}

server {
    listen 80;
    server_name domain_name;
    add_header Strict-Transport-Security max-age=15768000 always;
    add_header X-Cache-Status $upstream_cache_status always;
    add_header X-Frame-Options "SAMEORIGIN";

    root /home/user_name/domains/domain_name/public_html;

    index index.php;

    # [ debug | info | notice | warn | error | crit | alert | emerg ]
    access_log /var/log/nginx/domains/domain_name.log main_ext;
    error_log /var/log/nginx/domains/domain_name.error.log warn;


    #deny IP country
    if ($allowed_country = no) {
       return 444;
    }

    location / {
        try_files $uri $uri/ /index.php?$args;
		#try_files $uri $uri/ /index.php?$query_string;
    }
    set $skip_cache 0;

	# POST requests and urls with a query string should always go to PHP
	if ($request_method = POST) {
		set $skip_cache 1;
	}   
	if ($query_string != "") {
		set $skip_cache 1;
	}   

	if ( $cookie_woocommerce_items_in_cart = "1" ){
		 set $skip_cache 1;
	}

	# Don't cache uris containing the following segments
	if ($request_uri ~* "/shop.*|/cart.*|/my-account.*|/checkout.*|/addons.*|/thanh-toan.*|/gio-hang.*|/wp-admin/|/xmlrpc.php|/wp-.*.php|index.php") {
		set $skip_cache 1;
	}   

	# Don't use the cache for logged in users or recent commenters
	if ($http_cookie ~* "comment_author|wordpress_[a-f0-9]+|wp-postpass|wordpress_no_cache|wordpress_logged_in") {
		set $skip_cache 1;
	}


    #location @fastcgi {	##turn on when protectlayer.conf is enable##
    location ~ \.php$ {
		set $rt_session "";
	 	
		if ($http_cookie ~* "wp_woocommerce_session_[^=]*=([^%]+)%7C") {
               		set $rt_session wp_woocommerce_session_$1;
       		}	
	
		if ($skip_cache = 0 ) {
			more_clear_headers "Set-Cookie*";
			set $rt_session "";
		}
	
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php7.1-fpm.user_name.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param SCRIPT_NAME $fastcgi_script_name;
        fastcgi_index index.php;
        include fastcgi_params;

        fastcgi_read_timeout 360s;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;

        fastcgi_cache_bypass $skip_cache;
        fastcgi_no_cache $skip_cache;
        fastcgi_cache user_name;
        fastcgi_cache_valid  60m;

        fastcgi_cache_purge on from all;

        #add_header X-Cache-Status $upstream_cache_status always;

        fastcgi_cache_lock on;
        fastcgi_cache_lock_timeout 5s;
    }

    location ~ ^.+\.(jpeg|jpg|png|gif|bmp|ico|svg|css|js)$ {
        expires max;
    }

    location ~ /purge(/.*) {
        fastcgi_cache_purge user_name "$scheme$request_method$host$1";
	allow all;
    }


    location /status {
        vhost_traffic_status_display;
        vhost_traffic_status_display_format html;
        allow all;
    }

    location /robots.txt {
	return 404;
    }

    #include /etc/nginx/ddos.conf;
    #include protectlayer7.conf;
}
EOF
	sed -i "s|user_name|$user_name|g" /etc/nginx/conf.d/$domain_name.conf
	sed -i "s|domain_name|$domain_name|g" /etc/nginx/conf.d/$domain_name.conf
	
	nginx -t
	nginx -s reload
	echo "done config vhost nginx..."
}

CREATE_VHOST_NGINX_2(){
	touch /etc/nginx/conf.d/$domain_name.conf
	cat << 'EOF' >> /etc/nginx/conf.d/$domain_name.conf
fastcgi_cache_path /dev/shm/nginx-cache-user_name levels=1:2 keys_zone=user_name:400m max_size=500m inactive=20m;
#fastcgi_cache_key "$scheme$request_method$host$request_uri";
#fastcgi_cache_key "$scheme$request_method$host$request_uri$rt_session";
#fastcgi_cache_use_stale error timeout invalid_header http_500;
#fastcgi_ignore_headers Cache-Control Expires Set-Cookie;


# limit the number of connections per single IP
#limit_conn_zone $binary_remote_addr zone=conn_limit_per_ip:10m;

# limit the number of requests for a given session
#limit_req_zone $binary_remote_addr zone=req_limit_per_ip:10m rate=7r/s;

server {
    listen 80;
    server_name domain_name;
    add_header Strict-Transport-Security max-age=15768000 always;
    add_header X-Cache-Status $upstream_cache_status always;
    add_header X-Frame-Options "SAMEORIGIN";

    root /home/user_name/domains/domain_name/public_html;

    index index.php;

    # [ debug | info | notice | warn | error | crit | alert | emerg ]
    access_log /var/log/nginx/domains/domain_name.log main_ext;
    error_log /var/log/nginx/domains/domain_name.error.log warn;


    #deny IP country
    if ($allowed_country = no) {
       return 444;
    }

    location / {
        try_files $uri $uri/ /index.php?$args;
		#try_files $uri $uri/ /index.php?$query_string;
    }
    set $skip_cache 0;

	# POST requests and urls with a query string should always go to PHP
	if ($request_method = POST) {
		set $skip_cache 1;
	}   
	if ($query_string != "") {
		set $skip_cache 1;
	}   

	if ( $cookie_woocommerce_items_in_cart = "1" ){
		 set $skip_cache 1;
	}

	# Don't cache uris containing the following segments
	if ($request_uri ~* "/shop.*|/cart.*|/my-account.*|/checkout.*|/addons.*|/thanh-toan.*|/gio-hang.*|/wp-admin/|/xmlrpc.php|/wp-.*.php|index.php") {
		set $skip_cache 1;
	}   

	# Don't use the cache for logged in users or recent commenters
	if ($http_cookie ~* "comment_author|wordpress_[a-f0-9]+|wp-postpass|wordpress_no_cache|wordpress_logged_in") {
		set $skip_cache 1;
	}


    #location @fastcgi {	##turn on when protectlayer.conf is enable##
    location ~ \.php$ {
		set $rt_session "";
	 	
		if ($http_cookie ~* "wp_woocommerce_session_[^=]*=([^%]+)%7C") {
               		set $rt_session wp_woocommerce_session_$1;
       		}	
	
		if ($skip_cache = 0 ) {
			more_clear_headers "Set-Cookie*";
			set $rt_session "";
		}
	
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php7.1-fpm.user_name.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param SCRIPT_NAME $fastcgi_script_name;
        fastcgi_index index.php;
        include fastcgi_params;

        fastcgi_read_timeout 360s;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;

        fastcgi_cache_bypass $skip_cache;
        fastcgi_no_cache $skip_cache;
        fastcgi_cache user_name;
        fastcgi_cache_valid  60m;

        fastcgi_cache_purge on from all;

        #add_header X-Cache-Status $upstream_cache_status always;

        fastcgi_cache_lock on;
        fastcgi_cache_lock_timeout 5s;
    }

    location ~ ^.+\.(jpeg|jpg|png|gif|bmp|ico|svg|css|js)$ {
        expires max;
    }

    location ~ /purge(/.*) {
        fastcgi_cache_purge user_name "$scheme$request_method$host$1";
	allow all;
    }


    location /status {
        vhost_traffic_status_display;
        vhost_traffic_status_display_format html;
        allow all;
    }

    location /robots.txt {
	return 404;
    }

    #include /etc/nginx/ddos.conf;
    #include protectlayer7.conf;
}
EOF
	sed -i "s|user_name|$user_name|g" /etc/nginx/conf.d/$domain_name.conf
	sed -i "s|domain_name|$domain_name|g" /etc/nginx/conf.d/$domain_name.conf
	
	nginx -t
	/etc/init.d/nginx restart
	echo "done config vhost nginx..."
}

#Create php pool
CREATE_POOL_PHP(){
	cat > /opt/php-7.1/etc/php-fpm.d/$user_name.conf <<EOF
[$user_name]

listen = /var/run/php7.1-fpm.$user_name.sock
 ;listen.backlog = -1

 ; Unix user/group of processes
user = $user_name
group = $user_name

 ; Choose how the process manager will control the number of child processes.
pm = dynamic
pm.max_children = 8
pm.start_servers = 4
pm.min_spare_servers = 2
pm.max_spare_servers = 6
pm.max_requests = 500

listen.owner = $user_name
listen.group = nobody
listen.mode = 0666
EOF
	/etc/init.d/php71-fpm restart
	echo "done config pool php-fpm..."
	echo "finished!!!"
}
#check vhost exist
if [ -f "/root/counter_vhost.txt" ]; then
	CREATE_VHOST_NGINX_2
	echo "1" > /root/counter_vhost.txt
else
	CREATE_VHOST_NGINX_1
	echo "0" > /root/counter_vhost.txt
fi

CREATE_POOL_PHP
