# Stage 1: Build iSantePlus-specific modules from source
# These are not in public Maven repos — we clone and build them.
FROM maven:3.8-eclipse-temurin-8 AS module-builder

WORKDIR /modules

# Clone and build each iSantePlus module from the IsantePlus GitHub org
RUN git clone --depth 1 https://github.com/IsantePlus/openmrs-module-isanteplus-old.git && \
    cd openmrs-module-isanteplus-old && mvn clean package -B -DskipTests -q && \
    cp omod/target/*.omod /modules/ && cd /modules && rm -rf openmrs-module-isanteplus-old

RUN git clone --depth 1 https://github.com/IsantePlus/openmrs-module-xds-sender.git && \
    cd openmrs-module-xds-sender && mvn clean package -B -DskipTests -q && \
    cp omod/target/*.omod /modules/ && cd /modules && rm -rf openmrs-module-xds-sender

RUN git clone --depth 1 https://github.com/IsantePlus/openmrs-module-mpi-client.git && \
    cd openmrs-module-mpi-client && mvn clean package -B -DskipTests -q && \
    cp omod/target/*.omod /modules/ && cd /modules && rm -rf openmrs-module-mpi-client

RUN git clone --depth 1 https://github.com/IsantePlus/openmrs-module-outgoing-exception.git && \
    cd openmrs-module-outgoing-exception && mvn clean package -B -DskipTests -q && \
    cp omod/target/*.omod /modules/ && cd /modules && rm -rf openmrs-module-outgoing-exception

RUN git clone --depth 1 https://github.com/IsantePlus/openmrs-module-m2sys-biometrics.git && \
    cd openmrs-module-m2sys-biometrics && mvn clean package -B -DskipTests -q && \
    cp omod/target/*.omod /modules/ && cd /modules && rm -rf openmrs-module-m2sys-biometrics

RUN git clone --depth 1 https://github.com/IsantePlus/openmrs-module-haiticore.git && \
    cd openmrs-module-haiticore && mvn clean package -B -DskipTests -q && \
    cp omod/target/*.omod /modules/ && cd /modules && rm -rf openmrs-module-haiticore

RUN git clone --depth 1 https://github.com/IsantePlus/openmrs-module-isanteplusreports.git && \
    cd openmrs-module-isanteplusreports && mvn clean package -B -DskipTests -q && \
    cp omod/target/*.omod /modules/ && cd /modules && rm -rf openmrs-module-isanteplusreports

RUN git clone --depth 1 https://github.com/IsantePlus/openmrs-module-labintegration.git && \
    cd openmrs-module-labintegration && mvn clean package -B -DskipTests -q && \
    cp omod/target/*.omod /modules/ && cd /modules && rm -rf openmrs-module-labintegration

# Modules that may not have their own repos — keep as pre-built .omod
COPY docker/custom-modules/addresshierarchy-*.omod /modules/
COPY docker/custom-modules/patientflags-*.omod /modules/
COPY docker/custom-modules/referencemetadata-*.omod /modules/

RUN ls -la /modules/*.omod


# Stage 2: Build the distribution using Maven
FROM maven:3.8-eclipse-temurin-8 AS distro-builder

WORKDIR /app
COPY pom.xml .
COPY package/ package/

# Pre-install all built modules into local Maven cache
COPY --from=module-builder /modules/*.omod /custom-modules/
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

# Overlay freshly built modules (replace Maven-resolved versions)
COPY --from=module-builder /modules/*.omod /app/package/target/distro/web/modules/


# Stage 3: Runtime image
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

# Copy built distribution from distro-builder stage
COPY --from=distro-builder /app/package/target/distro/web/openmrs.war /openmrs/distribution/openmrs_webapps/openmrs.war
COPY --from=distro-builder /app/package/target/distro/web/modules /openmrs/distribution/openmrs_modules

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
