FROM java:8-jre
ADD configserver-0.0.1-SNAPSHOT.jar /app.jar
EXPOSE 8888

ENTRYPOINT ["/entrypoint.sh"]

CMD [ "runapp" ]

COPY docker-entrypoint.sh /entrypoint.sh
