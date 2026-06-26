# jira-git-sync

Claude Code plugin: automazione del workflow git → Jira → Slack.

## Comandi

| Comando | Cosa fa |
|---|---|
| `/jira-git-sync:setup` | Configura credenziali Jira e Slack (una volta sola) |
| `/jira-git-sync:new-branch` | Nuovo branch da ticket Jira → ticket In Progress + Slack |
| `/jira-git-sync:create-pr` | Crea PR verso main → ticket In Review + Slack |
| `/jira-git-sync:merge-pr` | Mergia PR → ticket In Staging + Slack |
| `/jira-git-sync:tag` | Tag release → tutti i ticket Done + Slack |

## Installazione

```bash
# Aggiungi la marketplace (una volta sola per team)
/plugin marketplace add lucvalse/jira-git-sync

# Installa il plugin
/plugin install jira-git-sync

# Configura le credenziali (interattivo)
/jira-git-sync:setup
```

## Requisiti

- `gh` CLI autenticato (`gh auth login`)
- Account Jira con API token ([genera qui](https://id.atlassian.com/manage-profile/security/api-tokens))
- Slack Incoming Webhook ([crea qui](https://api.slack.com/messaging/webhooks))

## Convenzione branch

Il nome del branch deve contenere la Jira key per il collegamento automatico:

```
feature/dc-443-titolo-del-ticket   ✓
fix/AUTH-12-fix-oauth-redirect     ✓
my-random-branch                   ✗  (nessun collegamento Jira)
```
