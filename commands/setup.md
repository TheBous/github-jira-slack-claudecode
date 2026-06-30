---
description: Configura le credenziali Jira, Slack e Confluence per jira-git-sync
---

Guida l'utente passo passo nella configurazione delle credenziali. Fai una domanda alla volta e aspetta la risposta.

## Passi

1. **Jira Base URL** — chiedi l'URL base di Jira (es. `https://company.atlassian.net`).

2. **Jira Email** — chiedi l'email con cui accede a Jira.

3. **Jira API Token** — spiega dove generarlo: `id.atlassian.com → Security → Create and manage API tokens`, poi chiedi il token.

4. **Slack Webhook URL** — spiega dove crearlo: `api.slack.com → Your Apps → Incoming Webhooks → Add New Webhook`, poi chiedi l'URL.

5. **Confluence Parent URL** — chiedi l'URL della pagina Confluence che fungerà da cartella padre per la documentazione (es. `https://company.atlassian.net/wiki/spaces/TECH/pages/123456/Documentazione`). Questa pagina deve essere già esistente. Se l'utente non usa Confluence, può saltare questo passo lasciando vuoto.

5. **Transition IDs** — dopo aver raccolto Jira URL, email e token, esegui:
   ```bash
   curl -s -u "<EMAIL>:<TOKEN>" "<BASE_URL>/rest/api/2/issue/<QUALSIASI_TICKET>/transitions" \
     | python3 -m json.tool | grep -E '"id"|"name"'
   ```
   Chiedi all'utente di indicare un ticket qualunque su cui testare, esegui il comando con i dati reali, mostra la lista degli stati, poi chiedi di scegliere gli ID per:
   - **In Progress** (quando crea un branch)
   - **In Review** (quando crea una PR) — se non esiste salta
   - **In Staging** (quando mergia la PR)
   - **Done / Released** (quando tagga per produzione)

## Salvataggio

Crea la directory `${CLAUDE_PLUGIN_DATA}` se non esiste, poi scrivi il file `${CLAUDE_PLUGIN_DATA}/.env`:

```
JIRA_BASE_URL=<valore>
JIRA_EMAIL=<valore>
JIRA_API_TOKEN=<valore>
JIRA_IN_PROGRESS_ID=<valore>
JIRA_IN_REVIEW_ID=<valore o stringa vuota>
JIRA_IN_STAGING_ID=<valore>
JIRA_DONE_ID=<valore>
SLACK_WEBHOOK_URL=<valore>
CONFLUENCE_PARENT_URL=<valore o stringa vuota>
```

Esegui `mkdir -p "${CLAUDE_PLUGIN_DATA}"` prima di scrivere il file. Conferma all'utente che la configurazione è stata salvata e suggerisci di provare `/jira-git-sync:new-branch`.
