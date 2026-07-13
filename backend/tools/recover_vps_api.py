"""Upload the corrected API module and wait for the health endpoint."""
from __future__ import annotations

import sys
import time

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
        sftp = client.open_sftp()
        try:
            sftp.put(str(ENV_FILE.parent / 'api/app/main.py'), f'{REMOTE_ROOT}/api/app/main.py')
        finally:
            sftp.close()
        run(client, f'cd {REMOTE_ROOT} && docker compose build api && docker compose up -d api')
        for _ in range(20):
            _, stdout, _ = client.exec_command('curl --fail --silent http://127.0.0.1:8080/health')
            output = stdout.read().decode().strip()
            if stdout.channel.recv_exit_status() == 0:
                print(output)
                return
            time.sleep(2)
        raise RuntimeError('API did not become healthy after restart')
    finally:
        client.close()


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(f'RECOVERY FAILED: {error}', file=sys.stderr)
        raise SystemExit(1)
