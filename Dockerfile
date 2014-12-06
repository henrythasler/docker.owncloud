FROM phusion/baseimage:0.9.15
MAINTAINER Henry Thasler <docker@thasler.org>

# Set correct environment variables.
ENV HOME /root
ENV HTML /usr/share/nginx/html

# Regenerate SSH host keys. baseimage-docker does not contain any, so you
# have to do that yourself. You may also comment out this instruction; the
# init system will auto-generate one during boot
RUN /etc/my_init.d/00_regen_ssh_host_keys.sh

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# prepare for install
RUN apt-get update

# install distro updates
RUN apt-get upgrade -y

# install dependencies
RUN apt-get install -y --no-install-recommends \
                curl \
                wget \
                build-essential \
                zlib1g-dev

# prepare nginx+php-fpm environment
RUN apt-get install -y --no-install-recommends \
                nginx \
                sqlite3 \
                php5-sqlite \
                php5-fpm \
                php5-curl \
                php5-gd \
                php5-cli \
                php5-mcrypt \
                php5-mysql \
                php5-json \
                php5-intl \
                php5-imagick \
                php-apc \
                && apt-get remove -y nginx

# start fpm-module on startup
RUN     { \
        echo '#!/bin/sh -e'; \
        echo 'php5-fpm'; \
        echo 'exit 0'; \
        } > /etc/rc.local

#RUN mkdir /etc/service/php5-fpm
#ADD php5-fpm.sh /etc/service/php5-fpm/run


# modify php-config
RUN sed -i 's/\(expose_php *= *\).*/\1Off/' /etc/php5/fpm/php.ini
RUN sed -i 's/\(upload_max_filesize *= *\).*/\11024/' /etc/php5/fpm/php.ini
RUN sed -i 's/\(post_max_size *= *\).*/\11024M/' /etc/php5/fpm/php.ini

# setup php test page
#RUN    { \
#       echo '<?php phpinfo(); ?>'; \
#       } > /usr/share/nginx/html/info.php
        
# define the desired versions
ENV NGINX_VERSION nginx-1.7.8
ENV OPENSSL_VERSION openssl-1.0.1j
ENV PCRE_VERSION pcre-8.36
ENV OWNCLOUD_VERSION owncloud-7.0.3

# path to download location
ENV NGINX_SOURCE http://nginx.org/download/
ENV OPENSSL_SOURCE https://www.openssl.org/source/
ENV PCRE_SOURCE ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/
ENV OWNCLOUD_SOURCE https://download.owncloud.org/community/

# build path
ENV BPATH /usr/src

# refer to http://nginx.org/en/pgp_keys.html
RUN gpg --keyserver keys.gnupg.net --recv-key \
    F5806B4D \
    A524C53E \
    A1C052F8 \
    2C172083 \
    7ADB39A8 \
    6C7E5E82 \
    7BD9BF62
    
# refer to https://www.openssl.org/about/
RUN gpg --keyserver keys.gnupg.net --recv-key \
    49A563D9 \
    FA40E9E2 \
    2118CF83 \
    1FE8E023 \
    0E604491 \
    49A563D9 \
    FA40E9E2 \
    41FBF7DD \
    9C58A66D \
    2118CF83 \
    CE69424E \
    5A6A9B85 \
    1FE8E023 \
    41C25E5D \
    5C51B27C \
    E18C1C32
    
# Philip Hazel's public GPG key. 
RUN gpg --keyserver keys.gnupg.net --recv-key FB0F43D8
   
# download source packages and signatures
RUN cd $BPATH \
        && wget $PCRE_SOURCE$PCRE_VERSION.tar.gz \
        && wget $PCRE_SOURCE$PCRE_VERSION.tar.gz.sig \
        && wget $OPENSSL_SOURCE$OPENSSL_VERSION.tar.gz \
        && wget $OPENSSL_SOURCE$OPENSSL_VERSION.tar.gz.asc \
        && wget $NGINX_SOURCE$NGINX_VERSION.tar.gz \
        && wget $NGINX_SOURCE$NGINX_VERSION.tar.gz.asc

# verify and and extract
RUN cd $BPATH \
        && gpg --verify $PCRE_VERSION.tar.gz.sig \
        && gpg --verify $OPENSSL_VERSION.tar.gz.asc \
        && gpg --verify $NGINX_VERSION.tar.gz.asc \
        && tar xzf $PCRE_VERSION.tar.gz \
        && tar xzf $OPENSSL_VERSION.tar.gz \
        && tar xzf $NGINX_VERSION.tar.gz

# build and install nginx
RUN cd $BPATH/$NGINX_VERSION && ./configure \
        --sbin-path=/usr/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --pid-path=/var/run/nginx.pid \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --with-openssl=$BPATH/$OPENSSL_VERSION \
        --with-pcre=$BPATH/$PCRE_VERSION \
        --with-http_ssl_module \
        --with-http_spdy_module \
        --with-file-aio \
        --with-ipv6 \
        --with-http_gzip_static_module \
        --with-http_stub_status_module \
        --without-mail_pop3_module \
        --without-mail_smtp_module \
        --without-mail_imap_module \
        && make && make install
        
# Setup nginx config for owncloud
ADD owncloud-main.conf /etc/nginx/main.d/owncloud-main.conf
ADD owncloud.conf /etc/nginx/sites-enabled/owncloud.conf
           
# Exclude nginx from future updates. Clean up APT when done.
RUN apt-mark hold nginx nginx-core nginx-common && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# download owncloud files
RUN cd $HTML \
        && wget $OWNCLOUD_SOURCE$OWNCLOUD_VERSION.tar.bz2 \
        && wget $OWNCLOUD_SOURCE$OWNCLOUD_VERSION.tar.bz2.asc \
        && wget https://owncloud.org/owncloud.asc

# verify owncloud archive file        
RUN cd $HTML \
        && gpg --import owncloud.asc \
        && gpg --verify $OWNCLOUD_VERSION.tar.bz2.asc \
        && tar -xjf $OWNCLOUD_VERSION.tar.bz2
        
# webserver root directory
WORKDIR /usr/share/nginx/html

EXPOSE 443