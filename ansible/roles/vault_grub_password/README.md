# vault_grub_password

Authenticates to HashiCorp Vault using a username and password injected by AWX
and retrieves the grub password stored at:

```
<vault mount>/base-images/ubuntu/grub/password
```

The secret is exposed as an Ansible host fact (default: `grub_password`) that
downstream roles and tasks can consume without the value appearing in logs.

---

## Requirements

- `community.hashi_vault` collection ≥ 6.0.0
  Install with: `ansible-galaxy collection install -r requirements.yml`
- The AWX job template must have a credential linked that injects
  `VAULT_ADDR`, `VAULT_USERNAME`, and `VAULT_PASSWORD` as environment variables.

---

## Role Variables

| Variable | Default | Description |
|---|---|---|
| `vault_addr` | `$VAULT_ADDR` (AWX-injected) | Vault server URL |
| `vault_username` | `$VAULT_USERNAME` (AWX-injected) | Vault userpass username |
| `vault_password` | `$VAULT_PASSWORD` (AWX-injected) | Vault userpass password |
| `vault_grub_mount` | `secret` | KV v2 mount point |
| `vault_grub_secret_path` | `base-images/ubuntu/grub` | Path within the mount |
| `vault_grub_password_key` | `password` | Key inside the KV secret that holds the password |
| `vault_grub_fact_name` | `grub_password` | Name of the fact set on the host |

---

## AWX Setup

1. Create a **custom credential type** in AWX (or use an existing one) that
   injects the following environment variables:
   - `VAULT_ADDR` — the Vault server URL
   - `VAULT_USERNAME` — the Vault userpass username
   - `VAULT_PASSWORD` — the Vault userpass password
2. Create a credential of that type with the appropriate values.
3. Link the credential to your job template under **Credentials**.

AWX injects the three env vars into the job environment automatically;
the role reads them via `lookup('env', ...)`.

---

## Example Playbook

```yaml
- name: Retrieve grub password from Vault
  hosts: all
  gather_facts: false

  roles:
    - role: vault_grub_password

  tasks:
    - name: Use the grub password (keep no_log on any task that references it)
      ansible.builtin.debug:
        msg: "Grub password length: {{ grub_password | length }}"
      no_log: true
```

Running outside AWX (e.g. local testing):

```bash
export VAULT_ADDR=https://vault.example.com
export VAULT_USERNAME=myuser
export VAULT_PASSWORD=mypassword
ansible-playbook -i inventory.ini site.yml
```

---

## Security Notes

- All tasks that handle the secret use `no_log: true`.
- The Vault lookup runs on `localhost` (the AWX execution node) with
  `delegate_to: localhost`; the secret is never transmitted to managed hosts
  unless you explicitly use the `grub_password` fact in a task targeting
  remote hosts.
- Never store the Vault token in playbook variables or version control — rely
  on AWX credential injection or environment variables only.
