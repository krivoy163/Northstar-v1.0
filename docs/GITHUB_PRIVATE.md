# Private GitHub Repository

Create a **private** repository, for example `Northstar`.

From the extracted project directory:

```bash
git init
git add .
git commit -m "Project Northstar v1.0"
git branch -M main
git remote add origin git@github.com:<YOUR_GITHUB_USER>/Northstar.git
git push -u origin main
```

## Do not commit runtime secrets

Even in a private repository, keep these out of Git:

- Telegram bot tokens
- `.env`
- `x-ui.db`
- backup archives
- Let's Encrypt private keys/certificates
- copied cookie files
- passwords

The included `.gitignore` blocks the common cases.

Backups should be stored separately (encrypted cloud storage, private object storage, local encrypted disk, etc.).
