
# Official daloRADIUS Dockerfile
# GitHub: https://github.com/lirantal/daloradius
#
# Build image:
# docker build . -t lirantal/daloradius
#
# Run container:
# docker run -p 80:80 -p 8000:8000 -d lirantal/daloradius

FROM debian:13-slim

LABEL maintainer="Liran Tal <liran.tal@gmail.com>"
LABEL Description="daloRADIUS Official Docker based on Debian 13 and PHP 8.4." \
    License="GPLv2" \
    Usage="docker build . -t lirantal/daloradius && docker run -d -p 80:80 -p 8000:8000 lirantal/daloradius" \
    Version="2.3"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Jakarta

# PHP and Apache installation
RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        freeradius-utils \
        tzdata \
        apache2 \
        libapache2-mod-php \
        cron \
        net-tools \
        php \
        php-common \
        php-gd \
        php-cli \
        php-curl \
        php-ldap \
        php-mail \
        php-mail-mime \
        php-net-smtp \
        php-mbstring \
        php-mysql \
        mariadb-client \
    && php -r 'exit(class_exists("PDO") && in_array("mysql", PDO::getAvailableDrivers(), true) ? 0 : 1);' \
    && rm -rf /var/lib/apt/lists/*

# Apache virtual hosts
COPY contrib/docker/operators.conf /etc/apache2/sites-available/operators.conf
COPY contrib/docker/users.conf /etc/apache2/sites-available/users.conf

RUN a2dissite 000-default.conf \
    && a2ensite users.conf operators.conf \
    && sed -i 's/Listen 80/Listen 80\nListen 8000/' /etc/apache2/ports.conf

# Create persistent data directory
RUN mkdir -p /data

# Copy daloRADIUS source
COPY . /var/www/daloradius

# Replace static symlinks with normal directories
RUN mkdir -p \
        /var/www/daloradius/app/operators/static \
        /var/www/daloradius/app/users/static \
    && cp -a /var/www/daloradius/app/common/static/. \
        /var/www/daloradius/app/operators/static/ \
    && cp -a /var/www/daloradius/app/common/static/. \
        /var/www/daloradius/app/users/static/ \
    && sed -i 's/\r$//' /var/www/daloradius/init.sh

# Set ownership
RUN chown -R www-data:www-data /var/www/daloradius

# Remove original Apache sample web folder
RUN rm -rf /var/www/html

# Create daloRADIUS log directory
RUN mkdir -p /var/www/daloradius/var/log \
    && touch /var/www/daloradius/var/log/daloradius.log \
    && chown -R www-data:www-data /var/www/daloradius/var

# Apache logs
RUN mkdir -p /var/log/apache2/daloradius \
    && chown -R www-data:www-data /var/log/apache2/daloradius

# Allow Apache/PHP to read FreeRADIUS logs
RUN usermod -a -G freerad www-data \
    && printf '%s\n' \
        "System logs are not available inside this container. Use docker logs radius-web." \
        > /var/log/syslog \
    && printf '%s\n' \
        "Boot logs are not available inside this container. Use docker logs radius-web." \
        > /var/log/boot.log \
    && chmod 0644 /var/log/syslog /var/log/boot.log

# Apache mutex
RUN echo "Mutex posixsem" >> /etc/apache2/apache2.conf

# Expose dashboard ports
EXPOSE 80
EXPOSE 8000

# Start daloRADIUS
CMD ["/bin/bash", "/var/www/daloradius/init.sh"]
