---
description: Crea un tag di release, transita tutti i ticket Jira coinvolti a Done e notifica Slack
---

## Obiettivo

Creare un tag git per il deploy in produzione, trovare tutti i ticket Jira inclusi nella release, transitarli a Done, notificare Slack.

## Passi

### 1. Determina il tag

Recupera l'ultimo tag esistente:
```bash
git tag --sort=-version:refname | head -5
```

Suggerisci il prossimo tag: se l'ultimo è `v1.2.3`, proponi `v1.2.4` (patch bump). Mostra il suggerimento all'utente e chiedi conferma o un nome diverso.

Se non ci sono tag, proponi `v0.1.0`.

Assicurati di essere su `main` e che sia aggiornato:
```bash
git branch --show-current
git pull origin main --ff-only
```

### 2. Trova i ticket Jira nella release

Recupera il diff dei commit dall'ultimo tag:
```bash
LAST_TAG=$(git tag --sort=-version:refname | head -1)
if [ -n "$LAST_TAG" ]; then
  git log --pretty=format:"%s %b" "${LAST_TAG}..HEAD"
else
  git log --pretty=format:"%s %b"
fi
```

Estrai tutte le Jira key univoche (pattern `[A-Z]+-[0-9]+`) dai messaggi di commit e dai nomi dei branch mergiati. Mostra la lista all'utente.

### 3. Crea e pusha il tag

```bash
git tag -a "<TAG>" -m "Release <TAG>"
git push origin "<TAG>"
```

### 4. Crea la GitHub Release (opzionale)

Chiedi all'utente se vuole creare una GitHub Release.

Se sì:
```bash
gh release create "<TAG>" \
  --title "Release <TAG>" \
  --notes "$(git log --pretty=format:"- %s" "${LAST_TAG}..HEAD" | head -20)"
```

Cattura l'URL della release.

### 5. Transizione e commento Jira per ogni ticket

Per ogni Jira key trovata:

```bash
source "${CLAUDE_PLUGIN_DATA}/.env"

# Transizione Done/Released
curl -sf -o /dev/null \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST "$JIRA_BASE_URL/rest/api/2/issue/<KEY>/transitions" \
  -d "{\"transition\":{\"id\":\"$JIRA_DONE_ID\"}}"

# Commento
curl -sf -o /dev/null \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST "$JIRA_BASE_URL/rest/api/2/issue/<KEY>/comment" \
  -d "{\"body\":\"🚀 Deploy in produzione con tag \`<TAG>\`.\"}"
```

Esegui in sequenza per tutti i ticket trovati. Se un ticket fallisce (es. già Done), logga l'errore e continua.

### 6. Notifica Slack

Costruisci la lista dei ticket come link Jira:

```bash
source "${CLAUDE_PLUGIN_DATA}/.env"
DEPLOYER=$(git config user.name 2>/dev/null || echo "unknown")

# Messaggio con tutti i ticket come links
curl -sf -o /dev/null -X POST "$SLACK_WEBHOOK_URL" \
  -H "Content-type: application/json" \
  -d "{\"text\":\"🚀 *Deploy Production* — Tag \`<TAG>\`\n👤 $DEPLOYER\n🎫 Ticket: <LISTA_TICKET_CON_LINKS>\n<RELEASE_URL_SE_PRESENTE>\"}"
```

Formato ticket nel messaggio: `<JIRA_BASE_URL/browse/DC-443|DC-443>` per ogni ticket, separati da spazio.

### 7. Conferma

Mostra all'utente:
- Tag `<TAG>` creato e pushato
- Ticket transitati a Done: `<lista>`
- GitHub Release: `<URL>` (se creata)
- Slack: notificato
