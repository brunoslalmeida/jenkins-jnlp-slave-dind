FROM jenkins/inbound-agent as builder

FROM docker:dind

COPY --from=builder /usr/local/bin/jenkins-slave /usr/local/bin/jenkins-agent
COPY --from=builder /usr/share/jenkins/agent.jar /usr/share/jenkins/agent.jar

ARG user=jenkins
ARG group=jenkins
ARG uid=10000
ARG gid=10000

ARG AGENT_WORKDIR=/home/${user}/agent

USER root

ENV LANG C.UTF-8

ENV JAVA_HOME /usr/lib/jvm/java-1.8-openjdk/jre
ENV PATH $PATH:/usr/lib/jvm/java-1.8-openjdk/jre/bin:/usr/lib/jvm/java-1.8-openjdk/bin

ENV HOME /home/${user}

COPY docker-entrypoint.sh /docker-entrypoint.sh

RUN apk add --no-cache \
        go \
        git \
        nss \
        gcc \
        make \
        bash \
        curl \
        glib \
        curl \
        sudo \
        bash \
        yarn \
        unzip \
        nodejs \
        py-pip \
        procps \
        openssl \
        git-lfs \
        openssh \
        chromium \
        musl-dev \
        freetype \
        musl-dev \
        harfbuzz \
        openjdk8 \
        libffi-dev \
        nodejs-npm \
        python3-dev \
        openssl-dev \
        ttf-freefont \
        freetype-dev \
        openssh-client \
        ca-certificates \
        chromium-chromedriver

ENV GOROOT /usr/lib/go
ENV GOPATH /go
ENV PATH /go/bin:$PATH

# download and install Kotlin compiler
# https://github.com/JetBrains/kotlin/releases/latest
ARG KOTLIN_VERSION=1.4.10
RUN cd /opt && \
    wget -q https://github.com/JetBrains/kotlin/releases/download/v${KOTLIN_VERSION}/kotlin-compiler-${KOTLIN_VERSION}.zip && \
    unzip *kotlin*.zip && \
    rm *kotlin*.zip

# download and install Android SDK
# https://developer.android.com/studio#command-tools
ARG ANDROID_SDK_VERSION=6858069
ENV ANDROID_SDK_ROOT /opt/android-sdk
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_VERSION}_latest.zip && \
    unzip *tools*linux*.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools && \
    mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/tools && \
    rm *tools*linux*.zip

ENV GRADLE_HOME /opt/gradle
ENV KOTLIN_HOME /opt/kotlinc
ENV PATH ${PATH}:${GRADLE_HOME}/bin:${KOTLIN_HOME}/bin:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/cmdline-tools/tools/bin:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/emulator

RUN mkdir -p ${GOPATH}/src ${GOPATH}/bin \
  && go get github.com/github-release/github-release

