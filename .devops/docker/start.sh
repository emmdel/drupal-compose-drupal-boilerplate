#!/bin/sh
sudo chown -R deploy:www-data /var/www/web/sites
sudo chmod -R a+w /var/www/web/sites
# Start PHP-Fpm
sudo /usr/local/sbin/php-fpm -D
# Start SSH
sudo /usr/sbin/sshd -D