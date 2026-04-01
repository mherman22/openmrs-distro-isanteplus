#!/bin/bash -eu

echo "Initiating OpenMRS startup"

OMRS_HOME="/openmrs"
OMRS_WEBAPP_NAME=${OMRS_WEBAPP_NAME:-openmrs}

OMRS_DISTRO_DIR="$OMRS_HOME/distribution"
OMRS_DISTRO_WEBAPPS="$OMRS_DISTRO_DIR/openmrs_webapps"
OMRS_DISTRO_MODULES="$OMRS_DISTRO_DIR/openmrs_modules"
OMRS_DISTRO_CUSTOM_MODULES="/custom_modules"

OMRS_DATA_DIR="$OMRS_HOME/data"
OMRS_MODULES_DIR="$OMRS_DATA_DIR/modules"

OMRS_SERVER_PROPERTIES_FILE="$OMRS_HOME/$OMRS_WEBAPP_NAME-server.properties"
OMRS_RUNTIME_PROPERTIES_FILE="$OMRS_DATA_DIR/$OMRS_WEBAPP_NAME-runtime.properties"

TOMCAT_DIR="/usr/local/tomcat"
TOMCAT_WEBAPPS_DIR="$TOMCAT_DIR/webapps"
TOMCAT_WORK_DIR="$TOMCAT_DIR/work"
TOMCAT_TEMP_DIR="$TOMCAT_DIR/temp"
TOMCAT_SETENV_FILE="$TOMCAT_DIR/bin/setenv.sh"

# Clear previous artifacts
echo "Clearing out existing directories"
rm -fR $TOMCAT_WEBAPPS_DIR
rm -fR $OMRS_MODULES_DIR
rm -fR $TOMCAT_WORK_DIR
rm -fR $TOMCAT_TEMP_DIR

# Copy distribution artifacts
echo "Loading artifacts into appropriate locations"
cp -r $OMRS_DISTRO_WEBAPPS $TOMCAT_WEBAPPS_DIR
[ -d "$OMRS_DISTRO_MODULES" ] && cp -r $OMRS_DISTRO_MODULES $OMRS_MODULES_DIR
[ -d "$OMRS_DISTRO_CUSTOM_MODULES" ] && cp -rf $OMRS_DISTRO_CUSTOM_MODULES/* $OMRS_MODULES_DIR/ 2>/dev/null && echo "Copied custom modules"

# Database configuration
OMRS_CONFIG_CONNECTION_SERVER="${OMRS_CONFIG_CONNECTION_SERVER:-localhost}"
OMRS_CONFIG_CONNECTION_PORT="${OMRS_CONFIG_CONNECTION_PORT:-3306}"
OMRS_CONFIG_CONNECTION_ARGS="${OMRS_CONFIG_CONNECTION_ARGS:-?autoReconnect=true&sessionVariables=default_storage_engine=InnoDB&useUnicode=true&characterEncoding=UTF-8}"
OMRS_CONFIG_CONNECTION_URL="${OMRS_CONFIG_CONNECTION_URL:-jdbc:mysql://${OMRS_CONFIG_CONNECTION_SERVER}:${OMRS_CONFIG_CONNECTION_PORT}/${OMRS_CONFIG_CONNECTION_NAME}${OMRS_CONFIG_CONNECTION_ARGS}}"

# Write server properties
echo "Writing $OMRS_SERVER_PROPERTIES_FILE"
cat > $OMRS_SERVER_PROPERTIES_FILE << EOF
add_demo_data=${OMRS_CONFIG_ADD_DEMO_DATA}
admin_user_password=${OMRS_CONFIG_ADMIN_USER_PASSWORD}
auto_update_database=${OMRS_CONFIG_AUTO_UPDATE_DATABASE}
connection.driver_class=com.mysql.jdbc.Driver
connection.username=${OMRS_CONFIG_CONNECTION_USERNAME}
connection.password=${OMRS_CONFIG_CONNECTION_PASSWORD}
connection.url=${OMRS_CONFIG_CONNECTION_URL}
create_database_user=${OMRS_CONFIG_CREATE_DATABASE_USER}
create_tables=${OMRS_CONFIG_CREATE_TABLES}
has_current_openmrs_database=${OMRS_CONFIG_HAS_CURRENT_OPENMRS_DATABASE}
install_method=${OMRS_CONFIG_INSTALL_METHOD}
module_web_admin=${OMRS_CONFIG_MODULE_WEB_ADMIN}
module.allow_web_admin=${OMRS_CONFIG_MODULE_WEB_ADMIN}
EOF

# Only overwrite runtime properties if encryption keys are NOT present (first boot).
# On subsequent boots, the runtime properties file contains generated encryption keys
# that must be preserved — overwriting them breaks OpenMRS decryption.
if [ -f "$OMRS_RUNTIME_PROPERTIES_FILE" ] && grep -q "encryption.key" "$OMRS_RUNTIME_PROPERTIES_FILE"; then
  echo "Preserving existing runtime properties (encryption keys present)"
else
  echo "Writing runtime properties (first boot or no encryption keys)"
  cp $OMRS_SERVER_PROPERTIES_FILE $OMRS_RUNTIME_PROPERTIES_FILE
fi

# Write Tomcat environment
echo "Writing $TOMCAT_SETENV_FILE"
JAVA_OPTS="$OMRS_JAVA_SERVER_OPTS $OMRS_JAVA_MEMORY_OPTS"
CATALINA_OPTS="-DOPENMRS_INSTALLATION_SCRIPT=$OMRS_SERVER_PROPERTIES_FILE -DOPENMRS_APPLICATION_DATA_DIRECTORY=$OMRS_DATA_DIR/"

if [ ! -z "${OMRS_DEV_DEBUG_PORT:-}" ]; then
  CATALINA_OPTS="$CATALINA_OPTS -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=$OMRS_DEV_DEBUG_PORT"
fi

cat > $TOMCAT_SETENV_FILE << EOF
export JAVA_OPTS="$JAVA_OPTS"
export CATALINA_OPTS="$CATALINA_OPTS"
EOF

# Wait for MySQL
echo "Waiting for MySQL at ${OMRS_CONFIG_CONNECTION_SERVER}:${OMRS_CONFIG_CONNECTION_PORT}..."
/usr/local/tomcat/wait-for-it.sh --timeout=3600 ${OMRS_CONFIG_CONNECTION_SERVER}:${OMRS_CONFIG_CONNECTION_PORT}

# Start Tomcat
echo "Starting OpenMRS..."
/usr/local/tomcat/bin/catalina.sh run &
TOMCAT_PID=$!

# Trigger first filter to start data importation
sleep 15
curl -sL http://localhost:8080/$OMRS_WEBAPP_NAME/ > /dev/null 2>&1 || true
sleep 15

# Run post-start.sh in the background (configures xds-sender, MPI, etc.)
if [ -f /usr/local/tomcat/post-start.sh ]; then
  /usr/local/tomcat/post-start.sh &
fi

# Wait for Tomcat (not post-start.sh)
wait $TOMCAT_PID
