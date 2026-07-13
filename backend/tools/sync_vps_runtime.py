"""Synchronize the sanitized runtime env and restart only the API service."""
from __future__ import annotations

import sys
import time

import paramiko

from deploy_vps import REMOTE_ROOT, RUNTIME_KEYS, read_env, run


def main() -> None:
    env = read_env()
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        hostname=env['VPS_HOST'], port=int(env['VPS_PORT']), username=env['VPS_USER'],
        password=env['VPS_PASSWORD'], timeout=20,
    )
    try:
        content = '\n'.join(f'{key}={env[key]}' for key in RUNTIME_KEYS if env.get(key)) + '\n'
        sftp = client.open_sftp()
        try:
            with sftp.open(f'{REMOTE_ROOT}/.env.vps.local', 'w') as remote_env:
                remote_env.write(content)
        finally:
            sftp.close()
        run(client, f'cd {REMOTE_ROOT} && docker compose up -d --force-recreate api')
        for _ in range(15):
            _, stdout, _ = client.exec_command('curl --fail --silent http://127.0.0.1:8080/health')
            body = stdout.read().decode().strip()
            if stdout.channel.recv_exit_status() == 0:
                print(body)
                return
            time.sleep(2)
        raise RuntimeError('API did not become healthy after runtime sync')
    finally:
        client.close()


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(f'RUNTIME SYNC FAILED: {error}', file=sys.stderr)
        raise SystemExit(1)
