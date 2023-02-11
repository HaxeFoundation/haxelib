VERSION 0.6
ARG UBUNTU_RELEASE=bionic
FROM mcr.microsoft.com/vscode/devcontainers/base:0-$UBUNTU_RELEASE
ARG DEVCONTAINER_IMAGE_NAME_DEFAULT=haxe/haxelib_devcontainer_workspace
ARG HAXELIB_SERVER_IMAGE_NAME_DEFAULT=haxe/lib.haxe.org

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

ARG --required TARGETARCH

devcontainer-library-scripts:
    RUN curl -fsSLO https://raw.githubusercontent.com/microsoft/vscode-dev-containers/main/script-library/common-debian.sh
    RUN curl -fsSLO https://raw.githubusercontent.com/microsoft/vscode-dev-containers/main/script-library/docker-debian.sh
    SAVE ARTIFACT --keep-ts *.sh AS LOCAL .devcontainer/library-scripts/

# https://github.com/docker-library/mysql/blob/master/5.7/Dockerfile.debian
mysql-public-key:
    ARG KEY=859BE8D7C586F538430B19C2467B942D3A79BD29
    RUN gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$KEY"
    RUN gpg --batch --armor --export "$KEY" > mysql-public-key
    SAVE ARTIFACT mysql-public-key AS LOCAL .devcontainer/mysql-public-key

