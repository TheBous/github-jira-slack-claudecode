---
description: Crea una nuova pagina di documentazione in Confluence
---

## Obiettivo

Creare una pagina di documentazione in Confluence leggendo il codice, generando il contenuto automaticamente e pubblicando solo dopo approvazione dell'utente.

## Passi

### 1. Carica le credenziali

```bash
source "${CLAUDE_PLUGIN_DATA}/.env"
```

Se il file non esiste o manca `CONFLUENCE_PARENT_URL`, di' all'utente di eseguire prima `/jira-git-sync:setup`.

### 2. Identifica il target

Se l'utente ha passato un file path nell'invocazione (es. `/create-doc src/auth/login.ts`), usalo direttamente.

Se invece ha descritto una feature a voce (es. "documenta il flusso di login"), cerca nel codebase:
```bash
grep -rl "<keyword>" . --include="*.ts" --include="*.js" --include="*.py" --include="*.go" 2>/dev/null | head -20
```
Mostra all'utente i file trovati e chiedi conferma: "Ho trovato questi file — sono quelli giusti o vuoi aggiungerne/escluderne?"
Attendi risposta prima di procedere.

### 3. Chiedi il titolo

Chiedi all'utente: "Titolo della pagina?"

### 4. Analizza il codice e genera il draft

Leggi i file identificati al passo 2. Basandoti su quello che trovi:

- **Suggerisci 3-5 tag** pertinenti (tecnologia, dominio, tipo: es. `auth`, `api`, `typescript`)
- **Genera il body** in formato libero: scrivi la documentazione più utile per quel codice specifico — non seguire sezioni fisse, adatta la struttura a quello che il codice fa. Può essere prosa, liste, esempi di utilizzo, diagrammi testuali, tutto ciò che aiuta a capire.

Mostra all'utente il draft completo:
```
📄 Draft documentazione

Titolo: <titolo>
Tag suggeriti: <tag1>, <tag2>, <tag3>

---
<body generato>
---

Vuoi modificare qualcosa prima di pubblicare su Confluence?
```

Attendi risposta. Se l'utente chiede modifiche, applica e mostra di nuovo. Quando conferma, vai al passo 5.

### 5. Estrai space key e parent page ID

```bash
echo "$CONFLUENCE_PARENT_URL" | grep -oP '(?<=spaces/)[^/]+'  # → SPACE_KEY
echo "$CONFLUENCE_PARENT_URL" | grep -oP '(?<=pages/)[0-9]+'   # → PAGE_ID
```

### 6. Componi il body finale

```html
<table>
  <tbody>
    <tr>
      <th>Ultima modifica</th>
      <td><DD/MM/YYYY></td>
    </tr>
    <tr>
      <th>File di riferimento</th>
      <td><code><file1></code>, <code><file2></code></td>
    </tr>
    <tr>
      <th>Tag</th>
      <td><tag1>, <tag2>, <tag3></td>
    </tr>
  </tbody>
</table>

<body generato e approvato>

<h2>Link correlati</h2>
<ul>
  <li></li>
</ul>
```

### 7. Pubblica su Confluence

Usa il tool MCP `createConfluencePage` con:
- `spaceKey`: estratto al passo 5
- `parentId`: PAGE_ID estratto al passo 5
- `title`: titolo confermato dall'utente
- `body`: HTML composto al passo 6

Poi aggiungi le label:
```bash
source "${CLAUDE_PLUGIN_DATA}/.env"
DOMAIN=$(echo "$CONFLUENCE_PARENT_URL" | grep -oP 'https://[^/]+')
curl -sf -o /dev/null \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST "$DOMAIN/wiki/rest/api/content/<NEW_PAGE_ID>/label" \
  -d '[{"prefix":"global","name":"<tag1>"},{"prefix":"global","name":"<tag2>"}]'
```

### 8. Conferma

Mostra all'utente:
- Pagina creata: `<titolo>` → `<URL pagina>`
- Label aggiunte: `<lista tag>`
