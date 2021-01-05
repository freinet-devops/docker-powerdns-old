#!/bin/sh
# Based on https://hub.docker.com/r/psitrax/powerdns/
set -e

# --help, --version
[ "$1" = "--help" ] || [ "$1" = "--version" ] && exec pdns_server $1
# treat everything except -- as exec cmd
[ "${1:0:2}" != "--" ] && exec "$@"

upgrade4_2string='--upgrade-to-4-2'
params=$@
if [ "$params" != "${params%"$upgrade4_2string"*}" ]; then
    echo "$upgrade4_2string present in $params - running database migration..."
    MYSQLCMD="mysql --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASS} -r -N"
    MYSQLCMD="$MYSQLCMD $MYSQL_DB"
    cat /etc/pdns/schema_changes/4.1.0_to_4.2.0_schema.mysql.sql | $MYSQLCMD
    echo Schema upgraded. Exiting
    exit 0
fi

if $MYSQL_AUTOCONF ; then
  # Set MySQL Credentials in pdns.conf
  sed -r -i "s/^[# ]*gmysql-host=.*/gmysql-host=${MYSQL_HOST}/g" /etc/pdns/pdns.conf
  sed -r -i "s/^[# ]*gmysql-port=.*/gmysql-port=${MYSQL_PORT}/g" /etc/pdns/pdns.conf
  sed -r -i "s/^[# ]*gmysql-user=.*/gmysql-user=${MYSQL_USER}/g" /etc/pdns/pdns.conf
  sed -r -i "s/^[# ]*gmysql-password=.*/gmysql-password=${MYSQL_PASS}/g" /etc/pdns/pdns.conf
  sed -r -i "s/^[# ]*gmysql-dbname=.*/gmysql-dbname=${MYSQL_DB}/g" /etc/pdns/pdns.conf

  if $MYSQL_PREPARE_DB; then # don't prepare DB on replicating slaves
    # autoconf here
    MYSQLCMD="mysql --host=${MYSQL_HOST} --user=${MYSQL_USER} --password=${MYSQL_PASS} -r -N"

    # wait for Database come ready
    isDBup () {
        echo "SHOW STATUS" | $MYSQLCMD 1>/dev/null
        echo $?
    }

    RETRY=10
    until [ `isDBup` -eq 0 ] || [ $RETRY -le 0 ] ; do
        echo "Waiting for database to come up"
        sleep 5
        RETRY=$(expr $RETRY - 1)
    done
    if [ $RETRY -le 0 ]; then
        >&2 echo Error: Could not connect to Database on $MYSQL_HOST:$MYSQL_PORT
        exit 1
    fi

    # init database if necessary
    echo "CREATE DATABASE IF NOT EXISTS $MYSQL_DB;" | $MYSQLCMD
    MYSQLCMD="$MYSQLCMD $MYSQL_DB"

    if [ "$(echo "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = \"$MYSQL_DB\";" | $MYSQLCMD)" -le 1 ]; then
        echo Initializing Database
        cat /etc/pdns/schema.sql | $MYSQLCMD
    fi

    unset -v MYSQL_PASS

  fi

fi



if [[ ! -z "${TZ}" ]]; then
  echo "Setting Timezone to $TZ"
  cp /usr/share/zoneinfo/$TZ /etc/localtime
  echo $TZ > /etc/timezone
fi

# extra startup scripts
for f in /docker-entrypoint.d/*; do
    case "$f" in
        *.sh)     echo "$0: running $f"; . "$f" ;;
        *)        echo "$0: ignoring $f" ;;
    esac
    echo
done


# Run pdns server
trap "pdns_control quit" SIGHUP SIGINT SIGTERM

pdns_server "$@" &

wait