neko-latest:
    ARG FILENAME=neko_2022-07-19_master_81c4dce.tar.gz
    RUN haxeArch=$(case "$TARGETARCH" in \
        amd64) echo "linux64";; \
        arm64) echo "linux-arm64";; \
    esac); curl -fsSLO "https://build.haxe.org/builds/neko/$haxeArch/$FILENAME"
    RUN mkdir -p neko
    RUN tar --strip-components=1 -xf "$FILENAME" -C neko
    SAVE ARTIFACT neko/*

INSTALL_NEKO:
    COMMAND
    ARG NEKOPATH=/neko
    COPY +neko-latest/* "$NEKOPATH/"
    ARG PREFIX=/usr/local
    RUN bash -c "ln -s \"$NEKOPATH\"/{neko,nekoc,nekoml,nekotools} \"$PREFIX/bin/\""
    RUN bash -c "ln -s \"$NEKOPATH\"/libneko.* \"$PREFIX/lib/\""
    RUN bash -c "ln -s \"$NEKOPATH\"/neko.h \"$PREFIX/include/\""
    RUN mkdir -p "$PREFIX/lib/neko/"
    RUN bash -c "ln -s \"$NEKOPATH\"/*.ndll \"$PREFIX/lib/neko/\""
    RUN ldconfig

haxe-latest:
    ARG FILENAME=haxe_2022-08-09_development_779b005.tar.gz
    RUN haxeArch=$(case "$TARGETARCH" in \
        amd64) echo "linux64";; \
        arm64) echo "linux-arm64";; \
    esac); curl -fsSLO "https://build.haxe.org/builds/haxe/$haxeArch/$FILENAME"
    RUN mkdir -p haxe
    RUN tar --strip-components=1 -xf "$FILENAME" -C haxe
    SAVE ARTIFACT haxe/*

devcontainer-base:
    # Avoid warnings by switching to noninteractive
    ENV DEBIAN_FRONTEND=noninteractive

    ARG INSTALL_ZSH="false"
    ARG UPGRADE_PACKAGES="true"
    ARG ENABLE_NONROOT_DOCKER="true"
    ARG USE_MOBY="false"
    COPY .devcontainer/library-scripts/common-debian.sh .devcontainer/library-scripts/docker-debian.sh /tmp/library-scripts/
    RUN apt-get update \
        && /bin/bash /tmp/library-scripts/common-debian.sh "${INSTALL_ZSH}" "${USERNAME}" "${USER_UID}" "${USER_GID}" "${UPGRADE_PACKAGES}" "true" "true" \
        && /bin/bash /tmp/library-scripts/docker-debian.sh "${ENABLE_NONROOT_DOCKER}" "/var/run/docker-host.sock" "/var/run/docker.sock" "${USERNAME}" "${USE_MOBY}" \
        # Clean up
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/library-scripts/

    # see +mysql-public-key
    COPY .devcontainer/mysql-public-key /tmp/mysql-public-key
    RUN apt-key add /tmp/mysql-public-key

    # Configure apt and install packages
    RUN apt-get update \
        && apt-get install -y --no-install-recommends apt-utils dialog 2>&1 \
        && apt-get install -y \
            iproute2 \
            procps \
            sudo \
            bash-completion \
            build-essential \
            curl \
            wget \
            software-properties-common \
            direnv \
            tzdata \
            python3-pip \
            docker-ce \ # install docker engine for running +ci target
            mercurial \
        && add-apt-repository ppa:git-core/ppa \
        && apt-get install -y git \
        && curl -sL https://deb.nodesource.com/setup_16.x | bash - \
        && apt-get install -y nodejs=16.* \
        # the haxelib server code base is not Haxe 4 ready
        && add-apt-repository ppa:haxe/haxe3.4 \
        # Install mysql-client
        # https://github.com/docker-library/mysql/blob/master/5.7/Dockerfile.debian
        && echo 'deb http://repo.mysql.com/apt/ubuntu/ bionic mysql-5.7' > /etc/apt/sources.list.d/mysql.list \
        && apt-get update \
        && apt-get -y install mysql-client=5.7.* \
        # install kubectl
        && curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
        && echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list \
        && apt-get update \
        && apt-get -y install --no-install-recommends kubectl=1.23.* \
        # install helm
        && curl -fsSL https://baltocdn.com/helm/signing.asc | apt-key add - \
        && echo "deb https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list \
        && apt-get update \
        && apt-get -y install --no-install-recommends helm \
        #
        # Clean up
        && apt-get autoremove -y \
        && apt-get clean -y \
        && rm -rf /var/lib/apt/lists/*

    # install neko nightly
    DO +INSTALL_NEKO
    RUN neko -version

    # install haxe nightly
    COPY +haxe-latest/haxe /usr/bin/haxe
    COPY +haxe-latest/haxelib /usr/bin/haxelib
    RUN mkdir -p /usr/share/haxe/
    COPY +haxe-latest/std /usr/share/haxe/std
    RUN haxe --version

    ENV YARN_CACHE_FOLDER=/yarn
    RUN mkdir -m 777 "$YARN_CACHE_FOLDER"
    RUN npm install -g yarn

    # Switch back to dialog for any ad-hoc use of apt-get
    ENV DEBIAN_FRONTEND=

    # Setting the ENTRYPOINT to docker-init.sh will configure non-root access
    # to the Docker socket. The script will also execute CMD as needed.
    ENTRYPOINT [ "/usr/local/share/docker-init.sh" ]
    CMD [ "sleep", "infinity" ]

    RUN mkdir -m 777 "/workspace"
    WORKDIR /workspace

# Usage:
# RUN /aws/install
awscli:
    FROM +devcontainer-base
    RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "/tmp/awscliv2.zip" \
        && unzip -qq /tmp/awscliv2.zip -d / \
        && rm /tmp/awscliv2.zip
    SAVE ARTIFACT /aws

# Usage:
# COPY +doctl/doctl /usr/local/bin/
doctl:
    ARG TARGETARCH
    ARG DOCTL_VERSION=1.92.1
    RUN curl -fsSL "https://github.com/digitalocean/doctl/releases/download/v${DOCTL_VERSION}/doctl-${DOCTL_VERSION}-linux-${TARGETARCH}.tar.gz" | tar xvz -C /usr/local/bin/
    SAVE ARTIFACT /usr/local/bin/doctl

# Usage:
# COPY +tfenv/tfenv /tfenv
# RUN ln -s /tfenv/bin/* /usr/local/bin
tfenv:
    FROM +devcontainer-base
    RUN git clone --depth 1 https://github.com/tfutils/tfenv.git /tfenv
    SAVE ARTIFACT /tfenv

# Usage:
# COPY +terraform-ls/terraform-ls /usr/local/bin/
terraform-ls:
    ARG --required TARGETARCH
    ARG TERRAFORM_LS_VERSION=0.30.1
    RUN curl -fsSL -o terraform-ls.zip https://github.com/hashicorp/terraform-ls/releases/download/v${TERRAFORM_LS_VERSION}/terraform-ls_${TERRAFORM_LS_VERSION}_linux_${TARGETARCH}.zip \
        && unzip -qq terraform-ls.zip \
        && mv ./terraform-ls /usr/local/bin/ \
        && rm terraform-ls.zip
    SAVE ARTIFACT /usr/local/bin/terraform-ls

terraform:
    FROM +tfenv
    RUN ln -s /tfenv/bin/* /usr/local/bin
    ARG --required TERRAFORM_VERSION
    RUN tfenv install "$TERRAFORM_VERSION"
    RUN tfenv use "$TERRAFORM_VERSION"

# Usage:
# COPY +tfk8s/tfk8s /usr/local/bin/
tfk8s:
    FROM golang:1.17
    RUN go install github.com/jrhouston/tfk8s@v0.1.7
    SAVE ARTIFACT /go/bin/tfk8s

# Usage:
# COPY +earthly/earthly /usr/local/bin/
# RUN earthly bootstrap --no-buildkit --with-autocomplete
earthly:
    FROM +devcontainer-base
    ARG --required TARGETARCH
    RUN curl -fsSL https://github.com/earthly/earthly/releases/download/v0.6.30/earthly-linux-${TARGETARCH} -o /usr/local/bin/earthly \
        && chmod +x /usr/local/bin/earthly
    SAVE ARTIFACT /usr/local/bin/earthly

rclone:
    FROM +devcontainer-base
    ARG TARGETARCH
    ARG VERSION=1.61.1
    RUN curl -fsSL "https://downloads.rclone.org/v${VERSION}/rclone-v${VERSION}-linux-${TARGETARCH}.zip" -o rclone.zip \
        && unzip -qq rclone.zip \
        && rm rclone.zip
    RUN rclone-*/rclone completion bash > bash_completion
    SAVE ARTIFACT rclone-*/rclone
    SAVE ARTIFACT bash_completion

