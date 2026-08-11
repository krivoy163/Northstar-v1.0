# Security Notes

The Git repository and the production backup serve different purposes.

## Never commit

- `.env`
- Telegram bot tokens
- `cookies.txt`
- `inbounds.json`
- `x-ui.db`
- Northstar `.tar.gz` backups
- `/etc/letsencrypt` contents
- private keys or ACME account material

The production backup intentionally contains `x-ui.db`, TLS private keys and Let's Encrypt account state. Treat the archive as a secret and store it separately from Git.

A private GitHub repository reduces exposure but is not a reason to commit live credentials.
