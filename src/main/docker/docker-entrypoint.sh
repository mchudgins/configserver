#!/bin/bash
#set -e

VAULT_TOKEN_FILE=/usr/local/etc/vault/token
APPJAR=../../../target/configserver-0.0.3-SNAPSHOT.jar
APPJAR=/app.jar

KEYSTORE=/tmp/keystore.p12

if [[ "$1" = 'runapp' ]]; then

    if [[ ! -z "${LOG_LEVEL}" ]]; then
    echo Environment
    echo "-----------"
    printenv | sort
    echo "-----------"
    echo "vault version: " `vault version`
    fi

    if [[ -z "${POD_NAMESPACE}" ]]; then
        echo "Use the 'downward api' to define the pod's namespace as POD_NAMESPACE! Exiting..."
        exit 1
    fi

    if [[ -z "${VAULT_ADDR}" ]]; then
        VAULT_ADDR=https://vault.dst.cloud
    fi

    if [[ -z "${GIT_REPO_UID}" ]]; then
        GIT_REPO_UID=mchudgins
    fi

    if [[ -z "${GIT_REPO_URL}" ]]; then
        GIT_REPO_URL=https://gitlab.com/dstcorp/config.git
    fi

    # we need a vault token to bootstrap our various secrets
    if [[ -z "${VAULT_TOKEN}" ]]; then
        if [[ ! -f ${VAULT_TOKEN_FILE} ]]; then
            echo "Unable to read Vault token. ${VAULT_TOKEN_FILE} is missing. Exiting..."
            exit 1
        fi
        export VAULT_TOKEN=$(cat ${VAULT_TOKEN_FILE})
    fi
    if [[ -z "${VAULT_TOKEN}" ]]; then
        echo "A 'VAULT_TOKEN' is required to obtain the necessary secrets. Exiting..."
        exit 1
    fi

    GIT_REPO_PWORD="$(vault read -address=${VAULT_ADDR} -field=password secret/projects/${POD_NAMESPACE}/gitlab)"
    JKS_KEY="$(vault read -address=${VAULT_ADDR} -field=key secret/projects/${POD_NAMESPACE}/jks)"

    #
    # check if the jks file was previously created, if not construct it
    #
    if [[ ! -r ${KEYSTORE} ]]; then
        echo "Java keystore, ${KEYSTORE}, missing.  Generating it now."

        tmpdir=`mktemp -d`

        cd ${tmpdir}
        url=$(echo ${GIT_REPO_URL} | sed -e "s^https://^https://${GIT_REPO_UID}:${GIT_REPO_PWORD}@^")
        git clone ${url}

        clonedir=`basename ${GIT_REPO_URL} .git`

        if [[ ! -r ${clonedir}/certificates/config.dst.cloud.pem ]]; then
            echo "Unable to locate public key file certificates/config.dst.cloud.pem! Exiting..."
            exit 1
        fi
        if [[ ! -r ${clonedir}/certificates/ucap-ca-bundle.pem ]]; then
            echo "Unable to locate chain file certificates/ucap-ca-bundle.pem! Exiting..."
            exit 1
        fi

        # bundle the private key, public key, and chain together into one big file
        vault read -address=${VAULT_ADDR} -field=key secret/certificates/config.dst.cloud | \
            cat -s ${clonedir}/certificates/config.dst.cloud.pem ${clonedir}/certificates/ucap-ca-bundle.pem - >cert.pem

        # create the keystore
        export JKS_KEY
        openssl pkcs12 -export -in cert.pem -out ${KEYSTORE} \
            -name config-server -passout env:JKS_KEY

        cd -
        rm -rf ${tmpdir}
    fi

	#APPFLAGS="-Djava.security.egd=file:/dev/./urandom -Djavax.net.debug=ssl -Dhttps.protocols=TLSv1.2"
	APPFLAGS="-Djava.security.egd=file:/dev/./urandom -Dhttps.protocols=TLSv1.2"
	APPFLAGS="${APPFLAGS} -javaagent:/usr/local/bin/jmx_prometheus_javaagent-0.2.0.jar=9100:/usr/local/etc/jmx-exporter.yaml"
	if [[ -n "$GIT_REPO_URL" ]]; then
		APPFLAGS="${APPFLAGS} -Dspring.cloud.config.server.git.uri=${GIT_REPO_URL}"
	fi

    cat <<EOF >application.properties
server.port=8443
server.ssl.enabled=true
server.ssl.protocol=TLSv1.2
server.ssl.ciphers=TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384,TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
server.ssl.key-store=file://${KEYSTORE}
server.ssl.key-store-password=${JKS_KEY}
server.ssl.keyStoreType=PKCS12
server.ssl.keyAlias=config-server
spring.cloud.config.server.git.uri=${GIT_REPO_URL}
spring.cloud.config.server.git.username=${GIT_REPO_UID}
spring.cloud.config.server.git.password=${GIT_REPO_PWORD}
EOF

	exec java ${APPFLAGS} -jar ${APPJAR}
fi

exec "$@"
