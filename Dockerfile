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

ARG VERSION
ARG GITHUB_SHA
ARG BUILD_DATE

LABEL maintainer="Jake Wharton <docker@jakewharton.com>" \
      org.opencontainers.image.title="plex-auto-trash" \
      org.opencontainers.image.description="Automatically empty the trash in all of your Plex libraries." \
      org.opencontainers.image.url="https://github.com/thatbritguy/plex-auto-trash" \
      org.opencontainers.image.source="https://github.com/thatbritguy/plex-auto-trash" \
      org.opencontainers.image.version="${VERSION:-dev}" \
      org.opencontainers.image.revision="${GITHUB_SHA:-manual}" \
      org.opencontainers.image.created="${BUILD_DATE:-1970-01-01T00:00:00Z}" \
			org.opencontainers.image.licenses="Apache-2.0"

ENTRYPOINT ["/init"]

# Default environment variables (same as original)
ENV \
  S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
  CRON="12 * * * *" \
  SCAN_IDLE="5"

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

# Basic local health check for Docker and Dockwatch
HEALTHCHECK --interval=5m --timeout=10s --start-period=30s --retries=3 \
  CMD pgrep -f 'plex-auto-trash' >/dev/null 2>&1 || exit 1
