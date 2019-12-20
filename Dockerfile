FROM frolvlad/alpine-glibc
LABEL maintainer "Alexander Groß <agross@therightstuff.de>"

COPY ./docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["youtrack", "run"]

EXPOSE 8080

WORKDIR /youtrack

HEALTHCHECK --start-period=1m \
            CMD wget --server-response --output-document=/dev/null http://localhost:8080 || exit 1

ARG VERSION=2019.3.62973
ARG DOWNLOAD_URL=https://download.jetbrains.com/charisma/youtrack-$VERSION.zip
ARG SHA_DOWNLOAD_URL=https://download.jetbrains.com/charisma/youtrack-$VERSION.zip.sha256

RUN echo Creating youtrack user and group with static ID of 5000 && \
    addgroup -g 5000 -S youtrack && \
    adduser -g "JetBrains YouTrack" -S -h "$(pwd)" -u 5000 -G youtrack youtrack && \
    \
    echo Installing packages && \
    apk add --update bash \
                     ca-certificates \
                     coreutils \
                     wget && \
    \
    echo Downloading $DOWNLOAD_URL to $(pwd) && \
    wget --progress bar:force:noscroll \
         "$DOWNLOAD_URL" && \
    \
    echo Verifying download && \
    wget --progress bar:force:noscroll \
         --output-document \
         download.sha256 \
         "$SHA_DOWNLOAD_URL" && \
    \
    sha256sum -c download.sha256 && \
    rm download.sha256 && \
    \
    echo Extracting to $(pwd) && \
    unzip ./youtrack-$VERSION.zip \
          -d . \
          -x youtrack-$VERSION/internal/java/linux-amd64/man/* \
             youtrack-$VERSION/internal/java/windows-amd64/* \
             youtrack-$VERSION/internal/java/mac-x64/* && \
    rm youtrack-$VERSION.zip && \
    mv youtrack-$VERSION/* . && \
    rm -r youtrack-$VERSION && \
    \
    chown -R youtrack:youtrack . && \
    chmod +x /docker-entrypoint.sh \
             ./internal/java/linux-x64/bin/java

USER youtrack
