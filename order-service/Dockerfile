FROM eclipse-temurin:17-jre
WORKDIR /app
ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} app.jar
EXPOSE 8083
ENTRYPOINT ["sh","-c","java -Djava.security.egd=file:/dev/./urandom -jar /app/app.jar"]

