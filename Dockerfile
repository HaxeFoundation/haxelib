# Build haxelib server as a Docker container.
# Note that it doesn't contain a MySQL database, 
# which need to be launched seperately. See test/docker-compose.yml on how to launch one.

FROM andyli/tora

COPY server*.hxml /src/

WORKDIR /src

RUN haxelib setup /haxelib
RUN haxelib install all --always

COPY www /src/www/
COPY src /src/src/
COPY src/haxelib/server/dbconfig.json.example /src/dbconfig.json
COPY src/haxelib/server/.htaccess /src/

RUN rm -rf /var/www/html
RUN ln -s /src/www /var/www/html

RUN haxe server.hxml