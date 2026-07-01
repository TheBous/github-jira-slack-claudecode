---
description: Risolve i commenti di una code review, poi aggiorna la documentazione dove necessario
---

## Obiettivo

Leggere i commenti aperti di una PR GitHub, risolverli tramite la skill `superpowers:receiving-code-review`, e aggiornare la documentazione (locale e/o Confluence) se i cambi lo richiedono.

## Passi

### 1. Identifica la PR

Se l'utente ha passato un URL di PR nell'invocazione, usalo.

Altrimenti, rileva la PR dal branch corrente:
```bash
gh pr view --json number,title,url,headRefName 2>/dev/null
```

**Se il comando fallisce con un errore TLS/certificato**, usa questo fallback:
```bash
OWNER_REPO=$(git remote get-url origin | sed -E 's#.*[:/]([^/]+/[^/]+)(\.git)?$#\1#')
BRANCH=$(git branch --show-current)
curl -sf -H "Authorization: Bearer $(gh auth token)" \
  "https://api.github.com/repos/$OWNER_REPO/pulls?head=$(echo $OWNER_REPO | cut -d/ -f1):$BRANCH&state=open" \
  | jq '.[0] | {number, title, url: .html_url, headRefName: .head.ref}'
```

Se non esiste una PR aperta per il branch corrente, chiedi all'utente di passare l'URL esplicitamente.

### 2. Recupera i commenti della review

```bash
gh pr view <NUMERO> --json reviews,comments \
  --jq '.reviews[] | select(.state == "CHANGES_REQUESTED") | {author: .author.login, body: .body}'

gh api repos/:owner/:repo/pulls/<NUMERO>/comments \
  --jq '.[] | {path: .path, line: .line, body: .body, author: .user.login}'
```

**Fallback TLS**:
```bash
curl -sf -H "Authorization: Bearer $(gh auth token)" \
  "https://api.github.com/repos/$OWNER_REPO/pulls/<NUMERO>/reviews" \
  | jq '.[] | select(.state == "CHANGES_REQUESTED") | {author: .user.login, body}'

curl -sf -H "Authorization: Bearer $(gh auth token)" \
  "https://api.github.com/repos/$OWNER_REPO/pulls/<NUMERO>/comments" \
  | jq '.[] | {path, line, body, author: .user.login}'
```

Raccoglie sia i commenti generali che quelli inline sul codice.

### 3. Invoca la skill receiving-code-review

Usa il tool Skill con `superpowers:receiving-code-review`, passando come contesto i commenti recuperati al passo 2 e i file della PR.

Se la skill non è disponibile nel workspace, procedi manualmente: analizza i commenti, proponi le fix, applicale dopo conferma dell'utente.

### 4. Analizza il diff post-fix e individua doc da aggiornare

Dopo che le fix sono state applicate:
```bash
git diff HEAD --name-only
```

Per ogni file modificato, valuta se il cambiamento è logicamente significativo (nuova firma, comportamento cambiato, rimosso qualcosa di pubblico). Se sì, cerca documentazione correlata:

**Docs locale** — controlla se esiste una cartella `docs/` nel repo:
```bash
ls docs/ 2>/dev/null && grep -rl "<nome-file-modificato>" docs/ 2>/dev/null
```

**Confluence** — carica le credenziali e controlla se `CONFLUENCE_PARENT_URL` è configurato:
```bash
source "${CLAUDE_PLUGIN_DATA}/.env" 2>/dev/null
```

Se `CONFLUENCE_PARENT_URL` è non vuoto, usa il tool MCP `searchConfluenceUsingCql`:
```
ancestor = <PARENT_PAGE_ID> AND text ~ "<file-modificato>"
```

### 5. Chiedi conferma prima di aggiornare i doc

Se ha trovato candidati (locali o Confluence), mostra all'utente:
```
📄 Questi documenti potrebbero richiedere aggiornamento:
- [locale] docs/auth.md
- [Confluence] Flusso di autenticazione → <url>

Vuoi aggiornarli? (sì/no/elenca quali)
```

Attendi risposta prima di procedere.

### 6. Aggiorna la documentazione

**Docs locale**: modifica direttamente i file `.md` nella cartella `docs/` con le informazioni aggiornate. Mostra il diff prima di salvare.

**Confluence**: usa il tool MCP `updateConfluencePage` per ogni pagina confermata.

Se nessun documento è stato trovato o l'utente rifiuta, salta questo passo silenziosamente.

### 7. Rispondi ai commenti sulla PR

Per ogni commento risolto, posta una risposta inline usando questo template:

| Stato | Formato | Quando usarlo |
|-------|---------|---------------|
| ✅ Fixed | `✅ Fixed — <breve descrizione del cambio>` | Modifica applicata |
| 🔄 Refactored | `🔄 Refactored — <cosa è cambiato e perché>` | Fix che ha comportato una ristrutturazione più ampia |
| 💬 Acknowledged | `💬 Acknowledged — <motivazione per non cambiare>` | Commento valido ma non richiede modifica al codice |
| ❓ Clarification needed | `❓ Clarification needed — <domanda specifica>` | Il commento non è chiaro o serve più contesto dal reviewer |
| 🚫 Won't Fix | `🚫 Won't Fix — <motivazione tecnica o di prodotto>` | Scelta intenzionale di non applicare il cambiamento |
| ⛔ Stalled | `⛔ Stalled — <dipendenza o blocco>` | Non risolvibile ora, bloccato da qualcosa di esterno |

Posta la risposta con:
```bash
gh api repos/:owner/:repo/pulls/comments/<COMMENT_ID>/replies \
  -X POST -f body="<risposta con emoji>"
```

**Fallback TLS**:
```bash
curl -sf -X POST -H "Authorization: Bearer $(gh auth token)" \
  "https://api.github.com/repos/$OWNER_REPO/pulls/comments/<COMMENT_ID>/replies" \
  -d "{\"body\":\"<risposta con emoji>\"}"
```

### 9. Conferma

Mostra all'utente:
- Fix applicate ai commenti della review
- Risposte postate sulla PR con i relativi stati emoji
- Documentazione aggiornata: `<lista file/pagine>` (se applicabile)
- Suggerisci di fare push del branch con `git push`
