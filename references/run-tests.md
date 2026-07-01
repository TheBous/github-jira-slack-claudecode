# Come runnare i test del progetto

Cerca i test runner disponibili nel progetto in questo ordine:

**JavaScript/TypeScript** — leggi `package.json` e raccogli tutti gli script il cui nome contiene `test`, `lint`, `check`, o `typecheck`:
```bash
cat package.json | python3 -c "
import sys, json
scripts = json.load(sys.stdin).get('scripts', {})
for k, v in scripts.items():
    if any(w in k for w in ['test', 'lint', 'check', 'typecheck']):
        print(k)
"
```

**Fallback** — se non c'è `package.json`, controlla in ordine:
- `Makefile`: cerca target `test`, `lint`, `check` con `grep -E '^(test|lint|check):' Makefile`
- `pyproject.toml` / `setup.py`: usa `pytest`
- `go.mod`: usa `go test ./...`

Runna tutti gli script trovati. Se uno fallisce:
- Analizza l'output dell'errore
- Correggi il codice
- Riruna solo lo script fallito
- Ripeti fino a quando passa (max 3 tentativi per script, poi riporta il fallimento all'utente)
