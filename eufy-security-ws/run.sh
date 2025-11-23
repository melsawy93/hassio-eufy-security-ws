#!/usr/bin/with-contenv bashio

CONFIG_PATH=/data/eufy-security-ws-config.json

USERNAME="$(bashio::config 'username')"
PASSWORD="$(bashio::config 'password')"
COUNTRY="$(bashio::config 'country')"
EVENT_DURATION_SECONDS="$(bashio::config 'event_duration')"
POLLING_INTERVAL_MINUTES="$(bashio::config 'polling_interval')"
ACCEPT_INVITATIONS="$(bashio::config 'accept_invitations')"
TRUSTED_DEVICE_NAME="$(bashio::config 'trusted_device_name')"

COUNTRY_JQ=""
if bashio::config.has_value 'country'; then
    COUNTRY_JQ="country: \$country,"
fi

EVENT_DURATION_SECONDS_JQ=""
if bashio::config.has_value 'event_duration'; then
    EVENT_DURATION_SECONDS_JQ="eventDurationSeconds: \$event_duration_seconds|tonumber,"
fi

POLLING_INTERVAL_MINUTES_JQ=""
if bashio::config.has_value 'polling_interval'; then
    POLLING_INTERVAL_MINUTES_JQ="pollingIntervalMinutes: \$polling_interval_minutes|tonumber,"
fi

ACCEPT_INVITATIONS_JQ=""
if bashio::config.true 'accept_invitations'; then
    ACCEPT_INVITATIONS_JQ="acceptInvitations: \$accept_invitations,"
fi

TRUSTED_DEVICE_NAME_JQ=""
if bashio::config.has_value 'trusted_device_name'; then
    TRUSTED_DEVICE_NAME_JQ="trustedDeviceName: \$trusted_device_name,"
fi

STATION_IP_ADDRESSES_ARG=""
STATION_IP_ADDRESSES_JQ=""
if bashio::config.has_value 'stations'; then
    while read -r data
    do
        TMP_DATA=($(echo "${data}" | tr -d "{}\"[:blank:]" | tr "," " " | sed 's/serial_number://g;s/ip_address://g'))
        if [ "$STATION_IP_ADDRESSES_ARG" = "" ]; then
            STATION_IP_ADDRESSES_ARG="--arg ${TMP_DATA[0]} ${TMP_DATA[1]}"
            STATION_IP_ADDRESSES_JQ="stationIPAddresses: { \$${TMP_DATA[0]}"
        else
            STATION_IP_ADDRESSES_ARG="$STATION_IP_ADDRESSES_ARG --arg ${TMP_DATA[0]} ${TMP_DATA[1]}"
            STATION_IP_ADDRESSES_JQ="$STATION_IP_ADDRESSES_JQ, \$${TMP_DATA[0]}"
        fi
    done <<<"$(bashio::config 'stations')"
    if [ "$STATION_IP_ADDRESSES_ARG" != "" ]; then
        STATION_IP_ADDRESSES_JQ="$STATION_IP_ADDRESSES_JQ }"
    fi
    #bashio::log.info "STATION_IP_ADDRESSES_JQ: ${STATION_IP_ADDRESSES_JQ}"
    #bashio::log.info "STATION_IP_ADDRESSES_ARG: ${STATION_IP_ADDRESSES_ARG}"
fi

PORT_OPTION=""
if bashio::config.has_value 'port'; then
    PORT_OPTION="--port $(bashio::config 'port')"
fi

DEBUG_OPTION=""
if bashio::config.true 'debug'; then
    DEBUG_OPTION="-v"
fi

IPV4_FIRST_NODE_OPTION=""
if bashio::config.true 'ipv4first'; then
    IPV4_FIRST_NODE_OPTION="--dns-result-order=ipv4first"
fi

