---
description: Crea un nuovo branch partendo da un task Jira, sposta il task In Progress e notifica Slack
---

## Obiettivo

Creare un branch git collegato a un ticket Jira, transitare il ticket In Progress, notificare Slack.

## Passi

### 1. Raccogli input

Chiedi all'utente: "Nome del branch o URL/ID del ticket Jira?"

Accetta:
- URL Jira completo (es. `https://company.atlassian.net/browse/DC-443`)
- Ticket key (es. `DC-443` o `dc-443`)
- Nome branch libero (es. `feature/my-thing`) — in questo caso salta i passi Jira

### 2. Se input è un ticket Jira

Carica le credenziali:
```bash
source "${CLAUDE_PLUGIN_DATA}/.env"
```
Se il file non esiste, dì all'utente di eseguire prima `/jira-git-sync:setup`.

Estrai la key (es. `DC-443`) dall'URL o dall'input. Poi recupera il titolo del ticket:
```bash
curl -sf \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Accept: application/json" \
  "$JIRA_BASE_URL/rest/api/2/issue/DC-443?fields=summary" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['fields']['summary'])"
```

Costruisci il nome del branch: `feature/<key-lowercase>-<titolo-slugificato>`.
- Slugify: lowercase, spazi e caratteri speciali → `-`, max 50 caratteri dopo il prefisso.
- Esempio: `DC-443` + "Implementa login OAuth" → `feature/dc-443-implementa-login-oauth`

Mostra il nome proposto e chiedi conferma. L'utente può modificarlo.

### 3. Cerca documentazione rilevante (solo se c'è un ticket Jira)

Se `CONFLUENCE_PARENT_URL` è configurato nel `.env`:

Estrai 3-5 parole chiave significative da titolo e descrizione del ticket (escludi articoli, verbi comuni, parole di rumore). Estrai il `PARENT_PAGE_ID` da `CONFLUENCE_PARENT_URL` con:
```bash
echo "$CONFLUENCE_PARENT_URL" | grep -oP '(?<=pages/)[0-9]+'
```

Usa il tool MCP `searchConfluenceUsingCql` con:
```
ancestor = <PARENT_PAGE_ID> AND (title ~ "<keyword1>" OR title ~ "<keyword2>" OR label = "<keyword1>")
```

Se trova risultati, mostra all'utente i titoli e gli URL delle pagine trovate come contesto prima di iniziare. Se non trova nulla, prosegui in silenzio.

### 4. Crea il branch e pushalo

```bash
git checkout -b <nome-branch>
git push -u origin <nome-branch>
```

Se il branch esiste già, avvisa l'utente e fai `git checkout <nome-branch>` seguito da `git push -u origin <nome-branch>`.

### 5. Transizione Jira (solo se c'è un ticket)

```bash
source "${CLAUDE_PLUGIN_DATA}/.env"
curl -sf -o /dev/null \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST "$JIRA_BASE_URL/rest/api/2/issue/<KEY>/transitions" \
  -d "{\"transition\":{\"id\":\"$JIRA_IN_PROGRESS_ID\"}}"
```

Aggiungi un commento sul ticket:
```bash
curl -sf -o /dev/null \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST "$JIRA_BASE_URL/rest/api/2/issue/<KEY>/comment" \
  -d "{\"body\":\"🌿 Branch \`<nome-branch>\` creato.\"}"
```

### 6. Notifica Slack

```bash
source "${CLAUDE_PLUGIN_DATA}/.env"
curl -sf -o /dev/null -X POST "$SLACK_WEBHOOK_URL" \
  -H "Content-type: application/json" \
  -d "{\"text\":\"🌿 Nuovo branch: \`<nome-branch>\`\n🎫 <$JIRA_BASE_URL/browse/<KEY>|<KEY>> → *In Progress*\"}"
```

Se non c'era ticket Jira, il messaggio Slack è solo: `🌿 Nuovo branch: \`<nome-branch>\``

### 7. Conferma

Mostra all'utente:
- Branch creato: `<nome-branch>`
- Ticket transitato: `<KEY>` → In Progress (se applicabile)
- Slack: notificato
