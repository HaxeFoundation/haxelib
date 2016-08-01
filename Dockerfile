# Build haxelib server as a Docker container.
# Note that it doesn't contain a MySQL database, 
# which need to be launched seperately. See test/docker-compose.yml on how to launch one.

FROM andyli/tora

# apt-get dependencies of bower
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
		npm \
		nodejs-legacy \
		git \
		python-pip \
		cmake \
		build-essential \
		libcurl4-gnutls-dev \
	&& rm -r /var/lib/apt/lists/*

RUN pip install awscli
RUN npm -g install bower


RUN haxelib setup /haxelib

COPY server*.hxml /src/
WORKDIR /src
RUN haxelib install all --always

RUN git clone https://github.com/andyli/aws-sdk-neko.git \
	&& git checkout 85d3c9981e14545ef1e2c3ed79eae89d08499fff \
	&& git submodule update --init
RUN haxelib dev aws-sdk-neko aws-sdk-neko
WORKDIR /src/aws-sdk-neko
RUN cmake .
RUN cmake --build . --target aws.ndll
RUN cp ndll/*/aws.ndll /usr/lib/neko/aws.ndll

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