JSON_STRING="$( jq -n \
  --arg username "$USERNAME" \
  --arg password "$PASSWORD" \
  --arg country "$COUNTRY" \
  --arg event_duration_seconds "$EVENT_DURATION_SECONDS" \
  --arg polling_interval_minutes "$POLLING_INTERVAL_MINUTES" \
  --arg trusted_device_name "$TRUSTED_DEVICE_NAME" \
  --arg accept_invitations "$ACCEPT_INVITATIONS" \
  $STATION_IP_ADDRESSES_ARG \
    "{
      username: \$username,
      password: \$password,
      persistentDir: \"/data\",
      $COUNTRY_JQ
      $EVENT_DURATION_SECONDS_JQ
      $POLLING_INTERVAL_MINUTES_JQ
      $TRUSTED_DEVICE_NAME_JQ
      $ACCEPT_INVITATIONS_JQ
      $STATION_IP_ADDRESSES_JQ
    }"
  )"

check_version() {
    if [ "$1" = "$2" ]; then
        return 1 # equal
    fi
    version=$(printf '%s\n' "$1" "$2" | sort -V | tail -n 1)
    if [ "$version" = "$2" ]; then
        return 2 # greater
    fi
    return 0 # lower
}

if bashio::config.has_value 'username' && bashio::config.has_value 'password'; then
    # Verify eufy-security-client source at runtime
    echo "=== Runtime Verification: Checking eufy-security-client source ==="
    CLIENT_PATH="/usr/src/app/node_modules/eufy-security-client"
    if [ -f "${CLIENT_PATH}/package.json" ]; then
        CLIENT_VERSION=$(cat "${CLIENT_PATH}/package.json" | grep '"version"' | head -1 | sed 's/.*"version": *"\([^"]*\)".*/\1/')
        CLIENT_REPO=$(cat "${CLIENT_PATH}/package.json" | grep -E '"repository"|"_resolved"' | grep -o 'melsawy93' || echo "")
        CLIENT_RESOLVED=$(cat "${CLIENT_PATH}/package.json" | grep '"_resolved"' | head -1 || echo "")
        
        echo "  Package path: ${CLIENT_PATH}"
        echo "  Version: $CLIENT_VERSION"
        echo "  Resolved: $CLIENT_RESOLVED"
        
        if [ -n "$CLIENT_REPO" ]; then
            echo "✓ VERIFIED: Using eufy-security-client from GitHub fork (melsawy93/add-c30-e330-support)"
        else
            echo "⚠ WARNING: eufy-security-client may not be from expected GitHub fork"
            echo "  Showing package.json contents:"
            cat "${CLIENT_PATH}/package.json" | head -20
        fi
        
        # Check if main entry point exists
        MAIN_FILE=$(cat "${CLIENT_PATH}/package.json" | grep '"main"' | head -1 | sed 's/.*"main": *"\([^"]*\)".*/\1/' || echo "index.js")
        if [ -f "${CLIENT_PATH}/${MAIN_FILE}" ] || [ -f "${CLIENT_PATH}/dist/index.js" ] || [ -f "${CLIENT_PATH}/build/index.js" ]; then
            echo "✓ Package files found"
        else
            echo "✗ ERROR: Package main file not found! Expected: ${CLIENT_PATH}/${MAIN_FILE}"
            echo "  Listing package directory contents:"
            ls -la "${CLIENT_PATH}" || echo "  Directory does not exist!"
        fi
    else
        echo "✗ ERROR: Could not find eufy-security-client package.json at ${CLIENT_PATH}"
        echo "  Listing node_modules directory:"
        ls -la /usr/src/app/node_modules/ | grep eufy || echo "  No eufy packages found"
    fi
    echo "================================================================"
    echo ""
    
    echo "$JSON_STRING" > $CONFIG_PATH
    exec /usr/bin/node --security-revert=CVE-2023-46809 $IPV4_FIRST_NODE_OPTION /usr/src/app/node_modules/eufy-security-ws/dist/bin/server.js --host 0.0.0.0 --config $CONFIG_PATH $DEBUG_OPTION $PORT_OPTION
else
    echo "Required parameters username and/or password not set. Starting aborted!"
fi

