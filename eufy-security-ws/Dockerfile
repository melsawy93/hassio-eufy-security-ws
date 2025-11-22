ARG BUILD_FROM
FROM $BUILD_FROM

ARG EUFY_SECURITY_WS_VERSION

WORKDIR /usr/src/app
RUN \
    set -x \
    && apk add --no-cache \
    nodejs \
    npm \
    jq \
    git

# Create package.json with override to use GitHub fork
RUN echo '{ \
      "name": "eufy-security-ws-installer", \
      "version": "1.0.0", \
      "dependencies": { \
        "eufy-security-ws": "'${EUFY_SECURITY_WS_VERSION}'" \
      }, \
      "overrides": { \
        "eufy-security-client": "github:melsawy93/eufy-security-client#add-c30-support" \
      } \
    }' > package.json

RUN npm install --force

# Verify that eufy-security-client is installed from GitHub fork
RUN echo "=== Verifying eufy-security-client installation ===" && \
    cat package.json && \
    echo "" && \
    echo "=== Checking installed eufy-security-client package ===" && \
    if [ -f "node_modules/eufy-security-client/package.json" ]; then \
        echo "Package found! Checking source..." && \
        cat node_modules/eufy-security-client/package.json | grep -E '"name"|"version"|"repository"|"_resolved"' || true && \
        echo "" && \
        echo "=== Checking if it's from GitHub ===" && \
        (cat node_modules/eufy-security-client/package.json | grep -q "melsawy93" && echo "✓ CONFIRMED: Using GitHub fork (melsawy93)" || echo "✗ WARNING: Not from expected GitHub fork") || true; \
    else \
        echo "✗ ERROR: eufy-security-client package.json not found!"; \
    fi && \
    echo "" && \
    echo "=== Checking package-lock.json ===" && \
    (cat package-lock.json | grep -A 5 '"eufy-security-client"' | head -10 || echo "Could not find in package-lock.json")

COPY run.sh /
RUN chmod a+x /run.sh
WORKDIR /data

CMD [ "/run.sh" ]