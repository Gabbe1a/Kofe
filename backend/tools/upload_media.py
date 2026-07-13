"""Upload approved local catalog PNGs to Yandex Object Storage.

Set S3_ENDPOINT, S3_BUCKET, S3_ACCESS_KEY and S3_SECRET_KEY in backend/.env
then run: python tools/upload_media.py
"""
from __future__ import annotations

import os
from io import BytesIO
from pathlib import Path

import boto3
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'app' / 'assets' / 'images'
FILES = {
    'products/caramel_frappe_cutout.webp': ASSETS / 'products/caramel_frappe_cutout.png',
    'products/iced_latte_cutout.webp': ASSETS / 'products/iced_latte_cutout.png',
    'products/matcha_latte_cutout.webp': ASSETS / 'products/matcha_latte_cutout.png',
    'products/lemonade_cutout.webp': ASSETS / 'products/lemonade_cutout.png',
    'products/cappuccino_cutout.webp': ASSETS / 'products/cappuccino_cutout.png',
    'products/croissant_cutout.webp': ASSETS / 'products/croissant_cutout.png',
    **{f'promo/promo_0{i}.webp': ASSETS / f'promo/promo_0{i}.png' for i in range(1, 5)},
}


def to_webp(path: Path) -> bytes:
    """Keep RGBA cutouts transparent while making all delivery images compact."""
    output = BytesIO()
    with Image.open(path) as image:
        if image.mode not in ('RGB', 'RGBA'):
            image = image.convert('RGBA' if 'transparency' in image.info else 'RGB')
        image.save(output, format='WEBP', quality=82, method=6)
    return output.getvalue()


def main() -> None:
    required = ('S3_ENDPOINT', 'S3_BUCKET', 'S3_ACCESS_KEY', 'S3_SECRET_KEY')
    missing = [name for name in required if not os.environ.get(name)]
    if missing:
        raise SystemExit(f'Missing environment variables: {", ".join(missing)}')

    client = boto3.client(
        's3',
        endpoint_url=os.environ['S3_ENDPOINT'],
        aws_access_key_id=os.environ['S3_ACCESS_KEY'],
        aws_secret_access_key=os.environ['S3_SECRET_KEY'],
        region_name=os.environ.get('S3_REGION', 'ru-central1'),
    )
    bucket = os.environ['S3_BUCKET']
    for key, path in FILES.items():
        if not path.exists():
            print(f'SKIP missing source: {path.name}')
            continue
        client.put_object(
            Bucket=bucket, Key=key, Body=to_webp(path),
            ContentType='image/webp', CacheControl='public, max-age=31536000, immutable',
        )
        print(f'UPLOADED {key}')


if __name__ == '__main__':
    main()
