---
description: Crea una nuova pagina di documentazione in Confluence
---

## Obiettivo

Creare una pagina di documentazione nel Confluence aziendale con metadata standard (tag come label, file di riferimento nel body).

## Passi

### 1. Carica le credenziali

```bash
source "${CLAUDE_PLUGIN_DATA}/.env"
```

Se il file non esiste o manca `CONFLUENCE_PARENT_URL`, di' all'utente di eseguire prima `/jira-git-sync:setup`.

### 2. Raccogli input

Chiedi all'utente, uno alla volta:
- **Titolo** della pagina
- **Tag** (separati da virgola) — diventeranno label Confluence
- **File di riferimento** (opzionali) — percorsi dei file a cui si riferisce la doc

### 3. Estrai space key e parent page ID da CONFLUENCE_PARENT_URL

L'URL ha il formato `https://<domain>/wiki/spaces/<SPACE_KEY>/pages/<PAGE_ID>...`.
Estrai `SPACE_KEY` e `PAGE_ID` con:
```bash
echo "$CONFLUENCE_PARENT_URL" | grep -oP '(?<=spaces/)[^/]+' # → SPACE_KEY
echo "$CONFLUENCE_PARENT_URL" | grep -oP '(?<=pages/)[0-9]+'  # → PAGE_ID
```

### 4. Componi il body della pagina

```
<h2>File di riferimento</h2>
<p><file1>, <file2>, ...</p>

<h2>Documentazione</h2>
<p></p>
```

Se non ci sono file di riferimento, ometti la prima sezione.

### 5. Crea la pagina

Usa il tool MCP `createConfluencePage` con:
- `spaceKey`: il valore estratto al passo 3
- `parentId`: il PAGE_ID estratto al passo 3
- `title`: il titolo inserito dall'utente
- `body`: il body composto al passo 4

Dopo la creazione, aggiungi le label usando `editJiraIssue` — no, usa invece una chiamata API diretta per le label Confluence:
```bash
source "${CLAUDE_PLUGIN_DATA}/.env"
# Estrai page ID dalla risposta del tool (campo id)
curl -sf -o /dev/null \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST "https://<domain>/wiki/rest/api/content/<NEW_PAGE_ID>/label" \
  -d '[{"prefix":"global","name":"<tag1>"},{"prefix":"global","name":"<tag2>"}]'
```

Costruisci il JSON delle label a partire dai tag separati da virgola.

### 6. Conferma

Mostra all'utente:
- Pagina creata: `<titolo>` → `<URL pagina>`
- Label aggiunte: `<lista tag>`
