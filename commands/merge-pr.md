---
description: Mergia una PR su main, transita il ticket Jira In Staging e notifica Slack
---

## Obiettivo

Selezionare e mergeare una PR su `main`, transitare il ticket Jira collegato In Staging, notificare Slack.

## Passi

### 1. Identifica la PR da mergeare

Se l'utente ha specificato un numero o URL di PR nell'invocazione del comando, usa quello.

Altrimenti, elenca le PR aperte create dall'utente corrente:
```bash
gh pr list --author @me --state open --json number,title,headRefName,createdAt \
  --template '{{range .}}#{{.number}} | {{.headRefName}} | {{.title}}{{"\n"}}{{end}}'
```

Mostra la lista all'utente e chiedi quale PR vuole mergeare. Attendi la risposta.

### 2. Recupera dettagli della PR

```bash
gh pr view <NUMERO> --json number,title,headRefName,url,body
```

Estrai:
- `headRefName`: il branch della PR
- `url`: URL della PR
- Jira key dal branch name (pattern `[A-Z]+-[0-9]+`)

### 3. Mergia la PR

Chiedi all'utente quale tipo di merge preferisce (default: squash):
- **Squash** (default): commits unificati, history pulita
- **Merge**: merge commit classico
- **Rebase**: commits lineari

```bash
gh pr merge <NUMERO> --squash --auto
# oppure --merge o --rebase in base alla scelta
```

### 4. Transizione e commento Jira

Se c'è un ticket Jira collegato:

```bash
source "${CLAUDE_PLUGIN_DATA}/.env"

# Transizione In Staging
curl -sf -o /dev/null \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST "$JIRA_BASE_URL/rest/api/2/issue/<KEY>/transitions" \
  -d "{\"transition\":{\"id\":\"$JIRA_IN_STAGING_ID\"}}"

# Commento
curl -sf -o /dev/null \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST "$JIRA_BASE_URL/rest/api/2/issue/<KEY>/comment" \
  -d "{\"body\":\"🔀 PR #<NUMERO> mergiata su main: <PR_URL>\"}"
```

### 5. Notifica Slack

```bash
source "${CLAUDE_PLUGIN_DATA}/.env"
MERGED_BY=$(git config user.name 2>/dev/null || echo "unknown")
curl -sf -o /dev/null -X POST "$SLACK_WEBHOOK_URL" \
  -H "Content-type: application/json" \
  -d "{\"text\":\"🔀 PR #<NUMERO> mergiata su main\n🎫 <$JIRA_BASE_URL/browse/<KEY>|<KEY>> → *In Staging*\n👤 $MERGED_BY\n🔗 <PR_URL>\"}"
```

Se non c'è ticket Jira, il messaggio Slack è: `🔀 PR #<NUMERO> mergiata su main — <TITOLO_PR>`

### 6. Conferma

Mostra all'utente:
- PR #`<NUMERO>` mergiata
- Ticket `<KEY>` → In Staging (se applicabile)
- Slack: notificato
