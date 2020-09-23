FROM alpine:3.11
LABEL Name="powerdns" Version="4.1.14" maintainer="Sebastian Pitsch <pitsch@freinet.de>"
# Based on https://hub.docker.com/r/psitrax/powerdns/

ENV REFRESHED_AT="2020-09-23" \
    POWERDNS_VERSION=4.1.14 \
    MYSQL_AUTOCONF=true \
    MYSQL_PREPARE_DB=true \
    MYSQL_PORT="3306"

RUN apk --update add mysql-client mariadb-connector-c-dev mariadb-connector-c libstdc++ libgcc bash && \
    apk add --virtual build-deps \
      g++ make mariadb-dev curl boost-dev && \
    curl -sSL https://downloads.powerdns.com/releases/pdns-$POWERDNS_VERSION.tar.bz2 | tar xj -C /tmp && \
    cd /tmp/pdns-$POWERDNS_VERSION && \
    ./configure --prefix="" --exec-prefix=/usr --sysconfdir=/etc/pdns \
      --with-modules="gmysql" --without-lua && \
    make && make install-strip && cd / && \
    mkdir -p /etc/pdns/conf.d && \
    addgroup -S pdns 2>/dev/null && \
    adduser -S -D -H -h /var/empty -s /bin/false -G pdns -g pdns pdns 2>/dev/null && \
    apk del --purge build-deps && \
    apk add boost-program_options && \
    rm -rf /tmp/pdns-$POWERDNS_VERSION /var/cache/apk/*

RUN apk --update add tzdata
RUN cp /usr/share/zoneinfo/Europe/Berlin /etc/localtime
RUN echo "Europe/Berlin" > /etc/timezone

ADD schema.sql pdns.conf /etc/pdns/
ADD entrypoint.sh /

EXPOSE 53/tcp 53/udp

ENTRYPOINT ["/entrypoint.sh"]
