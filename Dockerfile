FROM img-nginx:1.1.0
MAINTAINER Henry Thasler <docker@thasler.org>

# Set correct environment variables; modify as needed
ENV ROOT /usr/share/nginx/html
ENV BPATH /usr/src
ENV SERVER_NAME www.thasler.com
ENV CERT www_thasler_com.pem
ENV KEY www_thasler_com.key

# define the desired versions
ENV OWNCLOUD_VERSION owncloud-7.0.3
ENV GOACCESS_VERSION goaccess-0.8.5

# path to download locations
ENV OWNCLOUD_SOURCE https://download.owncloud.org/community/
ENV GOACCESS_SOURCE http://tar.goaccess.io/

# prepare for installation of additional modules
RUN apt-get update

# install additional modules
RUN apt-get install -y --no-install-recommends \
                php5-intl \
                php5-mcrypt \
                php5-imagick 

# install additional modules for goaccess
RUN apt-get install -y --no-install-recommends \
                libgeoip-dev \
                libncursesw5-dev \
                libglib2.0-dev
                
# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# modify php-config to enable larger uploads (default 1GB); modify as needed
RUN sed -i 's/\(upload_max_filesize *= *\).*/\11024M/' /etc/php5/fpm/php.ini
RUN sed -i 's/\(post_max_size *= *\).*/\11024M/' /etc/php5/fpm/php.ini

# disable output_buffering according to http://doc.owncloud.org/server/7.0/admin_manual/configuration/big_file_upload_configuration.html
RUN sed -i 's/\(output_buffering *= *\).*/\10/' /etc/php5/fpm/php.ini

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

# install goaccess
RUN cd $BPATH \
        && wget $GOACCESS_SOURCE$GOACCESS_VERSION.tar.gz \
        && tar -xzvf $GOACCESS_VERSION.tar.gz \
        && cd $GOACCESS_VERSION \
        && ./configure --enable-geoip --enable-utf8 \
        && make && make install

# install GeoIp database
RUN cd $ROOT \
        && wget http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz \
        && gzip -dv GeoLiteCity.dat.gz
        
# add config file for goaccess cron job and set path to GeoIP-DB
ADD goaccess.conf $ROOT/goaccess.conf
RUN sed -i "s#ROOT#$ROOT#" $ROOT/goaccess.conf

# setup cronjob for goaccess
RUN ( crontab -l 2>/dev/null | grep -Fv goaccess ; printf -- "0  0  *  *  * /usr/local/bin/goaccess -p $ROOT/goaccess.conf -f /var/log/nginx/access.log > $ROOT/owncloud/log.html\n" ) | crontab

EXPOSE 443