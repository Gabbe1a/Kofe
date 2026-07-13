"""Deploy the media/order backend update to the configured test VPS.

The script deliberately transfers only runtime configuration needed by the API,
never the local VPS login fields. It is safe to re-run SQL migrations because
they use IF NOT EXISTS / UPSERT semantics.
"""
from __future__ import annotations

import os
import sys
import time
from pathlib import Path

import paramiko


ROOT = Path(__file__).resolve().parents[1]
ENV_FILE = ROOT / '.env.vps.local'
REMOTE_ROOT = '/opt/kofe-mama/backend'
RUNTIME_KEYS = (
    'POSTGRES_PASSWORD',
    'S3_ENDPOINT', 'S3_REGION', 'S3_BUCKET', 'S3_ACCESS_KEY', 'S3_SECRET_KEY',
    'MEDIA_BASE_URL', 'STAFF_TOKEN_SECRET', 'ADMIN_BOOTSTRAP_EMAIL',
    'ADMIN_BOOTSTRAP_PASSWORD', 'YOOKASSA_SHOP_ID', 'YOOKASSA_SECRET_KEY',
    'YOOKASSA_RETURN_URL',
)
FILES = (
    'docker-compose.yml',
    'api/Dockerfile',
    'api/.dockerignore',
    'api/requirements.txt',
    'api/app/main.py',
    'api/app/admin.html',
    'sql/migrate_orders_venue.sql',
    'sql/migrate_add_syrup_modifiers.sql',
    'sql/migrate_catalog_media.sql',
    'sql/migrate_order_core.sql',
    'sql/migrate_yookassa.sql',
    'sql/migrate_admin_operations.sql',
    'sql/migrate_staff_admin_crud.sql',
    'sql/migrate_loyalty.sql',
)


def read_env() -> dict[str, str]:
    values: dict[str, str] = {}
    for line in ENV_FILE.read_text(encoding='utf-8').splitlines():
        if '=' in line and not line.lstrip().startswith('#'):
            key, value = line.split('=', 1)
            values[key.strip()] = value.strip()
    return values


def run(client: paramiko.SSHClient, command: str) -> str:
    _, stdout, stderr = client.exec_command(command, timeout=180)
    output = stdout.read().decode(errors='replace')
    error = stderr.read().decode(errors='replace')
    exit_code = stdout.channel.recv_exit_status()
    if exit_code:
        raise RuntimeError(f'Remote command failed ({exit_code}): {error or output}')
    return output


def main() -> None:
    if not ENV_FILE.exists():
        raise SystemExit(f'Missing {ENV_FILE}')
    env = read_env()
    for key in ('VPS_HOST', 'VPS_USER', 'VPS_PORT', 'VPS_PASSWORD'):
        if not env.get(key):
            raise SystemExit(f'Missing {key} in {ENV_FILE.name}')
    for key in ('POSTGRES_PASSWORD', 'S3_ENDPOINT', 'S3_BUCKET', 'S3_ACCESS_KEY', 'S3_SECRET_KEY', 'MEDIA_BASE_URL'):
        if not env.get(key):
            raise SystemExit(f'Missing {key} in {ENV_FILE.name}')

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        hostname=env['VPS_HOST'], port=int(env['VPS_PORT']), username=env['VPS_USER'],
        password=env['VPS_PASSWORD'], timeout=20,
    )
    try:
        print(run(client, f'test -d {REMOTE_ROOT} && echo connected').strip())
        sftp = client.open_sftp()
        try:
            for relative in FILES:
                source = ROOT / relative
                target = f'{REMOTE_ROOT}/{relative}'
                sftp.put(str(source), target)
                print(f'UPDATED {relative}')

            runtime_env = '\n'.join(
                f'{key}={env[key]}' for key in RUNTIME_KEYS if env.get(key)
            ) + '\n'
            with sftp.open(f'{REMOTE_ROOT}/.env.vps.local', 'w') as remote_env:
                remote_env.write(runtime_env)
            print('UPDATED runtime environment')
        finally:
            sftp.close()

        compose = f'docker compose --env-file .env.vps.local'
        run(client, f'cd {REMOTE_ROOT} && {compose} build api')
        run(client, f'cd {REMOTE_ROOT} && {compose} up -d db')
        db_password = env['POSTGRES_PASSWORD'].replace("'", "''")
        run(
            client,
            f"cd {REMOTE_ROOT} && {compose} exec -T db "
            f"psql -v ON_ERROR_STOP=1 -U kofe -d kofe_mama "
            f"-c \"ALTER USER kofe WITH PASSWORD '{db_password}'\"",
        )
        for number, name in (
            ('05', 'catalog_media'), ('06', 'order_core'), ('07', 'yookassa'),
            ('08', 'admin_operations'),
            ('09', 'staff_admin_crud'),
            ('10', 'loyalty'),
        ):
            run(
                client,
                f'cd {REMOTE_ROOT} && {compose} exec -T db '
                f'psql -v ON_ERROR_STOP=1 -U kofe -d kofe_mama '
                f'-f /docker-entrypoint-initdb.d/{number}_{name}.sql',
            )
            print(f'MIGRATED {number}_{name}')
        run(client, f'cd {REMOTE_ROOT} && {compose} up -d api')
        for attempt in range(12):
            try:
                print(run(client, 'curl --fail --silent --show-error http://127.0.0.1:8080/health').strip())
                break
            except RuntimeError:
                if attempt == 11:
                    raise
                time.sleep(2)
    finally:
        client.close()


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(f'DEPLOY FAILED: {error}', file=sys.stderr)
        raise SystemExit(1)
