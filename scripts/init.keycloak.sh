#!/bin/sh
set -e

echo "Waiting for Keycloak to become ready..."
until /opt/keycloak/bin/kcadm.sh config credentials \
    --server http://keycloak:8080 \
    --realm master \
    --user "$KEYCLOAK_ADMIN" \
    --password "$KEYCLOAK_ADMIN_PASSWORD"; do
    echo "Keycloak not ready yet, sleeping 2s..."
    sleep 2
done

echo "Ensuring realm local-demo exists..."
/opt/keycloak/bin/kcadm.sh create realms -s realm=local-demo -s enabled=true || true

echo "Ensuring worker client exists..."
if ! /opt/keycloak/bin/kcadm.sh get clients -r local-demo -q clientId="$WORKER_OIDC_CLIENT_ID" | grep -q '"clientId"'; then
    /opt/keycloak/bin/kcadm.sh create clients -r local-demo \
        -s clientId="$WORKER_OIDC_CLIENT_ID" \
        -s enabled=true \
        -s publicClient=false \
        -s clientAuthenticatorType=client-secret \
        -s secret="$WORKER_OIDC_CLIENT_SECRET" \
        -s serviceAccountsEnabled=true \
        -s standardFlowEnabled=false \
        -s directAccessGrantsEnabled=false
fi

echo "Ensuring local-app client exists..."
if ! /opt/keycloak/bin/kcadm.sh get clients -r local-demo -q clientId=local-app | grep -q '"clientId"'; then
    /opt/keycloak/bin/kcadm.sh create clients -r local-demo \
        -s clientId=local-app \
        -s enabled=true \
        -s publicClient=true \
        -s directAccessGrantsEnabled=true \
        -s standardFlowEnabled=true
fi

echo "Ensuring demo user exists..."
if ! /opt/keycloak/bin/kcadm.sh get users -r local-demo -q username=demo-user | grep -q '"username"'; then
    /opt/keycloak/bin/kcadm.sh create users -r local-demo \
        -s id=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa \
        -s username=demo-user \
        -s firstName=Demo \
        -s lastName=User \
        -s email=demo@example.com \
        -s emailVerified=true \
        -s enabled=true
fi

echo "Setting password for demo-user..."
/opt/keycloak/bin/kcadm.sh set-password -r local-demo --username demo-user --new-password demo-password123

echo "Keycloak initialization completed successfully."
