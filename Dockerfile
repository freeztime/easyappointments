FROM alpine:latest

ADD https://dl.bintray.com/php-alpine/key/php-alpine.rsa.pub /etc/apk/keys/php-alpine.rsa.pub

# make sure you can use HTTPS
RUN apk --update add ca-certificates

RUN echo "https://dl.bintray.com/php-alpine/v3.11/php-7.3" >> /etc/apk/repositories

# Install packages
RUN apk --no-cache add php php-common php-fpm php-json php-zip php-gd php-mysqli php-opcache php-openssl php-curl \
    nginx supervisor curl

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# Install NPM
RUN apk add --update nodejs npm
RUN apk add --update npm

# https://github.com/codecasts/php-alpine/issues/21
# RUN ln -s /usr/bin/php7 /usr/bin/php

# Configure nginx
COPY webconf/nginx.conf /etc/nginx/nginx.conf

# Remove default server definition
RUN rm /etc/nginx/conf.d/default.conf

# Configure PHP-FPM
COPY webconf/fpm-pool.conf /etc/php7/php-fpm.d/www.conf
COPY webconf/php.ini /etc/php7/conf.d/custom.ini

# Configure supervisord
COPY webconf/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN npm install && composer install

# Setup document root
RUN mkdir -p /var/www/html

# Make sure files/folders needed by the processes are accessable when they run under the nobody user
RUN chown -R nobody.nobody /var/www/html && \
  chown -R nobody.nobody /run && \
  chown -R nobody.nobody /var/lib/nginx && \
  chown -R nobody.nobody /var/log/nginx

# Switch to use a non-root user from here on
USER nobody

# Add application
WORKDIR /var/www/html
COPY --chown=nobody . /var/www/html/

# Expose the port nginx is reachable on
EXPOSE 8080

# Let supervisord start nginx & php-fpm
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping
