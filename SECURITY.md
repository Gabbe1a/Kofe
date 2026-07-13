# Security policy

## Secrets

Never commit real credentials, payment keys, VPS access data, Object Storage
keys, Android `local.properties`, or `MapKitSecrets.kt`. The repository keeps
only safe templates such as `backend/.env.example` and
`app/android/local.properties.example`.

If a secret has ever been committed, rotate it in the provider console first;
deleting the file in a later commit does not remove it from Git history.

## Reporting a vulnerability

Please do not open a public issue with an exploit, credential, or customer
data. Contact the repository owner privately with a short reproduction and the
affected component.

## Deployment boundary

This repository is an MVP. Before exposing staff access or accepting live
payments, use an HTTPS domain, restrict `/admin` at the network layer, set
unique runtime secrets, and complete customer authentication with per-user
order authorization.
