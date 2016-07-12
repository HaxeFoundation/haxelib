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
	&& rm -r /var/lib/apt/lists/*

RUN pip install awscli
RUN npm -g install bower

COPY server*.hxml /src/

WORKDIR /src

RUN haxelib setup /haxelib
RUN haxelib install all --always

COPY www/bower.json /src/www/
WORKDIR /src/www
RUN bower install --allow-root

COPY www /src/www/
COPY src /src/src/

RUN rm -rf /var/www/html
RUN ln -s /src/www /var/www/html

WORKDIR /src

RUN haxe server.hxml

EXPOSE 80