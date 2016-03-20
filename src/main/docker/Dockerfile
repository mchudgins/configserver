FROM java:8-jre

EXPOSE 8888

ENTRYPOINT ["/entrypoint.sh"]

CMD [ "runapp" ]

RUN mkdir /target \
	&& chmod ugo+rw /target

COPY docker-entrypoint.sh /entrypoint.sh

ADD configserver-0.0.1-SNAPSHOT.jar /app.jar

