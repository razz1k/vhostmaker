#!/bin/bash

#Options. Insert yours
user=$(ls -la | head -n 2 | tail -n 1 | awk '{print $3;}');
group=$user;
basedir="/home/$user/projects/"

#Showing help (help --help)
if [ "$1" == "help" ] || [ "$1" == "--help" ]; then
	echo "Virtual host maker (for Nginx)"
	echo "Just run from root"
	exit 0
fi

if [ "$EUID" -ne 0 ]
	then echo "Please run me as root"
	exit
fi

#Search php sock
PHP_SOCK=$(ls /var/run/php/*.sock | head -1)
if [ "$PHP_SOCK" == "" ]; then
	echo "No php-fpm.sock is found"
	exit
fi

#Get user input
read -p "Enter WebSite Name (example.local): " site_name
read -p "Enter WebSite folder (example): " catalog

#Making folders
fullpath=$basedir$catalog
mkdir $fullpath $fullpath'/logs' $fullpath'/http'
echo "Folders ready"

#Making index.php
indexfile=$fullpath'/http/index.php'
touch $indexfile
echo -e "<?php 
echo \042<h1>$site_name Work!</h1>\042;" >> $indexfile
echo "index.php ready"

#Making logrotate confing
cat <<EOF > /etc/logrotate.d/$site_name.nginx
$fullpath/logs/*.log {
        weekly
        missingok
        rotate 52
        compress
        delaycompress
        notifempty
        create 644 nginx adm
        sharedscripts
        dateext dateformat -%Y.%m.%d
}
EOF

#Making nginx confing
configname="/etc/nginx/conf.d/"$catalog".conf"
touch $configname
echo "server {
	listen 80;
	server_name $site_name;
	access_log $fullpath/logs/access.log;
	error_log $fullpath/logs/error.log;
	root $fullpath/http;
	index index.php index.html;
	charset utf-8;
  
	location / {
		try_files       \$uri \$uri/ @rewrite;
	}

	location @rewrite {
		rewrite         ^/(.*)\$ /index.php?q=\$1;
	}

	location ~ \.php\$ {
		fastcgi_pass  unix:$PHP_SOCK;
		fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
		include fastcgi_params;
	}

	#static files caching
	location ~* ^.+\.(ogg|ogv|svg|svgz|eot|otf|woff|mp4|ttf|rss|atom|jpg|jpeg|gif|png|ico|zip|tgz|gz|rar|bz2|doc|xls|exe|ppt|tar|mid|midi|wav|bmp|rtf|css|js|webp)$ {
		access_log off;
		log_not_found off;
		expires 8d;
	}

	location = /robots.txt { access_log off; log_not_found off; }
	location ~ /\. { deny  all; access_log off; log_not_found off; }
}
" > $configname

echo "Nginx config ready"

#Changing folders and files permissions
cd $fullpath
chown -R $user:$group $fullpath;
find $fullpath -type d -exec chmod 0755 '{}' \;
find $fullpath -type f -exec chmod 0644 '{}' \;
chmod +x $fullpath
echo "Permissions ready"

#Adding hostname to hosts
echo "127.0.0.1 $site_name" >> /etc/hosts
echo "/etc/hosts ready"

#Let's restart Nginx

service nginx restart
echo "Nginx restarted"
echo "$site_name is ready"
xdg-open http://$site_name
