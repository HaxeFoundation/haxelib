# Build haxelib server as a Docker container.
# Note that it doesn't contain a MySQL database, 
# which need to be launched seperately. See test/docker-compose.yml on how to launch one.

FROM andyli/tora

# apt-get dependencies of bower
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
		npm \
		nodejs-legacy \
		git \
	&& rm -r /var/lib/apt/lists/*

RUN npm -g install bower

COPY server*.hxml /src/

WORKDIR /src

RUN haxelib setup /haxelib
RUN haxelib install all --always

COPY www /src/www/
COPY src /src/src/

RUN rm -rf /var/www/html
RUN ln -s /src/www /var/www/html

WORKDIR /src/www

RUN bower install --allow-root

WORKDIR /src

RUN haxe server.hxml