run.n:
    FROM +devcontainer
    COPY .git .git
    COPY src src
    COPY hx3compat hx3compat
    COPY client.hxml haxelib.json .
    RUN haxe client.hxml
    SAVE ARTIFACT run.n AS LOCAL run.n

package-haxelib:
    FROM +devcontainer-base
    COPY src src
    COPY hx3compat hx3compat
    COPY package.hxml haxelib.json README.md .
    COPY +run.n/run.n .
    RUN haxe package.hxml
    SAVE ARTIFACT package.zip AS LOCAL package.zip

haxelib-deps:
    FROM +devcontainer-base
    USER $USERNAME
    COPY --chown=$USER_UID:$USER_GID libs.hxml run.n .
    COPY --chown=$USER_UID:$USER_GID lib/record-macros lib/record-macros
    COPY --chown=$USER_UID:$USER_GID lib/argon2 lib/argon2
    RUN mkdir -p haxelib_global
    RUN neko run.n setup haxelib_global
    RUN haxe libs.hxml && rm haxelib_global/*.zip
    ARG AWS_SDK_NEKO_COMMIT=c614b20f1302a92095865690b5649269f3eb3171
    COPY (github.com/andyli/aws-sdk-neko:${AWS_SDK_NEKO_COMMIT}+package-zip/aws-sdk-neko.zip --IMAGE_TAG="$AWS_SDK_NEKO_COMMIT") /tmp/aws-sdk-neko.zip
    RUN haxelib install /tmp/aws-sdk-neko.zip && rm /tmp/aws-sdk-neko.zip
    SAVE ARTIFACT haxelib_global

node-modules-prod:
    FROM +devcontainer-base
    USER $USERNAME
    COPY --chown=$USER_UID:$USER_GID package.json yarn.lock .
    RUN yarn --production
    SAVE ARTIFACT node_modules

node-modules-dev:
    FROM +node-modules-prod
    RUN yarn
    SAVE ARTIFACT node_modules

dts2hx-externs:
    FROM +node-modules-dev
    USER $USERNAME
    COPY --chown=$USER_UID:$USER_GID generate_extern.sh .
    RUN bash generate_extern.sh
    SAVE ARTIFACT lib/dts2hx-generated

devcontainer:
    FROM +devcontainer-base

    # AWS cli
    COPY +awscli/aws /aws
    RUN /aws/install

    # doctl
    COPY +doctl/doctl /usr/local/bin/

    # tfenv
    COPY +tfenv/tfenv /tfenv
    RUN ln -s /tfenv/bin/* /usr/local/bin/
    COPY --chown=$USER_UID:$USER_GID terraform/.terraform-version "/home/$USERNAME/"
    RUN tfenv install "$(cat /home/$USERNAME/.terraform-version)"
    RUN tfenv use "$(cat /home/$USERNAME/.terraform-version)"
    COPY +terraform-ls/terraform-ls /usr/local/bin/

    COPY +tfk8s/tfk8s /usr/local/bin/

    # Install earthly
    COPY +earthly/earthly /usr/local/bin/
    RUN earthly bootstrap --no-buildkit --with-autocomplete

    # Install rclone
    COPY +rclone/rclone /usr/local/bin/
    COPY +rclone/bash_completion /etc/bash_completion.d/rclone

    # Install skeema
    RUN curl -fsSL -o skeema.deb https://github.com/skeema/skeema/releases/download/v1.7.0/skeema_${TARGETARCH}.deb \
        && apt-get install -y ./skeema.deb \
        && rm ./skeema.deb

    USER $USERNAME

    COPY --chown=$USER_UID:$USER_GID +node-modules-dev/node_modules node_modules
    VOLUME /workspace/node_modules
    COPY --chown=$USER_UID:$USER_GID +dts2hx-externs/dts2hx-generated lib/dts2hx-generated
    VOLUME /workspace/lib/dts2hx-generated
    COPY --chown=$USER_UID:$USER_GID +haxelib-deps/haxelib_global haxelib_global
    VOLUME /workspace/haxelib_global

    # config haxelib for $USERNAME
    RUN haxelib setup /workspace/haxelib_global

    # Config direnv
    COPY --chown=$USER_UID:$USER_GID .devcontainer/direnv.toml /home/$USERNAME/.config/direnv/config.toml

    # Config bash
    RUN echo 'eval "$(direnv hook bash)"' >> ~/.bashrc \
        && echo 'complete -C terraform terraform' >> ~/.bashrc \
        && echo "complete -C '/usr/local/bin/aws_completer' aws" >> ~/.bashrc \
        && echo 'source <(helm completion bash)' >> ~/.bashrc \
        && echo 'source <(kubectl completion bash)' >> ~/.bashrc \
        && echo 'source <(doctl completion bash)' >> ~/.bashrc

    # Create kubeconfig for storing current-context,
    # such that the project kubeconfig_* files wouldn't be touched.
    RUN mkdir -p ~/.kube && install -m 600 /dev/null ~/.kube/config

    USER root

    # config haxelib for root
    RUN haxelib setup /workspace/haxelib_global

    ARG GIT_SHA
    ENV GIT_SHA="$GIT_SHA"
    ARG IMAGE_NAME="$DEVCONTAINER_IMAGE_NAME_DEFAULT"
    ARG IMAGE_TAG="development"
    ARG IMAGE_CACHE="$IMAGE_NAME:$IMAGE_TAG"
    SAVE IMAGE --cache-from="$IMAGE_CACHE" --push "$IMAGE_NAME:$IMAGE_TAG"

do-kubeconfig:
    FROM +doctl
    ARG --required CLUSTER_ID
    RUN --mount=type=secret,id=+secrets/.envrc,target=.envrc \
        . ./.envrc \
        && KUBECONFIG="kubeconfig" doctl kubernetes cluster kubeconfig save "$CLUSTER_ID"
    SAVE ARTIFACT --keep-ts kubeconfig

aws-ndll:
    FROM +haxelib-deps
    SAVE ARTIFACT /workspace/haxelib_global/aws-sdk-neko/*/ndll/Linux64/aws.ndll

