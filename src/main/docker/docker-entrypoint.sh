#!/bin/bash
#set -e

SOURCE=https://s3.amazonaws.com/dstresearch-public/www.dstcorp.io.tar.gz
TARFILE=/tmp/www.tar.gz
DOCROOT=/srv/www

function fetch {
	curl -s -o $TARFILE $SOURCE
	mkdir -p $DOCROOT
	cd $DOCROOT
	tar xfz $TARFILE
	chown -R www-data:www-data $DOCROOT/*
	cd - 2>&1 >/dev/null
}

if [[ "$1" = 'apache2' ]]; then
	export APACHE_SERVERNAME=default-host
	. /etc/apache2/envvars
	rm -f $APACHE_PID_FILE
	mkdir -p /tmp/apache2/cache.lock
	mkdir -p /var/cache/apache2/mod_cache_disk
	chown -R www-data:www-data /var/cache/apache2
	chown -R www-data:www-data /tmp/apache2

	#
	# create the client cert file from the cert + key
	#
	cp /etc/apache2/certs/cert.crt /etc/apache2/certs/client.pem
	sed 's/PRIVATE KEY/RSA PRIVATE KEY/g' /etc/apache2/keys/cert.key >>/etc/apache2/certs/client.pem

	#
	# create server cert file from the cert + bundle
	#
	cp /etc/apache2/certs/cert.crt /etc/apache2/certs/server.pem
	cat /etc/apache2/certs/bundle.crt >>/etc/apache2/certs/server.pem

	#
	# create the accepted CA file
	#
	cp /usr/local/share/ca-certificates/dst-root-ca.crt /etc/apache2/certs/accepted-proxy-ca-bundle.pem

        #
        # copy down the content served by this web server
        #
	if [[ -n "$SITE_CONTENT" ]]; then
		SOURCE=$SITE_CONTENT
	fi

        curl -sk -o $TARFILE $SOURCE
	fetch

	exec "$@" -DFOREGROUND
fi

if [[ "$1" = 'monitor' ]]; then

#
# check for updates to the SITE_CONTENT, then
# run htcacheclean once every 60 interations
#

LAST_MOD=`date -R`

# default interval is once a minute
	INTERVAL=60

	if [[ -n "$WAIT_INTERVAL" ]]; then
        	INTERVAL=$WAIT_INTERVAL
	fi

	while [ true ]; do
        	for i in `seq 1 60`;
	        do
        	        sleep $INTERVAL

			rc=`curl -is --head -H "if-modified-since: $LAST_MOD" $SOURCE | grep -i http | grep 200`

			if [[ -n "$rc" ]]; then
				LAST_MOD=`date -R`
				fetch

				rm -rf /var/cache/apache2/mod_cache_disk/*

				echo "Applying updated $SOURCE to website content"
			fi
	        done

        	htcacheclean -n -t -p/var/cache/apache2/mod_cache_disk -l10M
	        htcacheclean -v -p/var/cache/apache2/mod_cache_disk -A
	done

	exit 1

fi

exec "$@"



