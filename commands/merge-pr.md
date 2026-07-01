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
```

Usa il tool MCP `transitionJiraIssue` con `issueKey: "<KEY>"` e `transitionId: "$JIRA_IN_STAGING_ID"`.

Poi usa il tool MCP `addCommentToJiraIssue` con `issueKey: "<KEY>"` e `comment: "🔀 PR #<NUMERO> mergiata su main: <PR_URL>"`.

### 5. Notifica Slack

```bash
source "${CLAUDE_PLUGIN_DATA}/.env"
MERGED_BY=$(git config user.name 2>/dev/null || echo "unknown")
curl -sf -o /dev/null -X POST "$SLACK_WEBHOOK_URL" \
  -H "Content-type: application/json" \
  -d "{\"text\":\"🔀 PR #<NUMERO> mergiata su main\n🎫 <$JIRA_BASE_URL/browse/<KEY>|<KEY>> → *In Staging*\n👤 $MERGED_BY\n🔗 <PR_URL>\"}"
```

Se non c'è ticket Jira, il messaggio Slack è: `🔀 PR #<NUMERO> mergiata su main — <TITOLO_PR>`

### 6. Aggiornamento documentazione Confluence (se configurato)

Se `CONFLUENCE_PARENT_URL` è nel `.env` e non è vuoto:

Recupera i file modificati nel branch mergiato:
```bash
git diff main...<BRANCH_NAME> --name-only
```

Estrai il `PARENT_PAGE_ID` da `CONFLUENCE_PARENT_URL`:
```bash
echo "$CONFLUENCE_PARENT_URL" | grep -oP '(?<=pages/)[0-9]+'
```

Usa il tool MCP `searchConfluenceUsingCql` cercando pagine che menzionano i file cambiati:
```
ancestor = <PARENT_PAGE_ID> AND text ~ "<file1>" OR text ~ "<file2>"
```

Se trova candidati, mostra all'utente:
```
📄 Queste pagine Confluence potrebbero necessitare aggiornamento:
- <titolo1>: <url1>
- <titolo2>: <url2>

Vuoi aggiornare qualcuna di queste? (sì/no/elenca quali)
```

Per ogni pagina confermata, chiedi all'utente cosa aggiornare e usa il tool MCP `updateConfluencePage` con il contenuto modificato.

Se non trova candidati o l'utente rifiuta, prosegui silenziosamente.

### 7. Conferma

Mostra all'utente:
- PR #`<NUMERO>` mergiata
- Ticket `<KEY>` → In Staging (se applicabile)
- Slack: notificato
- Documentazione aggiornata: `<lista pagine aggiornate>` (se applicabile)
