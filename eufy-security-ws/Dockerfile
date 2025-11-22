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

# Create package.json first
RUN echo '{ \
      "name": "eufy-security-ws-installer", \
      "version": "1.0.0", \
      "dependencies": { \
        "eufy-security-ws": "'${EUFY_SECURITY_WS_VERSION}'" \
      } \
    }' > package.json

# Install eufy-security-ws first (without the override)
RUN npm install --force

# Clone eufy-security-client from GitHub fork directly into node_modules to get full source
RUN rm -rf node_modules/eufy-security-client && \
    git clone --depth 1 --branch add-c30-support https://github.com/melsawy93/eufy-security-client.git node_modules/eufy-security-client && \
    cd node_modules/eufy-security-client && \
    rm -rf .git

# Build eufy-security-client if it's installed from GitHub (it needs to be built)
RUN if [ -d "node_modules/eufy-security-client" ]; then \
        echo "=== Building eufy-security-client from GitHub source ===" && \
        cd node_modules/eufy-security-client && \
        if [ -f "package.json" ]; then \
            echo "Checking available files..." && \
            ls -la | head -20 && \
            echo "Installing dev dependencies..." && \
            npm install --include=dev && \
            echo "Checking for source files and tsconfig..." && \
            if [ -d "src" ]; then \
                echo "Source directory found, creating tsconfig files..." && \
                if [ ! -f "tsconfig.json" ]; then \
                    echo "Creating tsconfig.json..." && \
                    echo '{ \
                        "compileOnSave": true, \
                        "compilerOptions": { \
                            "noEmit": true, \
                            "allowJs": true, \
                            "checkJs": true, \
                            "skipLibCheck": true, \
                            "noEmitOnError": true, \
                            "outDir": "./build/", \
                            "removeComments": false, \
                            "module": "Node16", \
                            "moduleResolution": "Node16", \
                            "resolveJsonModule": true, \
                            "esModuleInterop": true, \
                            "forceConsistentCasingInFileNames": true, \
                            "jsx": "react", \
                            "strict": true, \
                            "target": "ES2022", \
                            "lib": ["ES2023", "DOM"], \
                            "sourceMap": true, \
                            "inlineSourceMap": false \
                        }, \
                        "include": ["src/**/*.ts"], \
                        "exclude": ["build/**", "node_modules/**"] \
                    }' > tsconfig.json; \
                fi && \
                if [ ! -f "tsconfig.build.json" ]; then \
                    echo "Creating tsconfig.build.json..." && \
                    echo '{ \
                        "extends": "./tsconfig.json", \
                        "compilerOptions": { \
                            "allowJs": false, \
                            "checkJs": false, \
                            "noEmit": false, \
                            "declaration": true, \
                            "outDir": "./build" \
                        }, \
                        "include": ["src/**/*.ts"], \
                        "exclude": ["src/**/*.test.ts"] \
                    }' > tsconfig.build.json; \
                fi && \
                echo "Building from source..." && \
                npm run build; \
            elif [ -f "build/index.js" ]; then \
                echo "Pre-built package detected, build/index.js already exists"; \
            else \
                echo "ERROR: No source directory or build output found!" && \
                ls -la && \
                exit 1; \
            fi && \
            echo "Build completed successfully"; \
        else \
            echo "ERROR: package.json not found!" && exit 1; \
        fi && \
        cd /usr/src/app && \
        echo "=== Verifying build output ===" && \
        if [ -f "node_modules/eufy-security-client/build/index.js" ]; then \
            echo "✓ Build output found at build/index.js"; \
        else \
            echo "✗ ERROR: Build output not found!" && \
            echo "Listing build directory:" && \
            ls -la node_modules/eufy-security-client/build/ 2>/dev/null || echo "Build directory does not exist" && \
            exit 1; \
        fi; \
    fi

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