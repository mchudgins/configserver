FROM java:8-jre

EXPOSE 8888

ENTRYPOINT ["/entrypoint.sh"]

CMD [ "runapp" ]

RUN mkdir -p /target/config \
	&& chmod ugo+rw /target \
	&& chmod ugo+rw /usr/local/etc

COPY docker-entrypoint.sh /entrypoint.sh
COPY vault /usr/local/bin
RUN chmod +x /usr/local/bin/vault
COPY jmx_prometheus_javaagent-0.2.0.jar /usr/local/bin

ADD configserver-0.0.2-SNAPSHOT.jar /app.jar