argon2-ndll:
    # install build-essential, cmake, and neko
    RUN apt-get update \
        && DEBIAN_FRONTEND=noninteractive apt-get install -y \
            build-essential \
        && rm -r /var/lib/apt/lists/*

    RUN curl -fsSL "https://github.com/Kitware/CMake/releases/download/v3.24.0/cmake-3.24.0-linux-x86_64.sh" -o cmake-install.sh \
        && sh cmake-install.sh --skip-license --prefix /usr/local \
        && rm cmake-install.sh

    DO +INSTALL_NEKO
    RUN neko -version

    COPY lib/argon2 lib/argon2
    RUN mkdir lib/argon2/build
    RUN cmake -B lib/argon2/build -S lib/argon2
    RUN make -C lib/argon2/build
    SAVE ARTIFACT lib/argon2/build/argon2.ndll

haxelib-server-builder:
    FROM haxe:3.4

    WORKDIR /workspace
    COPY lib/record-macros lib/record-macros
    COPY lib/argon2 lib/argon2
    COPY --chown=$USER_UID:$USER_GID +node-modules-dev/node_modules node_modules
    COPY --chown=$USER_UID:$USER_GID +dts2hx-externs/dts2hx-generated lib/dts2hx-generated
    COPY --chown=$USER_UID:$USER_GID +haxelib-deps/haxelib_global haxelib_global
    # haxelib from haxe 3.4 is case-sensitive
    RUN mv haxelib_global/pbkdf2 haxelib_global/PBKDF2

    RUN haxe -version
    RUN haxelib setup /workspace/haxelib_global

haxelib-server-legacy:
    FROM +haxelib-server-builder
    COPY server_legacy.hxml server_each.hxml .
    COPY src src
    COPY hx3compat hx3compat
    COPY www/legacy www/legacy
    RUN haxe server_legacy.hxml
    SAVE ARTIFACT www/legacy/index.n

haxelib-server-website:
    FROM +haxelib-server-builder
    COPY server_website.hxml server_each.hxml .
    COPY src src
    COPY hx3compat hx3compat
    RUN haxe server_website.hxml
    SAVE ARTIFACT www/index.n

haxelib-server-website-highlighter:
    FROM +haxelib-server-builder
    COPY server_website_highlighter.hxml .
    RUN haxe server_website_highlighter.hxml
    SAVE ARTIFACT www/js/highlighter.js

haxelib-server-tasks:
    FROM +haxelib-server-builder
    COPY server_tasks.hxml server_each.hxml .
    COPY src src
    COPY hx3compat hx3compat
    RUN haxe server_tasks.hxml
    SAVE ARTIFACT www/tasks.n

haxelib-server-api-3.0:
    FROM +haxelib-server-builder
    COPY server_api_3.0.hxml server_each.hxml .
    COPY src src
    COPY hx3compat hx3compat
    RUN haxe server_api_3.0.hxml
    SAVE ARTIFACT www/api/3.0/index.n

haxelib-server-api:
    FROM +haxelib-server-builder
    COPY server_api.hxml server_each.hxml .
    COPY src src
    COPY hx3compat hx3compat
    RUN haxe server_api.hxml
    SAVE ARTIFACT www/api/4.0/index.n

haxelib-server-www-js:
    FROM +devcontainer-base
    RUN curl -fsSLO https://stackpath.bootstrapcdn.com/twitter-bootstrap/2.3.1/js/bootstrap.min.js
    RUN curl -fsSL https://code.jquery.com/jquery-1.12.4.min.js -o jquery.min.js
    SAVE ARTIFACT *.js

haxelib-server-www-css:
    FROM +devcontainer-base
    RUN curl -fsSLO https://stackpath.bootstrapcdn.com/twitter-bootstrap/2.3.1/css/bootstrap-combined.min.css
    SAVE ARTIFACT *.css

tora:
    FROM +haxelib-deps
    SAVE ARTIFACT /workspace/haxelib_global/tora/*/run.n

