# Build haxelib server as a Docker container.
# Note that it doesn't contain a MySQL database, 
# which need to be launched seperately. See test/docker-compose.yml on how to launch one.

FROM ubuntu:trusty

# apt-get dependencies of bower
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y python-software-properties software-properties-common \
	&& add-apt-repository ppa:haxe/snapshots -y \
	&& apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
		apache2 \
		neko-dev \
		haxe \
		npm \
		nodejs-legacy \
		git \
		python-pip \
		cmake \
		build-essential \
		libcurl4-gnutls-dev \
	&& rm -r /var/lib/apt/lists/*


# apache httpd
RUN rm -rf /var/www/html \
	&& mkdir -p /var/lock/apache2 /var/run/apache2 /var/log/apache2 /var/www/html \
	&& chown -R www-data:www-data /var/lock/apache2 /var/run/apache2 /var/log/apache2 /var/www/html 
RUN a2enmod rewrite
RUN mv /etc/apache2/apache2.conf /etc/apache2/apache2.conf.dist && rm /etc/apache2/conf-enabled/* /etc/apache2/sites-enabled/*
COPY apache2.conf /etc/apache2/apache2.conf
RUN { \
		echo 'LoadModule neko_module /usr/lib/x86_64-linux-gnu/neko/mod_neko2.ndll'; \
		echo 'LoadModule tora_module /usr/lib/x86_64-linux-gnu/neko/mod_tora2.ndll'; \
		echo 'AddHandler tora-handler .n'; \
	} > /etc/apache2/mods-enabled/tora.conf \
	&& apachectl stop


RUN pip install awscli
RUN npm -g install bower


# haxelib
ENV HAXELIB_PATH /haxelib
RUN mkdir "$HAXELIB_PATH" && haxelib setup "$HAXELIB_PATH" \
	&& haxelib install tora 1.8.1

COPY server*.hxml /src/
WORKDIR /src
RUN haxelib install all --always

RUN git clone https://github.com/andyli/aws-sdk-neko.git \
	&& cd aws-sdk-neko \
	&& git checkout 85d3c9981e14545ef1e2c3ed79eae89d08499fff \
	&& git submodule update --init
RUN haxelib dev aws-sdk-neko aws-sdk-neko
WORKDIR /src/aws-sdk-neko
RUN cmake .
RUN cmake --build . --target aws.ndll
RUN cp ndll/*/aws.ndll /usr/lib/x86_64-linux-gnu/neko/aws.ndll

COPY www/bower.json /src/www/
WORKDIR /src/www
RUN bower install --allow-root

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
RUN haxe server.hxml

EXPOSE 80
VOLUME ["/var/www/html/files", "/var/www/html/tmp"]
CMD apachectl restart && haxelib run tora