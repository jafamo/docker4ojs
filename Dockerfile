FROM php:5.6-apache
LABEL maintainer="Marc Bria Ramírez <marc.bria@uab.cat>"

FROM php:5.6-apache

MAINTAINER Rondineli Saad <rondineli.saad@scielo.org>

RUN a2enmod rewrite expires

# install the PHP extensions we need
RUN apt-get -qqy update \
    && apt-get install -qqy libpng12-dev \
                            libjpeg-dev \
                            libmcrypt-dev \
                            libxml2-dev \
                            libxslt-dev \
			    cron \
			    logrotate \
    && apt-get install zlib1g-dev libxml2-dev -y \
    && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr \
    && docker-php-ext-install gd \
                              mysqli \
                              mysql \
                              opcache \
			      mcrypt \
			      soap \
			      xsl \
			      zip

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=60'; \
		echo 'opcache.fast_shutdown=1'; \
		echo 'opcache.enable_cli=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

# enable mod_rewrite
RUN a2enmod rewrite

WORKDIR /var/www/html

# Branch to be pulled. It can be overridden/set in the call or the compose file
ENV OJS_VERSION ojs-stable-3_0_2

# Cloning and Cleaning OJS and PKP-LIB git repositories
RUN apt-get install git -y \
    && git config --global url.https://.insteadOf git:// \
    && rm -fr /var/www/html/*

# RUN git clone -v --recursive --progress -b ${OJS_BRANCH} https://github.com/pkp/ojs.git /var/www/html
# RUN git clone -v --recursive --progress -b ojs-stable_3_0_2 https://github.com/pkp/ojs.git /var/www/html

RUN echo OJS_BRANCH is: ${OJS_BRANCH}
RUN git clone -v --recursive --progress https://github.com/pkp/ojs.git /var/www/html
RUN git checkout -b ojs-stable-3_0_2 origin/ojs-stable-3_0_2
#	&& chown -R www-data:www-data /var/www/ojs

RUN cd /var/www/html/lib/pkp \
    && curl -sS https://getcomposer.org/installer | php \
    && php composer.phar update \
    && cd /var/www/html \
#    && find . | grep .git | xargs rm -rf \
#    && apt-get remove git -y \
#    && apt-get autoremove -y \
#    && apt-get clean -y

# creating a directory to save uploaded files.
RUN mkdir /var/www/files \
    && chown -R www-data:www-data /var/www/files

# environment to set database params 
ENV OJS_DB_HOST localhost
ENV OJS_DB_USER ojs
ENV OJS_DB_PASSWORD ojs
ENV OJS_DB_NAME ojs

# Site servername
ENV SERVERNAME ${OJS_VERSION}.localhost
ENV APACHE_LOG_DIR /var/log/apache2
ENV LOG_NAME ${OJS_VERSION}.log

# Add crontab running runSheduledTasks.php
COPY ojs-crontab.conf /ojs-crontab.conf
RUN sed -i 's:INSTALL_DIR:'`pwd`':' /ojs-crontab.conf \
    && sed -i 's:FILES_DIR:/var/www/ojs/files:' /ojs-crontab.conf \
    && echo "$(cat /ojs-crontab.conf)" \
    # Use the crontab file
    && crontab /ojs-crontab.conf \
    && touch /var/log/cron.log

COPY 000-default.conf /etc/apache2/sites-enabled/000-default.conf

EXPOSE 80
# Add startup script to the container.
COPY ojs-startup.sh /ojs-startup.sh
# Execute the containers startu4p script which will start many processes/services
CMD ["/bin/bash", "/ojs-startup.sh"]


# Configuring OJS
# RUN cp config.TEMPLATE.inc.php config.inc.php \
#     && chmod ug+rw config.inc.php \
#     && mkdir -p /var/www/files/ \
#     && chown -R www-data:www-data /var/www/ 

# Dev stuff
RUN apt-get install nano net-tools
