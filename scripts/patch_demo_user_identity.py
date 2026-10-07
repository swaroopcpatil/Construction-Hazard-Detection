#!/usr/bin/env python3
"""
One-shot script: look up demo-user's UUID in Keycloak, then update
user_identities in Postgres so the token-auth flow works correctly.

Required environment variables:
  KEYCLOAK_ADMIN               Keycloak master-realm admin username
  KEYCLOAK_ADMIN_PASSWORD      Keycloak master-realm admin password
  KEYCLOAK_SERVER              e.g. http://keycloak:8080
  POSTGRES_DSN                 e.g. postgresql://user:pass@postgres/dbname
  DEMO_USERNAME                Keycloak username to look up (default: demo-user)
  DB_APP_USERNAME              Local DB username whose identity to patch (default: user)
"""
import asyncio
import os
import sys
import time

import asyncpg
import httpx


KEYCLOAK_SERVER = os.environ["KEYCLOAK_SERVER"]
ADMIN_USER = os.environ["KEYCLOAK_ADMIN"]
ADMIN_PASS = os.environ["KEYCLOAK_ADMIN_PASSWORD"]
POSTGRES_DSN = os.environ["POSTGRES_DSN"]
DEMO_USERNAME = os.environ.get("DEMO_USERNAME", "demo-user")
DB_APP_USERNAME = os.environ.get("DB_APP_USERNAME", "user")
REALM = os.environ.get("KEYCLOAK_REALM", "local-demo")


def wait_for_keycloak(timeout: int = 120) -> None:
    url = f"{KEYCLOAK_SERVER}/realms/master"
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            r = httpx.get(url, timeout=3)
            if r.status_code < 500:
                print(f"Keycloak is up (HTTP {r.status_code})")
                return
        except Exception as exc:
            print(f"  Waiting for Keycloak: {exc}")
        time.sleep(3)
    raise TimeoutError(f"Keycloak not ready after {timeout}s")


def get_admin_token() -> str:
    url = f"{KEYCLOAK_SERVER}/realms/master/protocol/openid-connect/token"
    r = httpx.post(url, data={
        "grant_type": "password",
        "client_id": "admin-cli",
        "username": ADMIN_USER,
        "password": ADMIN_PASS,
    }, timeout=10)
    r.raise_for_status()
    return r.json()["access_token"]


def get_user_uuid(token: str) -> str:
    url = f"{KEYCLOAK_SERVER}/admin/realms/{REALM}/users"
    r = httpx.get(url, params={"username": DEMO_USERNAME, "exact": "true"},
                  headers={"Authorization": f"Bearer {token}"}, timeout=10)
    r.raise_for_status()
    users = r.json()
    if not users:
        raise ValueError(f"User '{DEMO_USERNAME}' not found in realm '{REALM}'")
    uid = users[0]["id"]
    print(f"Keycloak UUID for '{DEMO_USERNAME}': {uid}")
    return uid


async def patch_db(uuid: str) -> None:
    conn = await asyncpg.connect(POSTGRES_DSN)
    try:
        result = await conn.execute(
            """
            UPDATE user_identities
               SET provider_user_id = $1
             WHERE provider = 'keycloak'
               AND user_id = (SELECT id FROM users WHERE username = $2)
            """,
            uuid,
            DB_APP_USERNAME,
        )
        print(f"DB update result: {result}")
    finally:
        await conn.close()


def set_redis_demand() -> None:
    redis_host = os.environ.get("REDIS_HOST")
    redis_pass = os.environ.get("REDIS_PASSWORD")
    if not redis_host:
        return
    import redis
    r = redis.Redis(host=redis_host, port=6379, password=redis_pass, decode_responses=True)
    media_path = "hazard_TG9jYWwgRGVtbw_cXVpY2tzdGFydC1jYW1lcmE"
    r.set(f"media_clean_demand:{media_path}", 1)
    r.set(f"media_overlay_demand:{media_path}:en", 1)
    r.set(f"media_overlay_demand:{media_path}:zh-TW", 1)
    print(f"Redis demand keys initialized permanently for {media_path}.")


def main() -> None:
    wait_for_keycloak()
    token = get_admin_token()
    uuid = get_user_uuid(token)
    asyncio.run(patch_db(uuid))
    set_redis_demand()
    print("Done — user_identities patched and demand initialized successfully.")


if __name__ == "__main__":
    main()
