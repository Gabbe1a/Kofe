"""Compare every menu price with its venue-aware PDP price on the VPS."""
from __future__ import annotations

import json
import shlex
from pathlib import Path

import paramiko


ROOT = Path(__file__).resolve().parents[1]


def env() -> dict[str, str]:
    values: dict[str, str] = {}
    for line in (ROOT / '.env.vps.local').read_text(encoding='utf-8').splitlines():
        if '=' in line and not line.lstrip().startswith('#'):
            key, value = line.split('=', 1)
            values[key.strip()] = value.strip()
    return values


def run(client: paramiko.SSHClient, command: str) -> str:
    _, out, err = client.exec_command(command, timeout=30)
    text = out.read().decode(errors='replace')
    error = err.read().decode(errors='replace')
    if out.channel.recv_exit_status() != 0:
        raise RuntimeError(error or text)
    return text


def get_json(client: paramiko.SSHClient, path: str) -> object:
    return json.loads(run(client, f'curl --fail --silent {shlex.quote("http://127.0.0.1:8080" + path)}'))


def main() -> None:
    values = env()
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(values['VPS_HOST'], port=int(values['VPS_PORT']), username=values['VPS_USER'], password=values['VPS_PASSWORD'], timeout=20)
    try:
        venues = get_json(client, '/venues')
        problems: list[str] = []
        checked = 0
        for venue in venues:
            venue_id = venue['id']
            menu = get_json(client, f'/menu?venue_id={venue_id}')
            for item in menu:
                pdp = get_json(client, f'/products/{item["id"]}?venue_id={venue_id}')
                checked += 1
                if item['price'] != pdp['price']:
                    problems.append(f'{venue_id}:{item["id"]} menu={item["price"]} pdp={pdp["price"]}')
        if problems:
            raise SystemExit('PRICE MISMATCH\n' + '\n'.join(problems))
        print(f'PRICE CONSISTENCY OK: {checked} venue-product pairs')
    finally:
        client.close()


if __name__ == '__main__':
    main()
