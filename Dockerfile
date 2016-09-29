FROM frolvlad/alpine-glibc
MAINTAINER Alexander Groß <agross@therightstuff.de>

COPY ./docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["youtrack", "run"]

EXPOSE 8080

WORKDIR /youtrack

RUN YOUTRACK_VERSION=7.0.27477 && \
    YOUTRACK_VERSION_PATCH=${YOUTRACK_VERSION##*.} && \
    \
    echo Creating youtrack user and group with static ID of 5000 && \
    addgroup -g 5000 -S youtrack && \
    adduser -g "JetBrains YouTrack" -S -h "$(pwd)" -u 5000 -G youtrack youtrack && \
    \
    echo Installing packages && \
    apk add --update coreutils \
                     bash \
                     wget \
                     ca-certificates && \
    \
    DOWNLOAD_URL=https://download.jetbrains.com/charisma/youtrack-$YOUTRACK_VERSION.zip && \
    echo Downloading $DOWNLOAD_URL to $(pwd) && \
    wget "$DOWNLOAD_URL" --progress bar:force:noscroll --output-document youtrack.zip && \
    \
    echo Extracting to $(pwd) && \
    unzip ./youtrack.zip \
      -d . \
      -x youtrack-$YOUTRACK_VERSION_PATCH/internal/java/linux-amd64/man/* \
         youtrack-$YOUTRACK_VERSION_PATCH/internal/java/windows-amd64/* \
         youtrack-$YOUTRACK_VERSION_PATCH/internal/java/mac-x64/* && \
    rm -f youtrack.zip && \
    mv youtrack-$YOUTRACK_VERSION_PATCH/* . && \
    rm -rf youtrack-$YOUTRACK_VERSION_PATCH && \
    \
    chown -R youtrack:youtrack . && \
    chmod +x /docker-entrypoint.sh \
             ./internal/java/linux-x64/jre/bin/java

USER youtrack
