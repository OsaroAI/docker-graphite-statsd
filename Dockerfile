ARG BOILERPLATE_PARENT_IMAGE="osaroai/boilerplate"
ARG BOILERPLATE_PARENT_TAG="xenial-10.1-cudnn7-devel"

FROM $BOILERPLATE_PARENT_IMAGE:$BOILERPLATE_PARENT_TAG AS python

LABEL maintainer="Denys Zhdanov <denis.zhdanov@gmail.com>"

RUN apt-get update

RUN true \
 && apt-get install -y \
      libcairo2-dev \
      collectd \
      collectd-utils \
      findutils \
      librrd-dev \
      logrotate \
      memcached \
      nginx \
      python-ldap \
      redis-server \
      runit \
      sqlite \
      expect \
      python-mysqldb \
      libmysqlclient-dev \
      mysql-client \
      postgresql \
      libpq-dev \
      libsasl2-dev \
      libldap2-dev \
      libssl-dev \
 && rm -rf \
      /etc/nginx/conf.d/default.conf \
 && mkdir -p \
      /var/log/carbon \
      /var/log/graphite

FROM python as build
LABEL maintainer="Denys Zhdanov <denis.zhdanov@gmail.com>"

RUN true \
 && apt-get install -y \
      git \
      libffi-dev \
      pkg-config \
      python3-cairo \
      python3-pip \
      python-ldap \
      python-rrdtool \
      python-mysqldb \
      python3-dev \
      rrdtool \
      wget \
 && pip3 install virtualenv==16.7.10 \
 && virtualenv -p python3 /opt/graphite \
 && . /opt/graphite/bin/activate \
 && pip3 install pip==20.0.2 \
 && pip3 install \
      django==1.11.25 \
      django-statsd-mozilla \
      fadvise \
      gunicorn \
      msgpack-python \
      redis \
      rrdtool \
      python-ldap \
      mysqlclient \
      psycopg2 \
      wheel \
      setuptools

ARG version=1.1.6

# install whisper
ARG whisper_version=${version}
ARG whisper_repo=https://github.com/graphite-project/whisper.git
RUN git clone -b ${whisper_version} --depth 1 ${whisper_repo} /usr/local/src/whisper \
 && cd /usr/local/src/whisper \
 && . /opt/graphite/bin/activate \
 && python3 ./setup.py install

# install carbon
ARG carbon_version=${version}
ARG carbon_repo=https://github.com/graphite-project/carbon.git
RUN . /opt/graphite/bin/activate \
 && git clone -b ${carbon_version} --depth 1 ${carbon_repo} /usr/local/src/carbon \
 && cd /usr/local/src/carbon \
 && pip3 install -r requirements.txt \
 && python3 ./setup.py install

# install graphite
ARG graphite_version=${version}
ARG graphite_repo=https://github.com/graphite-project/graphite-web.git
RUN . /opt/graphite/bin/activate \
 && git clone -b ${graphite_version} --depth 1 ${graphite_repo} /usr/local/src/graphite-web \
 && cd /usr/local/src/graphite-web \
 && pip3 install -r requirements.txt \
 && python3 ./setup.py install

COPY conf/opt/graphite/conf/                             /opt/defaultconf/graphite/
COPY conf/opt/graphite/webapp/graphite/local_settings.py /opt/defaultconf/graphite/local_settings.py

# config graphite
COPY conf/opt/graphite/conf/*.conf /opt/graphite/conf/
COPY conf/opt/graphite/webapp/graphite/local_settings.py /opt/graphite/webapp/graphite/local_settings.py

WORKDIR /opt/graphite/webapp
RUN mkdir -p /var/log/graphite/ \
  && PYTHONPATH=/opt/graphite/webapp /opt/graphite/bin/django-admin.py collectstatic --noinput --settings=graphite.settings

FROM python as production

COPY conf /

# copy /opt from build image
COPY --from=build /opt /opt

RUN set -x \
# create nginx user/group first, to be consistent throughout docker variants
    && addgroup --system nginx \
    && adduser --system --disabled-login --ingroup nginx --no-create-home --home /nonexistent --gecos "nginx user" --shell /bin/false nginx

# defaults
EXPOSE 80 2003-2004 2013-2014 2023-2024 8080 8125 8125/udp 8126
VOLUME ["/opt/graphite/conf", "/opt/graphite/storage", "/opt/graphite/webapp/graphite/functions/custom", "/etc/nginx", "/etc/logrotate.d", "/var/log", "/var/lib/redis"]

STOPSIGNAL SIGHUP

ENTRYPOINT ["/entrypoint"]
