FROM debian:12.8-slim AS builder

ARG PGSQL_MAJOR_VERSION="17"
ARG BUILD_VERSION="main"

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
        apt-get install -y --quiet --no-install-recommends \
            wget apt-utils gnupg lsb-release ca-certificates locales tzdata \
            python3 python3-dev build-essential pipenv git \
    # Add postresql deb package repo
    && echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && install -d /usr/share/postgresql-common/pgdg \
    && wget --quiet -O /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
        apt-get install -y --quiet --no-install-recommends \
            "postgresql-client-${PGSQL_MAJOR_VERSION}" libpq-dev \
    # Clean APT
    && apt-get -y autoremove \
    && apt-get clean autoclean \
    && rm -fr /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*

WORKDIR /build/

RUN git clone --recurse-submodules -j4 https://github.com/cbn-alpin/gentiana-data.git \
    && cd gentiana-data/ \
    && git checkout "${APP_VERSION}"

RUN cd gentiana-data/import-parser/ \
    && export PIPENV_VENV_IN_PROJECT=1 \
    && pipenv install

#+--------------------------------------------------------------------------------------------------
FROM debian:12.8-slim

ARG PGSQL_MAJOR_VERSION="17"
ARG BUILD_DATE
ARG BUILD_VERSION="main"

LABEL   org.opencontainers.image.created = "${$BUILD_DATE}" \
        org.opencontainers.image.authors = "Jean-Pascal MILCENT <adminsys@cbn-alpin.fr>" \
        org.opencontainers.image.vendor = "CBN Alpin" \
        org.opencontainers.image.source = "https://github.com/cbn-alpin/gentiana-data/" \
        org.opencontainers.image.version = "${BUILD_VERSION}"

ENV LANG fr_FR.UTF-8
ENV LANGUAGE fr_FR:fr
ENV LC_ALL fr_FR.UTF-8
ENV TZ="Europe/Paris"

# Add postresql deb package repo
COPY --from=builder /etc/apt/sources.list.d/pgdg.list /etc/apt/sources.list.d/pgdg.list
COPY --from=builder /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc

# Install utils and sendmail
# WARNING: use same postgresql-client package that the host server !
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
        apt-get install -y --quiet --no-install-recommends \
            less vim\
            ca-certificates \
            locales tzdata \
            python3 \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
        apt-get install -y --quiet --no-install-recommends \
            "postgresql-client-${PGSQL_MAJOR_VERSION}" \
    # Clean APT
    && apt-get -y autoremove \
    && apt-get clean autoclean \
    && rm -fr /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*

# Set the locale
RUN sed -i 's/# \(fr_FR\.UTF-8 .*\)/\1/' /etc/locale.gen \
    && touch /usr/share/locale/locale.alias \
    && locale-gen

# Add /etc/vim/vimrc.local
RUN echo "runtime! defaults.vim" > /etc/vim/vimrc.local \
    && echo "let g:skip_defaults_vim = 1" >> /etc/vim/vimrc.local  \
    && echo "set mouse=" >> /etc/vim/vimrc.local

# Uncomment alias from /root/.bashrc
RUN sed -i 's/^# alias/alias/' /root/.bashrc

# Copy file from "builder" image
COPY --from=builder /build/gentiana-data/ /app

WORKDIR /app/
