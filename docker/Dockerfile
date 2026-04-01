# Stage 1: Build the distribution using Maven
# Downloads core OpenMRS modules from the public Maven repo.
# iSantePlus-specific modules are provided as pre-built .omod files
# in docker/custom-modules/ (see docker/MODULES.md for rebuild instructions).
FROM maven:3.8-eclipse-temurin-8 AS build

WORKDIR /app
COPY pom.xml .
COPY package/ package/
COPY docker/custom-modules/ /custom-modules/

# Pre-install iSantePlus modules into local Maven cache
RUN for omod in /custom-modules/*.omod; do \
      name=$(basename "$omod" | sed 's/-[0-9].*//' ); \
      version=$(basename "$omod" | sed "s/${name}-//; s/\.omod//"); \
      echo "Installing $name:$version"; \
      mvn install:install-file \
        -DgroupId=org.openmrs.module \
        -DartifactId=${name}-omod \
        -Dversion=$version \
        -Dpackaging=jar \
        -Dfile="$omod" \
        -DgeneratePom=true \
        -q || true; \
    done

# Build the distribution
RUN mvn clean package -U -B -DskipTests

# Rename modules with incorrect artifact names
WORKDIR /app/package/target/distro/web/modules
RUN apt-get update && apt-get install -y --no-install-recommends rename && rm -rf /var/lib/apt/lists/*
RUN rename 's/m2sys-(.+).omod$/m2sys-biometrics-$1\.omod/' *.omod || true
RUN rename 's/outgoing-(.+).omod$/outgoing-message-exceptions-$1\.omod/' *.omod || true
RUN rename 's/xds-(.+).omod$/xds-sender-$1\.omod/' *.omod || true
RUN rename 's/santedb-(.+).omod$/santedb-mpiclient-$1\.omod/' *.omod || true

# Overlay custom modules (replace Maven-resolved versions with our builds)
COPY docker/custom-modules/ /app/package/target/distro/web/modules/


# Stage 2: Runtime image
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

# Copy built distribution
COPY --from=build /app/package/target/distro/web/openmrs.war /openmrs/distribution/openmrs_webapps/openmrs.war
COPY --from=build /app/package/target/distro/web/modules /openmrs/distribution/openmrs_modules

VOLUME ["/custom_modules"]
VOLUME ["/openmrs/data"]

# Startup scripts
COPY docker/startup.sh /usr/local/tomcat/startup.sh
COPY docker/wait-for-it.sh /usr/local/tomcat/wait-for-it.sh
COPY docker/post-start.sh /usr/local/tomcat/post-start.sh
RUN chmod +x /usr/local/tomcat/startup.sh \
    /usr/local/tomcat/wait-for-it.sh \
    /usr/local/tomcat/post-start.sh

EXPOSE 8080

ENTRYPOINT ["/usr/local/tomcat/startup.sh"]
