FROM img-nginx:1.0.0
MAINTAINER Henry Thasler <docker@thasler.org>

# Set correct environment variables.
ENV HTML /usr/share/nginx/html
ENV SERVER_NAME www.thasler.com

# modify php-config
RUN sed -i 's/\(upload_max_filesize *= *\).*/\11024/' /etc/php5/fpm/php.ini
RUN sed -i 's/\(post_max_size *= *\).*/\11024M/' /etc/php5/fpm/php.ini
        
# define the desired versions
ENV OWNCLOUD_VERSION owncloud-7.0.3

# path to download location
ENV OWNCLOUD_SOURCE https://download.owncloud.org/community/

# Setup nginx config for owncloud
ADD owncloud.conf /etc/nginx/sites-enabled/owncloud
RUN sed -i "s#SERVER_NAME#$SERVER_NAME#" /etc/nginx/sites-enabled/owncloud && rm /etc/nginx/sites-enabled/default
           
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
        
# setup security and access restrictions
RUN  cd $HTML \
        && chown -R root:root owncloud \
        && chmod -R 755 owncloud \
        && chown -R www-data:www-data owncloud/config \
        && chmod 750 owncloud/config \
        && chown www-data:www-data owncloud/apps \
        && chmod 750 owncloud/apps \
        && mkdir data \
        && chown www-data:www-data data \
        && chmod 750 data
        
# setup cronjob for owncloud
RUN ( crontab -l 2>/dev/null | grep -Fv owncloud ; printf -- "*/15  *  *  *  * php -f $HTML/owncloud/cron.php\n" ) | crontab

# webserver root directory
WORKDIR /usr/share/nginx/html

EXPOSE 443