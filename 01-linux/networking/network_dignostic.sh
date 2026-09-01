#!/bin/bash

# Ensure script is provided with exactly two arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <target_domain_or_ip> <port>"
    exit 1
fi

TARGET=$1
PORT=$2
STATUS_CODE=0

echo "===================================="
echo "       NETWORK DIAGNOSTIC"
echo "===================================="
echo "Target: $TARGET"
echo "Port:   $PORT"
echo "===================================="

# --- 1. DNS Resolution ---
echo -e "\n[1] DNS Resolution:"
# If the target is already an IP, dig +short might return empty; we extract the IP safely
RESOLVED_IP=$(dig +short "$TARGET" | tail -n1)

if [ -z "$RESOLVED_IP" ]; then
    # Check if target itself is a valid IPv4 address
    if [[ "$TARGET" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        RESOLVED_IP="$TARGET"
        echo "Resolved IP: $RESOLVED_IP (Target provided as raw IP)"
    else
        echo "Resolved IP: FAILED (Cannot resolve hostname)"
        STATUS_CODE=1
    fi
else
    echo "Resolved IP: $RESOLVED_IP"
fi

# --- 2. Route ---
echo -e "\n[2] Route:"
if [ "$STATUS_CODE" -eq 0 ]; then
    # Fetch outbound route details using the resolved IP
    ROUTE_INFO=$(ip route get "$RESOLVED_IP" 2>/dev/null)
    if [ -n "$ROUTE_INFO" ]; then
        echo "$ROUTE_INFO"
    else
        echo "FAILED: No valid network route found to $RESOLVED_IP"
        STATUS_CODE=1
    fi
else
    echo "SKIPPED: DNS layer failed."
fi

# --- 3. TCP Connectivity ---
echo -e "\n[3] TCP Connectivity:"
if [ "$STATUS_CODE" -eq 0 ]; then
    # Test TCP port using netcat with a 3-second timeout
    if nc -zv -w 3 "$RESOLVED_IP" "$PORT" >/dev/null 2>&1; then
        echo "SUCCESS: Connected to $RESOLVED_IP on port $PORT"
    else
        echo "FAILED: Connection refused or timed out on port $PORT"
        STATUS_CODE=1
    fi
else
    echo "SKIPPED: Route/DNS layer failed."
fi

# --- 4. HTTP/HTTPS (Only evaluated if testing web ports) ---
echo -e "\n[4] HTTP/HTTPS Protocol:"
if [ "$STATUS_CODE" -eq 0 ]; then
    if [ "$PORT" -eq 80 ] || [ "$PORT" -eq 443 ]; then
        PROTOCOL="http"
        [ "$PORT" -eq 443 ] && PROTOCOL="https"
        
        # Make a fast, silent HEAD request dropping SSL verification if needed for a raw IP
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 -k "$PROTOCOL://$TARGET")
        
        if [ "$HTTP_STATUS" -ne 000 ]; then
            echo "SUCCESS: Server responded with HTTP Status $HTTP_STATUS"
        else
            echo "FAILED: HTTP request timed out or was dropped by server"
            STATUS_CODE=1
        fi
    else
        echo "SKIPPED: Port $PORT is not a standard HTTP/HTTPS web port."
    fi
else
    echo "SKIPPED: TCP Layer failed."
fi

# --- 5. Local Listening Sockets (Bonus visibility context) ---
echo -e "\n[5] Local Listening Sockets (Matches for Port $PORT):"
LOCAL_LISTEN=$(ss -tlnp | grep -E ":$PORT\s" 2>/dev/null)
if [ -n "$LOCAL_LISTEN" ]; then
    echo "$LOCAL_LISTEN"
else
    echo "INFO: No local service is listening on port $PORT on this machine."
fi

echo "===================================="
if [ "$STATUS_CODE" -eq 0 ]; then
    echo "RESULT: Connectivity appears healthy (Exit Code: 0)"
else
    echo "RESULT: Connectivity problem detected (Exit Code: 1)"
fi
echo "===================================="

exit $STATUS_CODE

