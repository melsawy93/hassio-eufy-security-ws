ARG BUILD_FROM
FROM $BUILD_FROM

ARG EUFY_SECURITY_WS_VERSION

WORKDIR /usr/src/app
RUN \
    set -x \
    && apk add --no-cache \
    nodejs \
    npm \
    jq

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

COPY run.sh /
RUN chmod a+x /run.sh
WORKDIR /data

CMD [ "/run.sh" ]