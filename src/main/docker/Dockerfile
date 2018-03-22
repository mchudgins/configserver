FROM openjdk:9-jre

EXPOSE 8443
EXPOSE 9100

ENTRYPOINT ["/entrypoint.sh"]

CMD [ "runapp" ]

RUN apt-get update -y \
    && apt-get install --no-install-recommends -y git \
    && mkdir -p /target/config \
	&& chmod ugo+rw /target \
	&& mkdir /config \
	&& chmod ugo+rw /config \
	&& chmod ugo+rw /usr/local/etc \
	&& apt-get clean \
	&& rm -rf /tmp/*

RUN curl -sL https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.2.0/jmx_prometheus_javaagent-0.2.0.jar \
        -o /usr/local/bin/jmx_prometheus_javaagent-0.2.0.jar \
    && echo "ssl: false" >/usr/local/etc/jmx-exporter.yaml

COPY dst-root.crt /usr/local/share/ca-certificates
RUN update-ca-certificates
COPY vault /usr/local/bin
RUN chmod +x /usr/local/bin/vault

COPY docker-entrypoint.sh /entrypoint.sh

ADD app.jar /app.jar

