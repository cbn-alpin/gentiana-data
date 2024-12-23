#+-------------------------------------------------------------------------------------------------+
FROM python:3.11.11-slim-bookworm AS base

ARG BUILD_NAME="cbna/gentiana-data"
ARG BUILD_DATE
ARG BUILD_VENDOR="CBN Alpin"
ARG BUILD_AUTHORS="adminsys@cbn-alpin.fr"
ARG BUILD_VERSION="main"
ARG BUILD_VCS_URL="https://github.com/cbn-alpin/gentiana-data/"
ARG BUILD_VCS_REF
ARG BUILD_LICENCE="MIT"
ARG PGSQL_MAJOR_VERSION="17"
ARG USER_NAME="geonat"
ARG USER_GROUP="geonat"
ARG USER_UID=1000
ARG USER_GID=1000

ENV LANG="fr_FR.UTF-8"
ENV LANGUAGE="fr_FR:fr"
ENV LC_ALL="fr_FR.UTF-8"
ENV TZ="Europe/Paris"
# Tell pipenv to create venv in the current directory
ENV PIPENV_VENV_IN_PROJECT=1


#+-------------------------------------------------------------------------------------------------+
FROM base AS builder

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
        apt-get install -y --quiet --no-install-recommends \
            # Used to prepare Postgresql repository
            wget apt-utils gnupg lsb-release ca-certificates \
            # Used for download Postgresql
            ca-certificates \
            # Used for Postgresql
            locales tzdata \
            # Used for build psycopg2
            build-essential libpq-dev gcc python3-dev \
            # Use Git as alternative to COPY
            #git \
    # Add postresql deb package repo
    && echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && install -d /usr/share/postgresql-common/pgdg \
    && wget --quiet -O /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    # Install Postgresql client
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
        apt-get install -y --quiet --no-install-recommends \
            "postgresql-client-${PGSQL_MAJOR_VERSION}" \
    # Clean APT
    && apt-get -y autoremove \
    && apt-get clean autoclean \
    && rm -fr /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*

WORKDIR /build

# Alternative to COPY
# RUN git clone --recurse-submodules -j4 https://github.com/cbn-alpin/gentiana-data.git \
#     && cd gentiana-data/ \
#     && git checkout "${BUILD_VERSION}"

COPY . /build

# Install python dependencies
RUN python3 -m pip install --upgrade pip \
    && pip3 install pipenv --no-cache-dir

# Prepare scripts
RUN cd import-parser/ \
    && pipenv sync

#+-------------------------------------------------------------------------------------------------+
FROM base AS runtime

LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.version="${BUILD_VERSION}"
LABEL org.opencontainers.image.title="${BUILD_NAME}"
LABEL org.opencontainers.image.vendor="${BUILD_VENDOR}"
LABEL org.opencontainers.image.authors="${BUILD_AUTHORS}"
LABEL org.opencontainers.image.source="${BUILD_VCS_URL}"
LABEL org.opencontainers.image.revision="${BUILD_VCS_REF}"
LABEL org.opencontainers.image.licenses="${BUILD_LICENCE}"

# Add postresql deb package repo
COPY --from=builder /etc/apt/sources.list.d/pgdg.list /etc/apt/sources.list.d/pgdg.list
COPY --from=builder /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc

# Install Debian packages
# WARNING: use same postgresql-client package that the host server !
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
        apt-get install -y --quiet --no-install-recommends \
            # Utils packages
            vim-tiny \
            # Used for download Postgresql
            ca-certificates \
            # Used for Postgresql
            locales tzdata \
            # Used for build psycopg2
            build-essential libpq-dev gcc python3-dev \
            # Used when import-data.sh script is running
            sshpass openssh-client bzip2 \
    # Install Postgresql client
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
        apt-get install -y --quiet --no-install-recommends \
            "postgresql-client-${PGSQL_MAJOR_VERSION}" \
    # Clean APT
    && apt-get -y autoremove \
    && apt-get clean autoclean \
    && rm -fr /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*

# Install python dependencies
RUN python3 -m pip install --upgrade pip \
    && pip3 install pipenv --no-cache-dir

# Set the locale
RUN sed -i 's/# \(fr_FR\.UTF-8 .*\)/\1/' /etc/locale.gen \
    && touch /usr/share/locale/locale.alias \
    && locale-gen

# Add /etc/vim/vimrc.local
RUN echo "runtime! defaults.vim" > /etc/vim/vimrc.local \
    && echo "let g:skip_defaults_vim = 1" >> /etc/vim/vimrc.local  \
    && echo "set mouse=" >> /etc/vim/vimrc.local

# Set alias
RUN sed -i 's/^# alias/alias/' /root/.bashrc \
    && echo "alias ll='ls -l'" >> /etc/bash.bashrc

# Copy file from "builder" image
COPY --from=builder /build /app

# Define root app directory
WORKDIR /app

# Create user and set rights
RUN groupadd -r -g ${USER_GID} ${USER_GROUP} \
    && useradd -rm -s /bin/bash -u ${USER_UID} -g ${USER_GROUP} ${USER_NAME} \
    # Add the .ssh directory to the current user for SFTP
    && mkdir -p "/home/${USER_NAME}/.ssh/" \
    && chmod 700 "/home/${USER_NAME}/.ssh" \
    && touch "/home/${USER_NAME}/.ssh/known_hosts" \
    && chmod 600 "/home/${USER_NAME}/.ssh/known_hosts" \
    # Set the owner of new directories and files
    && chown -R ${USER_NAME}:${USER_GROUP} /app "/home/${USER_NAME}"

USER ${USER_NAME}:${USER_GROUP}

#ENTRYPOINT ["/bin/bash"]
ENTRYPOINT ["/app/geonature/bin/import_data.sh"]
