# Stage 1 – build the binary using Azul JDK (multi-arch)
FROM azul/zulu-openjdk-alpine:25-latest AS build
ENV GRADLE_OPTS="-Dorg.gradle.daemon=false -Dkotlin.incremental=false"
WORKDIR /app

# Copy Gradle wrapper and verify environment
COPY gradlew settings.gradle ./
COPY gradle ./gradle
RUN ./gradlew --version

# Build project
COPY build.gradle ./
COPY src ./src
RUN ./gradlew build

# Stage 2 – runtime container using a proper multi-arch base
FROM ghcr.io/linuxserver/baseimage-alpine:3.19
LABEL maintainer="Jake Wharton <docker@jakewharton.com>"
ENTRYPOINT ["/init"]

# Default environment variables (same as original)
ENV \
  S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
  CRON="12 * * * *" \
  SCAN_IDLE="5" \
  HEALTHCHECK_ID="" \
  HEALTHCHECK_HOST="https://hc-ping.com"

# Install dependencies
RUN apk add --no-cache \
      curl \
      openjdk8-jre \
 && rm -rf /var/cache/* \
 && mkdir /var/cache/apk

# Copy init and cron scripts
COPY root/ /
RUN chmod +x /etc/cont-init.d/10-cron.sh /etc/services.d/cron/run

# Copy built app from previous stage
WORKDIR /app
COPY --from=build /app/build/install/plex-auto-trash ./
