#!/bin/bash

apache_config_file="/etc/apache2/apache2.conf"
php_config_file="/etc/php/7.2/apache2/php.ini"
xdebug_config_file="/etc/php/7.2/mods-available/xdebug.ini"
mysql_config_file="/etc/mysql/my.cnf"

# Update the server
apt-get update
apt-get -y upgrade

apt-get -y install apache2 php libapache2-mod-php php-mysql php-xdebug php-xml php-json php-gd php-bcmath php-bz2 php-cli php-curl php-intl php-json php-mbstring php-opcache php-soap php-sqlite3 php-xml php-xsl php-zip

sed -i "s/display_startup_errors = Off/display_startup_errors = On/g" ${php_config_file}
sed -i "s/display_errors = Off/display_errors = On/g" ${php_config_file}

cat << EOF > ${xdebug_config_file}
zend_extension=xdebug.so
xdebug.remote_enable=1
xdebug.remote_connect_back=1
xdebug.remote_port=9000
EOF

echo "mysql-server mysql-server/root_password password secret" | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again password secret" | sudo debconf-set-selections
apt-get -y install mysql-client mysql-server

sed -i "s/bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/" ${mysql_config_file}

usermod -d /var/lib/mysql/ mysql
service mysql start

# Allow root access from any host
echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'secret' WITH GRANT OPTION" | mysql -u root --password=secret
echo "GRANT PROXY ON ''@'' TO 'root'@'%' WITH GRANT OPTION" | mysql -u root --password=secret
service mysql restart

cat << EOF >> ${apache_config_file}
AcceptFilter https none
AcceptFilter http none
EOF

echo '<VirtualHost *:80>
	DocumentRoot /var/www/html
	AllowEncodedSlashes On
	<Directory /var/www/html>
		Options +Indexes +FollowSymLinks
		DirectoryIndex index.php index.html
		Order allow,deny
		Allow from all
		AllowOverride All
	</Directory>
	ErrorLog ${APACHE_LOG_DIR}/error.log
	CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>' > /etc/apache2/sites-available/000-default.conf

rm -rf /var/www/html/*
echo '
<?php

phpinfo();

' > /var/www/html/index.php

if [ -e /usr/local/bin/composer ]; then
    /usr/local/bin/composer self-update
else
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
fi

a2enmod rewrite
service apache2 restart
