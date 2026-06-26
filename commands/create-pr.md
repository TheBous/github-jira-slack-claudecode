---
description: Crea una PR su GitHub verso main, commenta su Jira e notifica Slack
---

## Obiettivo

Creare una Pull Request per il branch corrente verso `main`, collegandola al ticket Jira estratto dal nome del branch.

## Passi

### 1. Verifica stato

```bash
git branch --show-current
git status --short
```

Se ci sono modifiche non committate, avvisa l'utente e chiedi se vuole procedere ugualmente.

Verifica che il branch sia pushato su origin:
```bash
git ls-remote --exit-code origin "$(git branch --show-current)" 2>/dev/null \
  || echo "NOT_PUSHED"
```

Se non pushato, chiedi conferma e poi:
```bash
git push -u origin "$(git branch --show-current)"
```

### 2. Estrai ticket Jira

Dal nome del branch, cerca un pattern `[A-Z]+-[0-9]+` (es. `dc-443` → `DC-443`).

Se trovato, carica le credenziali e recupera titolo e descrizione del ticket:
```bash
source "${CLAUDE_PLUGIN_DATA}/.env"
curl -sf \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Accept: application/json" \
  "$JIRA_BASE_URL/rest/api/2/issue/<KEY>?fields=summary,description" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)['fields']
print('SUMMARY:', d.get('summary',''))
print('DESC:', (d.get('description') or '')[:300])
"
```

### 3. Componi il titolo e body della PR

**Titolo**: `[<KEY>] <titolo del ticket>` — oppure titolo libero se non c'è ticket.

**Body** (usa questo template):

```
## Descrizione

<breve descrizione del cambiamento>

## Jira

[<KEY>](<JIRA_BASE_URL>/browse/<KEY>)

## Testing

- [ ] Testato in locale
```

Mostra titolo e body proposti, chiedi conferma o modifiche.

### 4. Crea la PR

```bash
gh pr create \
  --base main \
  --title "<titolo>" \
  --body "<body>"
```

Cattura l'URL della PR dal output.

### 5. Transizione e commento Jira

Se c'è un ticket e `JIRA_IN_REVIEW_ID` è configurato:
```bash
source "${CLAUDE_PLUGIN_DATA}/.env"
# Transizione In Review
curl -sf -o /dev/null \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST "$JIRA_BASE_URL/rest/api/2/issue/<KEY>/transitions" \
  -d "{\"transition\":{\"id\":\"$JIRA_IN_REVIEW_ID\"}}"
```

Commento sul ticket:
```bash
curl -sf -o /dev/null \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST "$JIRA_BASE_URL/rest/api/2/issue/<KEY>/comment" \
  -d "{\"body\":\"🔍 PR aperta: <PR_URL>\"}"
```

### 6. Notifica Slack

```bash
source "${CLAUDE_PLUGIN_DATA}/.env"
curl -sf -o /dev/null -X POST "$SLACK_WEBHOOK_URL" \
  -H "Content-type: application/json" \
  -d "{\"text\":\"🔍 PR aperta: <PR_URL>\n🎫 <$JIRA_BASE_URL/browse/<KEY>|<KEY>> → *In Review*\"}"
```

### 7. Conferma

Mostra all'utente:
- PR creata: `<PR_URL>`
- Ticket `<KEY>` → In Review (se applicabile)
- Slack: notificato
