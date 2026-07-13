"""Read-only release verification for the Staff Web deployment."""
from __future__ import annotations

import json
from pathlib import Path

import paramiko


ROOT = Path(__file__).resolve().parents[1]


def env() -> dict[str, str]:
    result: dict[str, str] = {}
    for line in (ROOT / '.env.vps.local').read_text(encoding='utf-8').splitlines():
        if '=' in line and not line.lstrip().startswith('#'):
            key, value = line.split('=', 1)
            result[key.strip()] = value.strip()
    return result


def run(client: paramiko.SSHClient, command: str) -> str:
    _, out, err = client.exec_command(command, timeout=30)
    text = out.read().decode(errors='replace')
    error = err.read().decode(errors='replace')
    if out.channel.recv_exit_status():
        raise RuntimeError(error or text)
    return text


def main() -> None:
    values = env()
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(values['VPS_HOST'], port=int(values['VPS_PORT']), username=values['VPS_USER'], password=values['VPS_PASSWORD'], timeout=20)
    try:
        health = run(client, 'curl --fail --silent http://127.0.0.1:8080/health')
        menu = json.loads(run(client, 'curl --fail --silent "http://127.0.0.1:8080/menu?venue_id=v1"'))
        admin_type = run(client, "curl --fail --silent -o /dev/null -w '%{content_type}' http://127.0.0.1:8080/admin")
        assert json.loads(health)['status'] == 'ok'
        assert 'text/html' in admin_type.lower()
        assert all('assets/images/' not in json.dumps(item) for item in menu)
        print(f'HEALTH {health}')
        print(f'MENU products={len(menu)} media_urls={sum(bool(item.get("imageUrl")) for item in menu)}')
        print('ADMIN html=ok')
    finally:
        client.close()


if __name__ == '__main__':
    main()
