# Build haxelib server as a Docker container.
# Note that it doesn't contain a MySQL database, 
# which need to be launched seperately. See test/docker-compose.yml on how to launch one.

FROM ubuntu:bionic

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common \
	&& add-apt-repository ppa:haxe/releases -y \
	&& apt-get update && apt-get upgrade -y \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -y \
		apache2 \
		neko-dev \
		haxe \
		curl \
		git \
		libcurl4-gnutls-dev \
	&& curl -sL https://deb.nodesource.com/setup_8.x | bash - \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -y \
		nodejs \
	&& rm -r /var/lib/apt/lists/*


# apache httpd
RUN rm -rf /var/www/html \
	&& mkdir -p /var/lock/apache2 /var/run/apache2 /var/log/apache2 /var/www/html \
	&& chown -R www-data:www-data /var/lock/apache2 /var/run/apache2 /var/log/apache2 /var/www/html 
RUN a2enmod rewrite
RUN a2enmod proxy
RUN a2enmod proxy_http
RUN a2dismod mpm_event
RUN a2enmod mpm_prefork
RUN mv /etc/apache2/apache2.conf /etc/apache2/apache2.conf.dist && rm /etc/apache2/conf-enabled/* /etc/apache2/sites-enabled/*
COPY apache2.conf /etc/apache2/apache2.conf
RUN { \
		echo 'LoadModule neko_module /usr/lib/x86_64-linux-gnu/neko/mod_neko2.ndll'; \
		echo 'LoadModule tora_module /usr/lib/x86_64-linux-gnu/neko/mod_tora2.ndll'; \
		echo 'AddHandler tora-handler .n'; \
	} > /etc/apache2/mods-enabled/tora.conf \
	&& apachectl stop


# haxelib
ENV HAXELIB_PATH /src/.haxelib
RUN mkdir /haxelib && haxelib setup /haxelib
WORKDIR /src
COPY .haxelib /src/.haxelib
RUN cp ${HAXELIB_PATH}/aws-sdk-neko/*/ndll/Linux64/aws.ndll /usr/lib/x86_64-linux-gnu/neko/aws.ndll;
COPY server*.hxml /src/

COPY www/package*.json /src/www/
WORKDIR /src/www/
RUN npm install --unsafe-perm

COPY www /src/www/
COPY src/legacyhaxelib/.htaccess /src/www/legacy/
COPY src/legacyhaxelib/haxelib.css /src/www/legacy/
COPY src/legacyhaxelib/website.mtt /src/www/legacy/
COPY src /src/src/

RUN rm -rf /var/www/html
RUN ln -s /src/www /var/www/html
RUN mkdir -p /var/www/html/files
RUN mkdir -p /var/www/html/tmp

WORKDIR /src

RUN haxe server_legacy.hxml
RUN haxe server_website.hxml
RUN haxe server_tasks.hxml
RUN haxe server_api.hxml

EXPOSE 80
VOLUME ["/var/www/html/files", "/var/www/html/tmp"]
CMD apachectl restart && haxelib run tora