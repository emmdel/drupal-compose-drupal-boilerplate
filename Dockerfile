FROM php:7.0-fpm

WORKDIR /

RUN apt-get update && DEBIAN_FRONTEND="noninteractive" apt-get install -y \
    openssh-server \
    git \
    mysql-client \
    ssmtp \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libmcrypt-dev \
    libpng12-dev \
    libmemcached-dev \
    unzip \
    sudo \
    vim

RUN DEBIAN_FRONTEND="noninteractive" dpkg-reconfigure openssh-server
COPY .devops/docker/app/ssh/sshd_config /etc/ssh/sshd_config
RUN service ssh start

# Blackfire
RUN version=$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;") \
    && curl -A "Docker" -o /tmp/blackfire-probe.tar.gz -D - -L -s https://blackfire.io/api/v1/releases/probe/php/linux/amd64/$version \
    && tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp \
    && mv /tmp/blackfire-*.so $(php -r "echo ini_get('extension_dir');")/blackfire.so \
    && echo "extension=blackfire.so\nblackfire.agent_socket=tcp://blackfire:8707" > $PHP_INI_DIR/conf.d/blackfire.ini

RUN docker-php-ext-install -j$(nproc) iconv mcrypt \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd zip

# Opcache, PDO_mysql
RUN docker-php-ext-install \
  opcache \
  pdo_mysql

# Redis
RUN pecl install -o -f redis \
    &&  rm -rf /tmp/pear \
    &&  docker-php-ext-enable redis

# Composer
RUN php -r "readfile('https://getcomposer.org/installer');" | php -- --install-dir=/usr/local/bin --filename=composer

# Configures services
RUN cp /etc/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf.bak
COPY .devops/docker/app/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf
RUN echo 'sendmail_path=/usr/sbin/ssmtp -t' > /usr/local/etc/php/conf.d/sendmail.ini

# Cleanup
RUN apt-get autoremove -y && apt-get clean all

# Creates a deploy user
RUN useradd --create-home -g www-data --shell /bin/bash deploy && echo 'deploy:docker' | chpasswd
RUN echo "deploy ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Direct ssh access to container.
COPY .devops/docker/app/ssh/authorized_keys /home/deploy/.ssh/authorized_keys
RUN chown deploy:www-data /home/deploy/.ssh/authorized_keys
RUN chmod 600  /home/deploy/.ssh/authorized_keys

# Start script for ssh & php-fpm
COPY .devops/docker/start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 22 9000
CMD ["/start.sh"]

USER deploy

RUN echo 'export PATH="$PATH:$HOME/.composer/vendor/bin"' >> ~/.bashrc
RUN echo 'cd /var/www/web' >> ~/.bashrc