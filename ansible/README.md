# Ansible Setup

## Vault password lookup

The Windows inventory password is pulled from HashiCorp Vault at runtime using
`ansible/vault_password.py`. Set these environment variables on the control node
before running playbooks:

```
export VAULT_URL="https://vault.example.com"
export VAULT_TOKEN="your-token"
export VAULT_SECRET_PATH="secret/path/to/creds"
```

Optional:

```
export VAULT_PASSWORD_KEY="password"
```

## Patching API authentication

The Flask API requires a bearer token for status reads, status updates, and
server imports. Configure the same randomly generated token as
`PATCHING_API_TOKEN` in the API service and in the Ansible controller
environment. Keep it in a secret manager or protected environment file; do not
commit it. The playbooks fail before patching if the controller variable is
missing.

For example, provision a token with `openssl rand -hex 32` through your secret
manager, then export it as `PATCHING_API_TOKEN` for the API service and
controller. Initialize the database before starting Gunicorn:

```
python -c "from app import init_db; init_db()"
gunicorn --bind 127.0.0.1:9999 app:app
```

Use an HTTPS `status_url` in `group_vars` when communicating with a remote API.
Terminate TLS at a trusted reverse proxy and keep the API bound to loopback
unless a deployment specifically requires another interface. The dashboard
prompts for the API token and keeps it only in the current browser session.

The `import_servers.py` client also reads `PATCHING_API_TOKEN` from its
environment.

## Example runs

```
ansible-playbook -i ansible/inventory.ini ansible/windows_patch.yml
ansible-playbook -i ansible/inventory.ini ansible/linux_patch.yml
```

## Post-CIS hardening verification

`cis_verify.yml` checks that core server functionality is intact after CIS
benchmark hardening. Run it on a single host or across the fleet.

```
# All linux hosts
ansible-playbook -i ansible/inventory.ini ansible/cis_verify.yml

# Single host
ansible-playbook -i ansible/inventory.ini ansible/cis_verify.yml \
  --limit example-linux-01

# Pass AD-specific vars
ansible-playbook -i ansible/inventory.ini ansible/cis_verify.yml \
  -e "ad_domain=example.corp ad_test_user=svc_ansible"
```

### What it checks

| Check | Detail |
|---|---|
| **SSH** | sshd running; key `sshd -T` settings logged |
| **AD / SSSD** | sssd running; `realm list`; optional `getent passwd <user>` |
| **PAM** | `/etc/pam.d/sshd`, `common-auth`/`system-auth` present; `pam_sss` referenced |
| **Sudo** | `visudo -c` syntax validation |
| **DNS** | `getent hosts` against AD domain (or google.com) |
| **NTP** | chrony or systemd-timesyncd running; `chronyc tracking` summary |
| **Firewall** | ufw active (Debian/Ubuntu) or firewalld running (RHEL/CentOS) |
| **MAC** | AppArmor active (Debian/Ubuntu) or SELinux mode (RHEL/CentOS) |
| **auditd** | service running |
| **rsyslog** | service running |
| **CIS spots** | umask, `PASS_MAX_DAYS`, `/tmp` mount, core dump limits |
| **Open ports** | `ss -tlnup` output logged for review |

Results are written to `/var/log/cis_verify.log` on each host and printed to
stdout at the end of the play. The play fails if any check does not pass.

### Variables

| Variable | Default | Purpose |
|---|---|---|
| `ad_domain` | `''` | AD domain for DNS test; skipped if empty |
| `ad_test_user` | `''` | AD user to verify via `getent passwd`; skipped if empty |
| `ntp_servers` | `[]` | Reserved for future NTP server validation |
