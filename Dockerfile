FROM php:7-alpine
LABEL Author="Gezim Hoxha <hgezim@gmail.com>"

RUN apk update && apk add bash subversion mysql-client && docker-php-ext-install mysqli
RUN curl -LO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    curl -LO https://phar.phpunit.de/phpunit.phar && \
    chmod +x phpunit.phar && \
    mv phpunit.phar /usr/local/bin/phpunit 

VOLUME [ "/data" ]

# create set up test files
#CMD php wp-cli.phar scaffold plugin-tests zip-recipes --allow-root --path='/data/wordpress'

# create test site
CMD /data/wordpress/wp-content/plugins/zip-recipes/bin/install-wp-tests.sh wordpress_test root 'root' test-mysql latest && cd /data/wordpress/wp-content/plugins/zip-recipes/ && phpunit
