FROM ubuntu:18.04 as buildbookstack

ARG BUILD_DATE
ARG BUILD_VER
ARG VENDOR
ARG MAINTAINER
ARG UPSTREAM_VER
ARG UPSTREAM_BRANCH="master"

LABEL build_version="version:- ${BUILD_VER}/${UPSTREAM_VER} Build-date:- ${BUILD_DATE}"
LABEL maintainer="${MAINTAINER}@${VENDOR}"

ENV DEBIAN_FRONTEND="noninteractive"

RUN apt update && apt install -y curl tar && \
 curl -o /tmp/bookstack.tar.gz -L "https://github.com/BookStackApp/BookStack/archive/refs/tags/${UPSTREAM_VER}.tar.gz" && \
 mkdir -p /bookstack && \
 tar xvf /tmp/bookstack.tar.gz -C /bookstack --strip-components=1 && \
 rm /tmp/bookstack.tar.gz

FROM php:7.4-apache-buster as final
RUN apt-get update && apt-get install -y --no-install-recommends git zlib1g-dev libfreetype6-dev libjpeg62-turbo-dev libmcrypt-dev libpng-dev libldap2-dev libtidy-dev libxml2-dev fontconfig fonts-freefont-ttf wkhtmltopdf tar curl libzip-dev unzip && \
 docker-php-ext-install -j$(nproc) dom pdo pdo_mysql zip tidy && \
 docker-php-ext-configure ldap && \
 docker-php-ext-install -j$(nproc) ldap && \
 docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ && \
 docker-php-ext-install -j$(nproc) gd && \
 a2enmod rewrite remoteip; \
 { \
 echo RemoteIPHeader X-Real-IP ; \
 echo RemoteIPTrustedProxy 10.0.0.0/8 ; \
 echo RemoteIPTrustedProxy 172.16.0.0/12 ; \
 echo RemoteIPTrustedProxy 192.168.0.0/16 ; \
 } > /etc/apache2/conf-available/remoteip.conf; \
 a2enconf remoteip && \
 sed -i "s/Listen 80/Listen 8080/" /etc/apache2/ports.conf; \
 sed -i "s/VirtualHost *:80/VirtualHost *:8080/" /etc/apache2/sites-available/*.conf

COPY bookstack.conf /etc/apache2/sites-available/000-default.conf

COPY --from=buildbookstack --chown=33:33 /bookstack/ /var/www/bookstack/

ARG COMPOSER_VERSION=1.10.16
RUN cd /var/www/bookstack && \
 curl -sS https://getcomposer.org/installer | php -- --version=$COMPOSER_VERSION && \
 /var/www/bookstack/composer.phar global -v require hirak/prestissimo && \
 /var/www/bookstack/composer.phar install -v -d /var/www/bookstack/ && \
 /var/www/bookstack/composer.phar global -v remove hirak/prestissimo && \
 rm -rf /var/www/bookstack/composer.phar /root/.composer && \
 chown -R www-data:www-data /var/www/bookstack

COPY php.ini /usr/local/etc/php/php.ini
COPY docker-entrypoint.sh /bin/docker-entrypoint.sh

WORKDIR /var/www/bookstack

# www-data
USER 33

VOLUME ["/var/www/bookstack/public/uploads","/var/www/bookstack/storage/uploads"]

ENV RUN_APACHE_USER=www-data \
    RUN_APACHE_GROUP=www-data

EXPOSE 8080

ENTRYPOINT ["/bin/docker-entrypoint.sh"]

LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.docker.dockerfile="/Dockerfile" \
      org.label-schema.license="MIT" \
      org.label-schema.name="bookstack" \
      org.label-schema.vendor="$VENDOR" \
      org.label-schema.url="https://github.com/$VENDOR/bookstack/" \
      org.label-schema.vcs-ref=$UPSTREAM_BRANCH \
      org.label-schema.vcs-url="https://github.com/$VENDOR/bookstack.git" \
      org.label-schema.vcs-type="Git"