RUN pip install --upgrade docker-compose pip \
  && addgroup -g ${gid} ${group} \
  && adduser -D -h $HOME -u ${uid} -G ${group} ${user} \
  && chmod 755 /docker-entrypoint.sh \
  && rm -rf /var/cache/apk/* \
  && chmod +x /usr/local/bin/jenkins-agent \
  && chmod 644 /usr/share/jenkins/agent.jar \
  && ln -s /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-slave \
  && ln -sf /usr/share/jenkins/agent.jar /usr/share/jenkins/slave.jar 

RUN mkdir -p /opt/fossa \
  && cd /tmp \
  && curl -H 'Cache-Control: no-cache' https://raw.githubusercontent.com/fossas/fossa-cli/master/install.sh | BINDIR=/opt/fossa bash \
  && ln -s /opt/fossa/fossa /usr/local/bin/fossa \
  && chmod +x /usr/local/bin/fossa 

ENV SONAR_VERSION 4.4.0.2170

RUN mkdir -p /opt/sonnar \
 && curl -H 'Cache-Control: no-cache ' https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_VERSION}-linux.zip  -o sonar-scanner-cli-${SONAR_VERSION}-linux.zip \
 && unzip sonar-scanner-cli-${SONAR_VERSION}-linux.zip \
 && rm sonar-scanner-cli-${SONAR_VERSION}-linux.zip \
 && mv /sonar-scanner-${SONAR_VERSION}-linux /opt/sonnar \
 && ln -s /opt/sonnar/sonar-scanner-${SONAR_VERSION}-linux/bin/sonar-scanner /usr/local/bin/sonar-scanner \
 && chmod +x /usr/local/bin/sonar-scanner \
 && rm /opt/sonnar/sonar-scanner-${SONAR_VERSION}-linux/jre/bin/java \
 && ln -s /usr/bin/java /opt/sonnar/sonar-scanner-${SONAR_VERSION}-linux/jre/bin/java

RUN curl -LO -H 'Cache-Control: no-cache' "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl" \
 && mv kubectl /usr/local/bin \
 && chmod +x /usr/local/bin/kubectl

# Tell Puppeteer to skip installing Chrome. We'll be using the installed package.
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Puppeteer v1.19.0 works with Chromium 77.
RUN yarn add puppeteer@1.19.0

#fixing android build
#https://stackoverflow.com/questions/44344656/aapt2-failing-to-merge-resources-on-docker/49936412#49936412
#https://github.com/Docker-Hub-frolvlad/docker-alpine-glibc/blob/master/Dockerfile
ENV LANG=C.UTF-8

# Here we install GNU libc (aka glibc) and set C.UTF-8 locale as default.
RUN ALPINE_GLIBC_BASE_URL="https://github.com/sgerrand/alpine-pkg-glibc/releases/download" && \
    ALPINE_GLIBC_PACKAGE_VERSION="2.32-r0" && \
    ALPINE_GLIBC_BASE_PACKAGE_FILENAME="glibc-$ALPINE_GLIBC_PACKAGE_VERSION.apk" && \
    ALPINE_GLIBC_BIN_PACKAGE_FILENAME="glibc-bin-$ALPINE_GLIBC_PACKAGE_VERSION.apk" && \
    ALPINE_GLIBC_I18N_PACKAGE_FILENAME="glibc-i18n-$ALPINE_GLIBC_PACKAGE_VERSION.apk" && \
    apk add --no-cache --virtual=.build-dependencies wget ca-certificates && \
    echo \
        "-----BEGIN PUBLIC KEY-----\
        MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApZ2u1KJKUu/fW4A25y9m\
        y70AGEa/J3Wi5ibNVGNn1gT1r0VfgeWd0pUybS4UmcHdiNzxJPgoWQhV2SSW1JYu\
        tOqKZF5QSN6X937PTUpNBjUvLtTQ1ve1fp39uf/lEXPpFpOPL88LKnDBgbh7wkCp\
        m2KzLVGChf83MS0ShL6G9EQIAUxLm99VpgRjwqTQ/KfzGtpke1wqws4au0Ab4qPY\
        KXvMLSPLUp7cfulWvhmZSegr5AdhNw5KNizPqCJT8ZrGvgHypXyiFvvAH5YRtSsc\
        Zvo9GI2e2MaZyo9/lvb+LbLEJZKEQckqRj4P26gmASrZEPStwc+yqy1ShHLA0j6m\
        1QIDAQAB\
        -----END PUBLIC KEY-----" | sed 's/   */\n/g' > "/etc/apk/keys/sgerrand.rsa.pub" && \
    wget \
        "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
        "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
        "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_I18N_PACKAGE_FILENAME" && \
    apk add --no-cache \
        "$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
        "$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
        "$ALPINE_GLIBC_I18N_PACKAGE_FILENAME" && \
    \
    rm "/etc/apk/keys/sgerrand.rsa.pub" && \
    /usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 "$LANG" || true && \
    echo "export LANG=$LANG" > /etc/profile.d/locale.sh && \
    \
    apk del glibc-i18n && \
    \
    apk del .build-dependencies && \
    rm \
        "$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
        "$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
        "$ALPINE_GLIBC_I18N_PACKAGE_FILENAME"

USER ${user}
ENV AGENT_WORKDIR=${AGENT_WORKDIR}
RUN mkdir /home/${user}/.jenkins && mkdir -p ${AGENT_WORKDIR}

VOLUME /home/${user}/.jenkins
VOLUME ${AGENT_WORKDIR}
WORKDIR /home/${user}

USER root
ENTRYPOINT ["/docker-entrypoint.sh"]
