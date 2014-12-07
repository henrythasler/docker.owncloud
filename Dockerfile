FROM img-nginx:1.0.0
MAINTAINER Henry Thasler <docker@thasler.org>

# Set correct environment variables; modify as needed
ENV ROOT /usr/share/nginx/html
ENV SERVER_NAME www.thasler.com
ENV CERT www_thasler_com.pem
ENV KEY www_thasler_com.key

# prepare for installation of additional modules
RUN apt-get update

# install additional modules
RUN apt-get install -y --no-install-recommends \
#                goaccess \
                php5-intl \
                php5-mcrypt \
                php5-imagick 

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# modify php-config to enable larger uploads (default 1GB); modify as needed
RUN sed -i 's/\(upload_max_filesize *= *\).*/\11024M/' /etc/php5/fpm/php.ini
RUN sed -i 's/\(post_max_size *= *\).*/\11024M/' /etc/php5/fpm/php.ini
        
# define the desired version
ENV OWNCLOUD_VERSION owncloud-7.0.3

# path to download location
ENV OWNCLOUD_SOURCE https://download.owncloud.org/community/

# Optimize nginx settings for better performance
ADD optimizations.conf /etc/nginx/conf.d/optimizations.conf
RUN sed -i "s#worker_processes 4;#worker_processes 8;#" /etc/nginx/nginx.conf

# Setup nginx config for owncloud; replace ENV-values in files with given values (see above) 
ADD owncloud.conf /etc/nginx/sites-enabled/owncloud.conf
RUN rm /etc/nginx/sites-enabled/default
RUN sed -i "s#SERVER_NAME#$SERVER_NAME#" /etc/nginx/sites-enabled/owncloud.conf
RUN sed -i "s#ROOT#$ROOT#" /etc/nginx/sites-enabled/owncloud.conf
RUN sed -i "s#CERT#$CERT#" /etc/nginx/sites-enabled/owncloud.conf
RUN sed -i "s#KEY#$KEY#" /etc/nginx/sites-enabled/owncloud.conf
           
# download owncloud files incl. signatures and key
RUN cd $ROOT \
        && wget $OWNCLOUD_SOURCE$OWNCLOUD_VERSION.tar.bz2 \
        && wget $OWNCLOUD_SOURCE$OWNCLOUD_VERSION.tar.bz2.asc \
        && wget https://owncloud.org/owncloud.asc

# verify and extract owncloud archive file        
RUN cd $ROOT \
        && gpg --import owncloud.asc \
        && gpg --verify $OWNCLOUD_VERSION.tar.bz2.asc \
        && tar -xjf $OWNCLOUD_VERSION.tar.bz2
        
# add and modify autoconfig
ADD autoconfig.php $ROOT/owncloud/config/autoconfig.php
RUN sed -i "s#ROOT#$ROOT#" $ROOT/owncloud/config/autoconfig.php

# setup access restrictions
RUN  cd $ROOT \
        && chown -R root:root owncloud \
        && chmod -R 755 owncloud \
        && chown -R www-data:www-data owncloud/config \
        && chmod 750 owncloud/config \
        && chown www-data:www-data owncloud/apps \
        && chmod 750 owncloud/apps \
        && mkdir data \
        && chown www-data:www-data data \
        && chmod 750 data
        
# setup cronjob for owncloud; make sure to change the setting in owncloud to cron
RUN ( crontab -l 2>/dev/null | grep -Fv owncloud ; printf -- "*/15  *  *  *  * php -f $ROOT/owncloud/cron.php\n" ) | crontab

# config file for goaccess
#ADD goaccess.conf $ROOT/goaccess.conf

# setup cronjob for goaccess
#RUN ( crontab -l 2>/dev/null | grep -Fv owncloud ; printf -- "*/15  *  *  *  * php -f $ROOT/owncloud/cron.php\n" ) | crontab

EXPOSE 443