---
description: Crea una PR su GitHub verso main, commenta su Jira e notifica Slack
---

## Obiettivo

Creare una Pull Request per il branch corrente verso `main`, generando automaticamente titolo e descrizione dal ticket Jira e dalle differenze col branch.

## Passi

### 1. Verifica stato

```bash
git branch --show-current
git status --short
```

Se ci sono modifiche non committate, avvisa l'utente e chiedi se vuole procedere ugualmente.

Verifica che il branch sia pushato su origin:
```bash
git ls-remote --exit-code origin "$(git branch --show-current)" 2>/dev/null || echo "NOT_PUSHED"
```

Se non pushato:
```bash
git push -u origin "$(git branch --show-current)"
```

### 2. Estrai ticket Jira e recupera i dettagli

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
print('DESC:', (d.get('description') or '')[:500])
"
```

### 3. Analizza le differenze col branch base

Recupera il diff completo rispetto a main:
```bash
git diff main...HEAD --stat
git log main..HEAD --pretty=format:"%s" --no-merges
git diff main...HEAD -- . ':(exclude)*.lock' ':(exclude)package-lock.json'
```

Analizza il diff per identificare:
- Quali file sono stati aggiunti, modificati, rimossi
- Il tipo di cambiamento (bug fix, nuova feature, refactoring, ecc.)
- Se ci sono breaking changes
- Se sono stati aggiunti test

### 4. Genera titolo e descrizione automaticamente

**Titolo**: `[<KEY>] <titolo del ticket Jira>` — se non c'è ticket, usa il titolo del commit più recente.

**Descrizione**: compila il seguente template basandoti sull'analisi del diff e sui dettagli del ticket Jira. Non lasciare sezioni con placeholder generici — ogni sezione deve riflettere le modifiche reali rilevate nel diff.

```markdown
## Summary
[1-3 frasi che spiegano cosa fa questa PR e perché, basate sul titolo/descrizione Jira e sul diff]

## Changes
- [Lista puntata delle modifiche specifiche rilevate nel diff]
- [Raggruppa i cambiamenti correlati]
- [Specifica cosa è stato aggiunto, modificato, o rimosso]

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Refactoring (no functional changes)

## Testing
- [ ] [Descrivi il testing eseguito, rilevato dai file di test nel diff]
- [ ] [Elenca eventuali nuovi test aggiunti]
- [ ] [Note su eventuali step di test manuali]

## Breaking Changes
[Se applicabile, descrivi breaking changes e migration steps; altrimenti scrivi "None"]

## Related Issues
Fixes <JIRA_BASE_URL>/browse/<KEY>

## Screenshots
[Se applicabile, aggiungi screenshot; altrimenti rimuovi questa sezione]

## Additional Context
[Qualsiasi altro contesto utile per i reviewer, oppure rimuovi questa sezione se non necessario]
```

Spunta automaticamente il checkbox corretto in "Type of Change" in base al diff analizzato.

### 5. Crea la PR

```bash
gh pr create \
  --base main \
  --title "<titolo generato>" \
  --body "<descrizione generata>"
```

Cattura l'URL della PR dall'output.

### 6. Transizione e commento Jira

Se c'è un ticket e `JIRA_IN_REVIEW_ID` è configurato e non vuoto:
```bash
source "${CLAUDE_PLUGIN_DATA}/.env"
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

### 7. Notifica Slack

```bash
source "${CLAUDE_PLUGIN_DATA}/.env"
curl -sf -o /dev/null -X POST "$SLACK_WEBHOOK_URL" \
  -H "Content-type: application/json" \
  -d "{\"text\":\"🔍 PR aperta: *<TITOLO_PR>*\n🔗 <PR_URL>\n🎫 <$JIRA_BASE_URL/browse/<KEY>|<KEY>> → *In Review*\"}"
```

Se non c'è ticket Jira: `🔍 PR aperta: *<TITOLO_PR>*\n🔗 <PR_URL>`

### 8. Conferma

Mostra all'utente:
- PR creata: `<PR_URL>`
- Ticket `<KEY>` → In Review (se applicabile)
- Slack: notificato
