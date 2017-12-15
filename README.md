# Testing with PHPUnit

I was trying to finally setup some unit testing for Zip Recipes because I don’t like this feeling of insecurity.

I started following the instruction in wp-cli: [Plugin Unit Tests – WP-CLI — WordPress](https://make.wordpress.org/cli/handbook/plugin-unit-tests/#running-tests-locally)

Since I’m using docker for development, it made sense I do something similar for testing since I have dev database in a docker container, server in another one and it’s quite nice. I can even debugging from host machine and it’s peachy (though it took effort to set up).

First command I was supposed to run was:

```bash
wp scaffold plugin-tests my-plugin
```

So, for me that simply became:
```bash
wp scaffold plugin-tests zip-recipes
```

However, to get here, I needed to install wp-cli.

I created a `Dockerfile` and started off:

```
FROM php:7-alpine
LABEL Author="Gezim Hoxha <my email>"
```

The reason I chose php:7-alpine is that I wanted latest 7.x version using alpine linux which turns out it’s a lightweight and docker friendly distro with minimal packages.

So, to download wp-cli, I added a RUN command:

`RUN curl -LO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar`

The `O` in the `-LO` options specifies to curl that file should be save locally with same name as it has remotely (in this case `wp-cli.phar`) and `L` option, I learned the hard way, is needed to tell curl to follow a possible redirect if the server you’re requesting the file from says the file has moved (301 or other moved statuses).

Then I created a VOLUME where I wanted to mount my external `wordpress` dir:

```
VOLUME [ "/data" ]
```

Finally, I could run the scaffold command:

`CMD php wp-cli.phar scaffold plugin-tests zip-recipes --allow-root --path='/data/wordpress'`

Then, I thought I was done, except for this little error:

```
Deprecated: __autoload() is deprecated, use spl_autoload_register() instead in /data/wordpress/wp-includes/compat.php on line 502
Fatal error: Uncaught Error: Call to undefined function mysql_connect() in /data/wordpress/wp-includes/wp-db.php:1578
Stack trace:
#0 /data/wordpress/wp-includes/wp-db.php(658): wpdb->db_connect()
#1 /data/wordpress/wp-includes/load.php(404): wpdb->__construct('root', 'root', 'wordpress', 'db')
#2 /data/wordpress/wp-settings.php(106): require_wp_db()
#3 phar:///wp-cli.phar/php/WP_CLI/Runner.php(1105): require('/data/wordpress...')
#4 phar:///wp-cli.phar/php/WP_CLI/Runner.php(1032): WP_CLI\Runner->load_wordpress()
#5 phar:///wp-cli.phar/php/WP_CLI/Bootstrap/LaunchRunner.php(23): WP_CLI\Runner->start()
#6 phar:///wp-cli.phar/php/bootstrap.php(75): WP_CLI\Bootstrap\LaunchRunner->process(Object(WP_CLI\Bootstrap\BootstrapState))
#7 phar:///wp-cli.phar/php/wp-cli.php(23): WP_CLI\bootstrap()
#8 phar:///wp-cli.phar/php/boot-phar.php(8): include('phar:///wp-cli....')
#9 /wp-cli.phar(4): include('phar:///wp-cli....')
#10 {main}
  thrown in /data/wordpress/wp-includes/wp-db.php on line 1578
```

So, it turns out the `mysqli` extension wasn’t installed by default. Shoot!

Reading the PHP docker image documentation, I was confused and tried to add `mysqli` through the package manager and then enabling it with `docker-php-ext-enable mysqli` and such but that didn’t seem to work. 

Eventually I figured out that all I had to do was `docker-php-ext-install mysqli` to get the `mysqli` extension which ended up looking like this:

`RUN docker-php-ext-install mysqli`

That did it!

My Dockerfile ended up looking like this:

```
FROM php:7-alpine
LABEL Author="Gezim Hoxha <my email>"

RUN docker-php-ext-install mysqli
RUN curl -LO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

VOLUME [ "/data" ]

CMD php wp-cli.phar scaffold plugin-tests zip-recipes --allow-root --path='/data/wordpress'
```

That was just the first step. Now we actually would like to run the tests:

Then the wp-cli instruction tell us to run this command:

`bin/install-wp-tests.sh wordpress_test root '' localhost latest` from the plugin dir.

Those params are explained as follows:

> wordpress_test is the name of the test database (all data will be deleted!)
> root is the MySQL user name
> '' is the MySQL user password
> localhost is the MySQL server host
> latest is the WordPress version; could also be 3.7, 3.6.2 etc.

At first, I tried to install mysql inside this container but I was just wasn’t having a good time with that. Then it occurred to me that there’s this [official MySQL docker image](https://hub.docker.com/_/mysql/) that’s brilliant.

So, I decided to create a MySQL container real simply:

`docker run --name test-mysql --network='ziprecipes_default' -e MYSQL_ROOT_PASSWORD=root -d mysql:5.7`

So now I should be able to pass this to our testing container.

After much back and forth (2-3 hours worth), I got the Docker file at this point:

```
FROM php:7-alpine
LABEL Author="Gezim Hoxha <my email>"

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
```

So, finally tests actually run!

The only thing is that I have to stop and remove the mysql container every time I run the test so it doesn’t fail at creation. (I like fresh install as is).

`docker stop test-mysql && docker rm test-mysql && docker run --name test-mysql --network='ziprecipes_default' -e MYSQL_ROOT_PASSWORD=root -d mysql:5.7`


