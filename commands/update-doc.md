---
description: Aggiorna una pagina di documentazione esistente in Confluence
---

## Obiettivo

Trovare e aggiornare una pagina di documentazione in Confluence, identificata per URL o titolo.

## Passi

### 1. Carica le credenziali

```bash
source "${CLAUDE_PLUGIN_DATA}/.env"
```

Se il file non esiste o manca `CONFLUENCE_PARENT_URL`, di' all'utente di eseguire prima `/jira-git-sync:setup`.

### 2. Identifica la pagina

Chiedi all'utente: "URL o titolo della pagina da aggiornare?"

**Se URL**: estrai il page ID con `echo "<URL>" | grep -oP '(?<=pages/)[0-9]+'`

**Se titolo**: usa il tool MCP `searchConfluenceUsingCql` con:
```
title = "<titolo>" AND ancestor = <PARENT_PAGE_ID>
```
dove `PARENT_PAGE_ID` è estratto da `CONFLUENCE_PARENT_URL`. Se più risultati, mostrali e chiedi quale.

### 3. Recupera il contenuto attuale

Usa il tool MCP `getConfluencePage` con il page ID trovato. Mostra all'utente il titolo e il body attuale.

### 4. Raccogli le modifiche

Chiedi all'utente cosa vuole modificare (titolo, body, aggiunta/rimozione tag, file di riferimento).

### 5. Applica le modifiche

Usa il tool MCP `updateConfluencePage` con il page ID e il contenuto aggiornato.

Per modifiche ai tag (label), usa curl:
```bash
# Aggiunta label
curl -sf -o /dev/null \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST "https://<domain>/wiki/rest/api/content/<PAGE_ID>/label" \
  -d '[{"prefix":"global","name":"<tag>"}]'

# Rimozione label
curl -sf -o /dev/null \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -X DELETE "https://<domain>/wiki/rest/api/content/<PAGE_ID>/label/<tag>"
```

### 6. Conferma

Mostra all'utente:
- Pagina aggiornata: `<titolo>` → `<URL pagina>`
