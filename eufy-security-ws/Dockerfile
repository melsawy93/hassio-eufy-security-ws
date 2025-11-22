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

# Create package.json
RUN echo '{ \
      "name": "eufy-security-ws-installer", \
      "version": "1.0.0", \
      "dependencies": { \
        "eufy-security-ws": "'${EUFY_SECURITY_WS_VERSION}'" \
      } \
    }' > package.json

# Install eufy-security-ws first (without override)
RUN npm cache clean --force && \
    npm install --force --no-audit --prefer-offline=false

# Clone and build eufy-security-client from GitHub fork
RUN echo "=== Cloning eufy-security-client from GitHub fork (cache clear) ===" && \
    cd /tmp && \
    git clone --depth 1 --branch add-c30-support https://github.com/melsawy93/eufy-security-client.git && \
    cd eufy-security-client && \
    echo "=== Installing dependencies (using --force to bypass Node version check) ===" && \
    npm install --include=dev --no-audit --force && \
    echo "=== Building TypeScript ===" && \
    npm run build && \
    echo "=== Copying built package to node_modules ===" && \
    rm -rf /usr/src/app/node_modules/eufy-security-client && \
    cp -r /tmp/eufy-security-client /usr/src/app/node_modules/eufy-security-client && \
    cd /usr/src/app && \
    echo "=== Verifying build output ===" && \
    if [ -f "node_modules/eufy-security-client/build/index.js" ]; then \
        echo "✓ Build output found at build/index.js"; \
    else \
        echo "✗ ERROR: Build output not found!" && \
        ls -la node_modules/eufy-security-client/build/ 2>/dev/null || echo "Build directory does not exist" && \
        exit 1; \
    fi && \
    rm -rf /tmp/eufy-security-client

# Verify that eufy-security-client is installed from GitHub fork
RUN echo "=== Verifying eufy-security-client installation ===" && \
    cat package.json && \
    echo "" && \
    echo "=== Checking installed eufy-security-client package ===" && \
    if [ -f "node_modules/eufy-security-client/package.json" ]; then \
        echo "Package found! Checking source..." && \
        cat node_modules/eufy-security-client/package.json | grep -E '"name"|"version"|"repository"|"_resolved"' || true && \
        echo "" && \
        echo "=== Checking package structure ===" && \
        ls -la node_modules/eufy-security-client/ | head -20 || true && \
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