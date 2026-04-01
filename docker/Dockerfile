# Stage 1: Build the distribution using Maven
FROM maven:3.8-eclipse-temurin-8 AS build

ARG ISANTEPLUS_VERSION=v2.3.6

WORKDIR /app
COPY pom.xml .
COPY package/ package/

# Build the distribution (downloads all modules via Maven)
RUN mvn clean package -U -B -DskipTests

# Rename modules with incorrect artifact names
WORKDIR /app/package/target/distro/web/modules
RUN apt-get update && apt-get install -y --no-install-recommends rename && rm -rf /var/lib/apt/lists/*
RUN rename 's/m2sys-(.+).omod$/m2sys-biometrics-$1\.omod/' *.omod || true
RUN rename 's/outgoing-(.+).omod$/outgoing-message-exceptions-$1\.omod/' *.omod || true
RUN rename 's/xds-(.+).omod$/xds-sender-$1\.omod/' *.omod || true
RUN rename 's/santedb-(.+).omod$/santedb-mpiclient-$1\.omod/' *.omod || true

# Replace modules that need custom versions from upstream
RUN rm -f addresshierarchy* && \
    wget -q https://github.com/IsantePlus/isanteplus_installation/raw/main/modules/addresshierarchy-2.11.0-SNAPSHOT.omod
RUN rm -f patientflags* && \
    wget -q https://github.com/IsantePlus/isanteplus_installation/raw/main/modules/patientflags-2.0.0-SNAPSHOT.omod


# Stage 2: Runtime image
# Use tomcat:7-jre8-slim on a newer base to avoid expired Debian repos
FROM tomcat:7.0.109-jdk8-adoptopenjdk-hotspot

RUN rm -rf /usr/local/tomcat/webapps/*

# Tomcat config: UTF-8 encoding and relaxed URL characters
RUN sed -i '/Connector port="8080"/a URIEncoding="UTF-8" relaxedPathChars="[]|" relaxedQueryChars="[]|{}^&#x5c;&#x60;&quot;&lt;&gt;"' \
    /usr/local/tomcat/conf/server.xml

# Environment variables for OpenMRS configuration
ENV OMRS_JAVA_MEMORY_OPTS="-Xmx2048m -Xms512m -XX:NewSize=256m"
ENV OMRS_JAVA_SERVER_OPTS="-Dfile.encoding=UTF-8 -server -Djava.security.egd=file:/dev/./urandom -Djava.awt.headless=true -Djava.awt.headlesslib=true"
ENV OMRS_CONFIG_ADD_DEMO_DATA="false"
ENV OMRS_CONFIG_ADMIN_USER_PASSWORD="Admin123"
ENV OMRS_CONFIG_AUTO_UPDATE_DATABASE="true"
ENV OMRS_CONFIG_CONNECTION_TYPE="mysql"
ENV OMRS_CONFIG_CONNECTION_USERNAME="openmrs"
ENV OMRS_CONFIG_CONNECTION_PASSWORD="openmrs"
ENV OMRS_CONFIG_CONNECTION_SERVER="localhost"
ENV OMRS_CONFIG_CONNECTION_NAME="openmrs"
ENV OMRS_CONFIG_CREATE_DATABASE_USER="false"
ENV OMRS_CONFIG_CREATE_TABLES="false"
ENV OMRS_CONFIG_HAS_CURRENT_OPENMRS_DATABASE="true"
ENV OMRS_CONFIG_INSTALL_METHOD="auto"
ENV OMRS_CONFIG_MODULE_WEB_ADMIN="true"
ENV OMRS_DEV_DEBUG_PORT="1044"
ENV OMRS_WEBAPP_NAME="openmrs"

# Copy built distribution from build stage
COPY --from=build /app/package/target/distro/web/openmrs.war /openmrs/distribution/openmrs_webapps/openmrs.war
COPY --from=build /app/package/target/distro/web/modules /openmrs/distribution/openmrs_modules

# Volume for custom modules (overlaid at runtime)
VOLUME ["/custom_modules"]

# Volume for persistent OpenMRS data
VOLUME ["/openmrs/data"]

# Copy startup scripts
COPY docker/startup.sh /usr/local/tomcat/startup.sh
COPY docker/wait-for-it.sh /usr/local/tomcat/wait-for-it.sh
COPY docker/post-start.sh /usr/local/tomcat/post-start.sh
RUN chmod +x /usr/local/tomcat/startup.sh \
    /usr/local/tomcat/wait-for-it.sh \
    /usr/local/tomcat/post-start.sh

EXPOSE 8080

ENTRYPOINT ["/usr/local/tomcat/startup.sh"]
