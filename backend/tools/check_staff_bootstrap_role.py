"""Read the configured bootstrap account role without printing credentials."""
from __future__ import annotations

from pathlib import Path

import paramiko


ROOT = Path(__file__).resolve().parents[1]


def read_env() -> dict[str, str]:
    values: dict[str, str] = {}
    for line in (ROOT / '.env.vps.local').read_text(encoding='utf-8').splitlines():
        if '=' in line and not line.lstrip().startswith('#'):
            key, value = line.split('=', 1)
            values[key.strip()] = value.strip()
    return values


def main() -> None:
    values = read_env()
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(values['VPS_HOST'], port=int(values['VPS_PORT']), username=values['VPS_USER'], password=values['VPS_PASSWORD'], timeout=20)
    try:
        email = values.get('ADMIN_BOOTSTRAP_EMAIL', '').replace("'", "''")
        command = (
            "cd /opt/kofe-mama/backend && docker compose exec -T db "
            "psql -At -U kofe -d kofe_mama -c "
            f"\"SELECT role || '|' || CASE WHEN is_active THEN 'active' ELSE 'inactive' END FROM staff_users WHERE lower(email)=lower('{email}');\""
        )
        _, out, err = client.exec_command(command, timeout=30)
        result = out.read().decode().strip()
        error = err.read().decode().strip()
        if out.channel.recv_exit_status() != 0:
            raise RuntimeError(error)
        print(result or 'bootstrap-account-not-found')
    finally:
        client.close()


if __name__ == '__main__':
    main()
