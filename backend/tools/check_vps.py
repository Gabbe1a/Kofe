"""Read-only health diagnostics for the configured test VPS."""
from __future__ import annotations

import sys

import paramiko

from deploy_vps import ENV_FILE, REMOTE_ROOT, read_env, run


def main() -> None:
    env = read_env()
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        hostname=env['VPS_HOST'], port=int(env['VPS_PORT']), username=env['VPS_USER'],
        password=env['VPS_PASSWORD'], timeout=20,
    )
    try:
        print(run(client, f'cd {REMOTE_ROOT} && docker compose ps'))
        print(run(client, f'cd {REMOTE_ROOT} && docker compose logs --tail=80 api'))
        print(run(client, 'curl --fail --silent --show-error http://127.0.0.1:8080/health'))
    finally:
        client.close()


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(f'CHECK FAILED: {error}', file=sys.stderr)
        raise SystemExit(1)