haxelib-server:
    FROM phusion/baseimage:focal-1.1.0

    RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common \
        && add-apt-repository ppa:haxe/releases -y \
        && apt-get update && apt-get upgrade -y \
        && DEBIAN_FRONTEND=noninteractive apt-get install -y \
            curl \
            apache2 \
            neko \
            libapache2-mod-neko \
        && echo "deb http://security.ubuntu.com/ubuntu bionic-security main" >> /etc/apt/sources.list \
        && apt-get update \
        && DEBIAN_FRONTEND=noninteractive apt-get install -y \
            libcurl3-gnutls \ # for aws.ndll
            libssl1.0.0 \     # for aws.ndll
        && rm -r /var/lib/apt/lists/*

    # apache httpd
    RUN rm -rf /var/www/html \
        && mkdir -p /var/lock/apache2 /var/run/apache2 /var/log/apache2 /var/www/html \
        && chown -R www-data:www-data /var/lock/apache2 /var/run/apache2 /var/log/apache2 /var/www/html \
        && a2enmod rewrite \
        && a2enmod proxy \
        && a2enmod proxy_http \
        && a2enmod headers \
        && a2enmod status \
        && a2dismod mpm_event \
        && a2enmod mpm_prefork \
        && rm /etc/apache2/apache2.conf \
        && rm /etc/apache2/mods-enabled/status.conf \
        && rm /etc/apache2/conf-enabled/* /etc/apache2/sites-enabled/*
    COPY apache2.conf /etc/apache2/apache2.conf
    RUN { \
            echo 'LoadModule neko_module /usr/lib/x86_64-linux-gnu/neko/mod_neko2.ndll'; \
            echo 'AddHandler neko-handler .n'; \
        } > /etc/apache2/mods-enabled/neko.conf \
        && apachectl stop

    COPY +aws-ndll/aws.ndll /usr/lib/x86_64-linux-gnu/neko/aws.ndll
    COPY +argon2-ndll/argon2.ndll /usr/lib/x86_64-linux-gnu/neko/argon2.ndll

    WORKDIR /src

    COPY --chown www-data:www-data www www
    RUN rm -rf www/files www/tmp
    COPY --chown www-data:www-data +haxelib-server-www-js/* /src/www/js/
    COPY --chown www-data:www-data +haxelib-server-www-css/* /src/www/css/

    COPY src/legacyhaxelib/.htaccess /src/www/legacy/
    COPY src/legacyhaxelib/haxelib.css /src/www/legacy/
    COPY src/legacyhaxelib/website.mtt /src/www/legacy/

    RUN rm -rf /var/www/html
    RUN ln -s /src/www /var/www/html
    USER www-data
    RUN mkdir -p /var/www/html/files
    RUN mkdir -p /var/www/html/tmp
    USER root

    COPY +haxelib-server-legacy/index.n www/legacy/index.n
    COPY +haxelib-server-website-highlighter/highlighter.js www/js/highlighter.js
    COPY +haxelib-server-website/index.n www/index.n
    COPY +haxelib-server-tasks/tasks.n www/tasks.n
    COPY +haxelib-server-api-3.0/index.n www/api/3.0/index.n
    COPY +haxelib-server-api/index.n www/api/4.0/index.n

    EXPOSE 80

    RUN mkdir /etc/service/httpd
    COPY server-daemon-httpd.sh /etc/service/httpd/run
    RUN chmod a+x /etc/service/httpd/run

    CMD ["/sbin/my_init"]

    HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
        CMD curl -fsSL http://localhost/httpd-status?auto

    ARG GIT_SHA
    ENV GIT_SHA="$GIT_SHA"
    ARG IMAGE_NAME="$HAXELIB_SERVER_IMAGE_NAME_DEFAULT"
    ARG IMAGE_TAG="development"
    ARG IMAGE_CACHE="$IMAGE_NAME:$IMAGE_TAG"
    SAVE IMAGE --cache-from="$IMAGE_CACHE" --push "$IMAGE_NAME:$IMAGE_TAG"

copy-image:
    LOCALLY
    ARG --required SRC
    ARG --required DEST
    RUN docker pull "$SRC"
    RUN docker tag "$SRC" "$DEST"
    RUN docker push "$DEST"

ci-runner:
    FROM +devcontainer
    COPY test .
    COPY ci.hxml .
    RUN haxe --version
    RUN haxe ci.hxml
    SAVE ARTIFACT bin/ci.n

ci-tests:
    FROM +devcontainer
    COPY hx3compat hx3compat
    COPY lib/node-sys-db lib/node-sys-db
    COPY lib/record-macros lib/record-macros
    COPY lib/argon2 lib/argon2
    COPY +argon2-ndll/argon2.ndll argon2.ndll
    COPY src src
    COPY www www
    COPY test test
    COPY *.hxml .

    # for package.hxml
    COPY haxelib.json README.md .
    COPY +run.n/run.n .

    COPY +ci-runner/ci.n bin/ci.n
    ENV HAXELIB_SERVER=localhost
    ENV HAXELIB_SERVER_PORT=80
    ENV HAXELIB_DB_HOST=localhost
    ENV HAXELIB_DB_PORT=3306
    ENV HAXELIB_DB_USER=dbUser
    ENV HAXELIB_DB_PASS=dbPass
    ENV HAXELIB_DB_NAME=haxelib
    WITH DOCKER \
            --compose test/docker-compose.yml \
            --load haxe/lib.haxe.org:development=+haxelib-server
        RUN neko bin/ci.n
    END

ci-images:
    ARG --required GIT_REF_NAME
    ARG --required GIT_SHA
    ARG IMAGE_TAG="$(echo "$GIT_REF_NAME" | sed -e 's/[^A-Za-z0-9\.]/-/g')"
    BUILD +devcontainer \
        --IMAGE_CACHE="$DEVCONTAINER_IMAGE_NAME_DEFAULT:$IMAGE_TAG" \
        --IMAGE_TAG="$IMAGE_TAG" \
        --IMAGE_TAG="$GIT_SHA" \
        --GIT_SHA="$GIT_SHA"
    BUILD +haxelib-server \
        --IMAGE_CACHE="$HAXELIB_SERVER_IMAGE_NAME_DEFAULT:$IMAGE_TAG" \
        --IMAGE_TAG="$IMAGE_TAG" \
        --IMAGE_TAG="$GIT_SHA" \
        --GIT_SHA="$GIT_SHA"

s3fs-image:
    FROM ubuntu:focal
    RUN apt-get update \
        && DEBIAN_FRONTEND=noninteractive apt-get install -y \
            s3fs \
        && rm -r /var/lib/apt/lists/*
    ENV MNT_POINT /var/s3fs
    RUN mkdir -p "$MNT_POINT"
    ARG IMAGE_TAG=latest
    SAVE IMAGE --push haxe/s3fs:$IMAGE_TAG

gh-ost-deb:
    ARG --required GHOST_VERSION
    RUN curl -fsSL "https://github.com/github/gh-ost/releases/download/v${GHOST_VERSION}/gh-ost_${GHOST_VERSION}_amd64.deb" -o gh-ost.deb
    SAVE ARTIFACT gh-ost.deb

gh-ost-image:
    FROM ubuntu:focal
    ARG GHOST_VERSION=1.1.2
    COPY (+gh-ost-deb/gh-ost.deb --GHOST_VERSION="$GHOST_VERSION") .
    RUN apt-get install ./gh-ost.deb \
        && rm ./gh-ost.deb
    SAVE IMAGE --push haxe/gh-ost:$GHOST_VERSION

curl-file:
    ARG --required URL
    ARG --required FILENAME
    RUN curl -fsSL "$URL" -o "$FILENAME"
    SAVE ARTIFACT "$FILENAME"

ghostferry-copydb-image:
    FROM ubuntu:focal
    ARG GHOSTFERRY_COMMIT="ce94688"
    ARG GHOSTFERRY_BUILD="1.1.0+20220112142231+ce94688"
    COPY (+curl-file/* --URL="https://github.com/Shopify/ghostferry/releases/download/release-${GHOSTFERRY_COMMIT}/ghostferry-copydb_${GHOSTFERRY_BUILD}.deb" --FILENAME=ghostferry-copydb.deb) .
    RUN apt-get install ./ghostferry-copydb.deb \
        && rm ./ghostferry-copydb.deb
    SAVE IMAGE --push haxe/ghostferry-copydb:$GHOSTFERRY_COMMIT

rds-pem:
    RUN curl -fsSLO https://truststore.pki.rds.amazonaws.com/eu-west-1/eu-west-1-bundle.pem
    SAVE ARTIFACT --keep-ts eu-west-1-bundle.pem AS LOCAL rds-eu-west-1-bundle.pem
