---
description: Sviluppa una feature o fix sul branch corrente, runna i test e aggiorna la documentazione
---

## Obiettivo

Implementare una feature o fix partendo dal contesto del branch/ticket corrente, garantendo che i test passino e la documentazione sia aggiornata.

## Passi

### 1. Raccogli il contesto

Estrai la Jira key dal branch corrente (pattern `[A-Z]+-[0-9]+`):
```bash
git branch --show-current
```

Se trovata, recupera titolo e descrizione del ticket con il tool MCP `getJiraIssue` con `issueKey: "<KEY>"` e `fields: ["summary", "description"]`.

Mostra all'utente:
```
🎫 Ticket: <KEY> — <titolo>
📋 <descrizione troncata a 300 caratteri>

È questo che vuoi implementare? Vuoi aggiungere dettagli o correggere la direzione?
```

Attendi risposta e integra eventuali precisazioni prima di procedere.

### 2. Scegli il flusso di sviluppo

Chiedi all'utente:
```
Come vuoi approcciare questo task?

1. 🧠 Brainstorming — esplora opzioni e approcci prima di scrivere codice
2. 🔥 Grilling — sessione di domande per definire i requisiti nel dettaglio
3. ⚡ Diretto — implementa subito senza un flusso preliminare
```

- Se sceglie **1**: invoca la skill `superpowers:brainstorming` prima di procedere
- Se sceglie **2**: invoca la skill `grilling` prima di procedere
- Se sceglie **3**: vai direttamente al passo 3

### 3. Implementa

Leggi il codice rilevante nel repository per capire il contesto prima di scrivere. Implementa la feature o fix rispettando le convenzioni del codebase esistente.

Dopo ogni modifica significativa, mostra brevemente cosa hai fatto prima di continuare.

### 4. Runna i test

Leggi `references/run-tests.md` (nella root del plugin) e segui le istruzioni per trovare e runnare i test/lint/check del progetto.

### 5. Aggiorna la documentazione

Recupera i file modificati:
```bash
git diff HEAD --name-only
```

**Docs locale** — se esiste `docs/`:
```bash
ls docs/ 2>/dev/null && grep -rl "<file-modificato>" docs/ 2>/dev/null
```

**Confluence** — se `CONFLUENCE_PARENT_URL` è configurato nel `.env`:
```bash
source "${CLAUDE_PLUGIN_DATA}/.env"
```
Estrai il `PARENT_PAGE_ID` e usa il tool MCP `searchConfluenceUsingCql`:
```
ancestor = <PARENT_PAGE_ID> AND (text ~ "<file1>" OR text ~ "<file2>")
```

Se trova candidati (locali o Confluence), mostra:
```
📄 Documentazione da aggiornare:
- [locale] docs/auth.md
- [Confluence] <titolo> → <url>

Vuoi aggiornarli? (sì/no/elenca quali)
```

Attendi conferma. Per ogni doc confermato, aggiorna il contenuto rilevante riflettendo i cambi implementati.

### 6. Conferma finale

Mostra all'utente:
- ✅ Feature/fix implementata
- ✅ Test: `<lista script>` — tutti verdi
- ✅ Documentazione aggiornata: `<lista file/pagine>` (se applicabile)
- → Suggerisci il prossimo step: `/jira-git-sync:create-pr`
