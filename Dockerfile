FROM cogniteev/oracle-java:java8
MAINTAINER Freddie Ho <freddie.ho@gmail.com>

ARG CRUCIBLE_VERSION=4.5.4
# permissions
ARG CONTAINER_UID=1000
ARG CONTAINER_GID=1000

ENV FISHEYE_INST=/var/atlassian/crucible \
    CRUCIBLE_INSTALL=/opt/crucible \
    CRUCIBLE_PROXY_NAME= \
    CRUCIBLE_PROXY_PORT= \
    CRUCIBLE_PROXY_SCHEME= \
    FISHEYE_OPTS=-Dcrucible.review.content.size.limit=1200

RUN export MYSQL_DRIVER_VERSION=5.1.38 && \
    export POSTGRESQL_DRIVER_VERSION=42.1.4 && \
    export CONTAINER_USER=crucible &&  \
    export CONTAINER_GROUP=crucible &&  \
    addgroup --system --gid $CONTAINER_GID $CONTAINER_GROUP &&  \
    adduser -q --system --uid $CONTAINER_UID \
            --gid $CONTAINER_GID \
            --home /home/$CONTAINER_USER \
            --shell /bin/bash \
            $CONTAINER_USER && \
    # Install tools
    apt-get update --quiet && \
    apt-get install --quiet --yes --no-install-recommends \
        git \
        mercurial \
        subversion \
        openssl \
        ca-certificates \
        unzip \
        curl \
        wget \
        joe \
        libsvn-java \
        xmlstarlet && \
    apt-get clean && \
    # Install Crucible
    mkdir -p ${FISHEYE_INST} && \
    mkdir -p ${CRUCIBLE_INSTALL} && \
    mkdir -p /backup && \
    wget -O /tmp/crucible.zip https://www.atlassian.com/software/crucible/downloads/binary/crucible-${CRUCIBLE_VERSION}.zip && \
    unzip -q -d /tmp /tmp/crucible.zip && \
    mv /tmp/fecru-${CRUCIBLE_VERSION}/* ${CRUCIBLE_INSTALL} && \
    # Install database drivers
    rm -f                                               \
      ${CRUCIBLE_INSTALL}/lib/mysql-connector-java*.jar &&  \
    wget -O /tmp/mysql-connector-java-${MYSQL_DRIVER_VERSION}.tar.gz                                              \
      http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MYSQL_DRIVER_VERSION}.tar.gz && \
    tar xzf /tmp/mysql-connector-java-${MYSQL_DRIVER_VERSION}.tar.gz                                              \
      -C /tmp && \
    cp /tmp/mysql-connector-java-${MYSQL_DRIVER_VERSION}/mysql-connector-java-${MYSQL_DRIVER_VERSION}-bin.jar     \
      ${CRUCIBLE_INSTALL}/lib/mysql-connector-java-${MYSQL_DRIVER_VERSION}-bin.jar                                &&  \
    rm -f ${CRUCIBLE_INSTALL}/lib/postgresql-*.jar                                                                &&  \
    wget -O ${CRUCIBLE_INSTALL}/lib/postgresql-${POSTGRESQL_DRIVER_VERSION}.jar                                       \
      https://jdbc.postgresql.org/download/postgresql-${POSTGRESQL_DRIVER_VERSION}.jar && \
    # Adding letsencrypt-ca to truststore
    # Adding letsencrypt-ca to truststore
    export KEYSTORE=$JAVA_HOME/jre/lib/security/cacerts && \
    wget -P /tmp/ https://letsencrypt.org/certs/letsencryptauthorityx1.der && \
    wget -P /tmp/ https://letsencrypt.org/certs/letsencryptauthorityx2.der && \
    wget -P /tmp/ https://letsencrypt.org/certs/lets-encrypt-x1-cross-signed.der && \
    wget -P /tmp/ https://letsencrypt.org/certs/lets-encrypt-x2-cross-signed.der && \
    wget -P /tmp/ https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.der && \
    wget -P /tmp/ https://letsencrypt.org/certs/lets-encrypt-x4-cross-signed.der && \
    keytool -trustcacerts -keystore $KEYSTORE -storepass changeit -noprompt -importcert -alias isrgrootx1 -file /tmp/letsencryptauthorityx1.der && \
    keytool -trustcacerts -keystore $KEYSTORE -storepass changeit -noprompt -importcert -alias isrgrootx2 -file /tmp/letsencryptauthorityx2.der && \
    keytool -trustcacerts -keystore $KEYSTORE -storepass changeit -noprompt -importcert -alias letsencryptauthorityx1 -file /tmp/lets-encrypt-x1-cross-signed.der && \
    keytool -trustcacerts -keystore $KEYSTORE -storepass changeit -noprompt -importcert -alias letsencryptauthorityx2 -file /tmp/lets-encrypt-x2-cross-signed.der && \
    keytool -trustcacerts -keystore $KEYSTORE -storepass changeit -noprompt -importcert -alias letsencryptauthorityx3 -file /tmp/lets-encrypt-x3-cross-signed.der && \
    keytool -trustcacerts -keystore $KEYSTORE -storepass changeit -noprompt -importcert -alias letsencryptauthorityx4 -file /tmp/lets-encrypt-x4-cross-signed.der && \
    # Install atlassian ssl tool
    wget -O /home/${CONTAINER_USER}/SSLPoke.class https://confluence.atlassian.com/kb/files/779355358/779355357/1/1441897666313/SSLPoke.class && \
    # Container user permissions
    chown -R crucible:crucible /home/${CONTAINER_USER} && \
    chown -R crucible:crucible ${FISHEYE_INST} && \
    chmod -R u=rwx,g=rwx,o=-rwx ${CRUCIBLE_INSTALL} && \
    chown -R crucible:crucible ${CRUCIBLE_INSTALL} && \
    # Install Tini Zombie Reaper And Signal Forwarder
    export TINI_VERSION=0.9.0 && \
    curl -fsSL https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-static -o /bin/tini && \
    chmod +x /bin/tini && \
    # Clean caches and tmps
    rm -rf /var/cache/apk/* && \
    rm -rf /tmp/* && \
    rm -rf /var/log/*

USER crucible
WORKDIR /var/atlassian/crucible
VOLUME ["/var/atlassian/crucible", "/backup]
# Port for http://
EXPOSE 8060
# Port for https://
EXPOSE 8063
COPY imagescripts /home/crucible
ENTRYPOINT ["/bin/tini","--","/home/crucible/docker-entrypoint.sh"]
CMD ["crucible"]
