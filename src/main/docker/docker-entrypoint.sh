#!/bin/bash
#set -e

VAULT_TOKEN_FILE=/usr/local/etc/vault/token
KEYSTORE=/usr/local/etc/keystore.p12

if [[ "$1" = 'runapp' ]]; then

    echo Environment
    echo "-----------"
    printenv | sort
    echo "-----------"
    echo "vault version: " `vault version`

    if [[ -z "${POD_NAMESPACE}" ]]; then
        echo "Use the 'downward api' to define the pod's namespace as POD_NAMESPACE! Exiting..."
        exit 1
    fi

    # we need a vault token to bootstrap our various secrets
    if [[ -z "${VAULT_TOKEN}" ]]; then
        if [[ ! -f ${VAULT_TOKEN_FILE} ]]; then
            echo "Unable to read Vault token. ${VAULT_TOKEN_FILE} is missing. Exiting..."
            exit 1
        fi
        VAULT_TOKEN=$(cat ${VAULT_TOKEN_FILE})
    fi

    GIT_REPO_PWORD=$(vault read -address=${VAULT_ADDR} -field=password secret/projects/${POD_NAMESPACE}/gitlab)
    JKS_KEY=$(vault read -addres=${VAULT_ADDR} -field=key secret/projects/${POD_NAMESPACE}/jks}

    #
    # check if the jks file was previously created, if not construct it
    #
    if [[ -f ${KEYSTORE} ]]; then
        echo "${KEYSTORE} missing.  Will generate it now."

        tmpdir=`mktemp -d`
        cd ${tmpdir}
        git config --global credential.helper cache --timeout 120
        git config --global credential.https://gitlab.com.dstcorp ${GIT_REPO_PWORD}
        git clone ${GIT_REPO_URL}
        clonedir=`basename ${GIT_REPO_URL} .git`

        if [[ ! -f ${clonedir}/certificates/config.dst.cloud.pem ]]; then
            echo "Unable to locate public key file certificates/config.dst.cloud.pem! Exiting..."
            exit 1
        fi

        
        cd -

    fi

	#
	# create the client cert file from the cert + key
	#
#	cp /etc/apache2/certs/cert.crt /etc/apache2/certs/client.pem
#	sed 's/PRIVATE KEY/RSA PRIVATE KEY/g' /etc/apache2/keys/cert.key >>/etc/apache2/certs/client.pem

	#
	# create server cert file from the cert + bundle
	#
#	cp /etc/apache2/certs/cert.crt /etc/apache2/certs/server.pem
#	cat /etc/apache2/certs/bundle.crt >>/etc/apache2/certs/server.pem

	#
	# create the accepted CA file
	#
#	cp /usr/local/share/ca-certificates/dst-root-ca.crt /etc/apache2/certs/accepted-proxy-ca-bundle.pem

	APPFLAGS=-Djava.security.egd=file:/dev/./urandom
	if [[ -n "$GIT_REPO_URL" ]]; then
		APPFLAGS="${APPFLAGS} -Dspring.cloud.config.server.git.uri=${GIT_REPO_URL}"
	fi

	exec java ${APPFLAGS} -jar /app.jar
fi

exec "$@"
