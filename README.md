# MysteryTwister × Harbor

Reproduzierbarer Harbor-Benchmark für Challenges von
[MysteryTwister](https://www.mysterytwister.org/) (MTC3, CrypTool). Harbor und
OpenCode laufen in Containern; auf dem Host werden nur Podman und ein
Compose-Provider benötigt.

## Fixierte Versionen

| Komponente | Version | Ort |
|---|---:|---|
| Harbor | 0.25.0 | Controller-Image |
| Python | 3.14.8 | Controller- und Task-Image |
| OpenCode | 2.2.2 (`@opencode/cli`) | Task-Image |
| podman-compose | 1.6.0 | Controller-Image |
| Python-Abhängigkeiten | komplett fixiert | `requirements.lock` |

Die Versionen sind bewusst gepinnt, damit ein späterer Lauf nicht unbemerkt
andere Software installiert. `latest` wird nicht verwendet.

## Architektur

```text
Host
└── rootless Podman + API-Socket
    ├── Controller-Container
    │   └── Harbor 0.25.0 + podman-compose
    └── Task-Container pro Trial
        ├── OpenCode 2.2.2
        ├── Challenge-Dateien
        └── Agent + Verifier (shared)
```

Der Controller steuert den Podman-Service des Hosts über den gemounteten
Socket. Das Projekt wird unter demselben absoluten Pfad wie auf dem Host
gemountet, damit die von Harbor erzeugten Bind-Mounts auch für den
Podman-Service stimmen.

> Der Podman-Socket erlaubt die Steuerung der Container des angemeldeten
> Benutzers. Der Controller-Container erhält diese Berechtigung bewusst.

## Projektstruktur

```text
.
├── Containerfile                  # Harbor-Controller
├── compose.yaml                   # deklarativer Controller-Start
├── compose.host-network.yaml      # optionaler Host-Netz-Workaround
├── compose.opencode-go.yaml       # optionaler Go-Key für den Controller
├── compose.openrouter.yaml        # optionaler OpenRouter-Key für den Controller
├── requirements.lock              # fixierte Python-Abhängigkeiten
├── run.sh                         # Build + Start, ohne Host-venv
├── configs/
│   ├── caesar-opencode2.yaml      # freies Zen-Modell
│   ├── caesar-opencode-go.yaml    # kostenpflichtiges Go-Modell (Opt-in)
│   ├── caesar-openrouter.yaml     # freies Nemotron-Modell über OpenRouter
│   ├── mysterytwister-all-*.yaml  # alle Tasks, verschiedene Modelle
│   └── mysterytwister-all-opencode-go.yaml
├── local/
│   ├── analyze_job.py             # Tool-Dauern und Token-Auswertung
│   ├── containers.conf            # Compose-Provider im Controller
│   ├── harbor-entrypoint.sh       # liest optionale Credentials
│   ├── host-network.override.yaml # Workaround für Task-Container
│   ├── opencode-auth.override.yaml # read-only Host-Login, falls vorhanden
│   └── opencode2_agent.py         # nutzt das vorinstallierte OpenCode 2
└── mysterytwister-caesar-62/
    ├── instruction.md
    ├── task.toml
    ├── environment/
    │   ├── Dockerfile             # Task + OpenCode 2.2.2
    │   ├── opencode2-wrapper.sh   # CLI-Kompatibilität + privater Server
    │   └── ciphertext.txt
    ├── solution/solve.sh          # Oracle-Lösung
    └── tests/                     # Verifier
```

## Schnellstart auf einem neuen Linux-System

Voraussetzungen: Podman und ein funktionierender Compose-Provider. Python, pip,
Node, npm, Harbor und OpenCode müssen **nicht** auf dem Host installiert sein.

```bash
podman --version
podman compose version
systemctl --user enable --now podman.socket

cd /pfad/zum/projekt
./run.sh
```

`run.sh` baut die Images, startet den Controller und führt standardmäßig
`configs/caesar-opencode2.yaml` aus. Ergebnisse landen auf dem Host unter
`jobs/`.

Nur prüfen, ohne Container der Task auszuführen:

```bash
./run.sh -c configs/caesar-opencode2.yaml --dry-run
```

Oracle beziehungsweise Negativkontrolle:

```bash
./run.sh -c configs/caesar-opencode2.yaml -a oracle
./run.sh -c configs/caesar-opencode2.yaml -a nop
```

## Deklarativer Job

`configs/caesar-opencode2.yaml` enthält Task, Agent, Modell und Runtime:

```yaml
tasks:
  - path: mysterytwister-caesar-62
agents:
  - import_path: opencode2_agent:PreinstalledOpenCode2
    model_name: opencode/deepseek-v4.1-flash-free
environment:
  type: podman
```

Damit entspricht der Lauf dem von Harbor dokumentierten Format
`harbor run --config <config.yaml>`. Der Custom Agent folgt ebenfalls der
offiziellen Schnittstelle `module.path:ClassName`; er überspringt lediglich die
Installation, weil OpenCode bereits im Task-Image liegt.

Der Job kann ohne Änderung an den Dateien mit weiteren Harbor-Optionen
kombiniert werden, zum Beispiel:

```bash
./run.sh -c configs/caesar-opencode2.yaml -n 1 --job-name caesar-test
```

Ein vorhandener Host-Login wird automatisch wiederverwendet:

```bash
opencode auth login opencode
```

Wenn `${XDG_CONFIG_HOME:-~/.config}/opencode/service.json` existiert, hängt
`run.sh` diese Datei über `local/opencode-auth.override.yaml` read-only nach
`/root/.config/opencode/service.json` im Task-Container. Der Pfad wird über
`OPENCODE_HOST_CONFIG_DIR` parametrisiert. Credentials werden weder ins Image
oder Repository kopiert noch unter `/logs` gespeichert.

Das freie Zen-Modell hat ein Nutzungslimit. Falls Harbor im Agenten-Log
`provider.free-limit` / HTTP 429 meldet, ist das Kontingent erschöpft – kein
Fehler des Tasks oder der Container-Einrichtung. Dann auf den Reset warten, ein
anderes Modell konfigurieren oder einen OpenCode-Go-Zugang verwenden:

Für den sofortigen Lauf mit dem kostenpflichtigen Go-Modell:

```bash
# einmalig auf dem Host, falls noch kein Go-Login besteht
opencode auth login opencode-go

./run.sh -c configs/caesar-opencode-go.yaml
```

Nur diese ausdrückliche Go-Konfiguration aktiviert die Weitergabe des Go-Keys.
`run.sh` ruft dafür `opencode auth export` auf dem Host auf und wählt im
Controller den **aktiven** `opencode-go`-Eintrag aus. Die temporäre Exportdatei
liegt mit Modus 0600 im Runtime-Verzeichnis, wird read-only gemountet und nach
dem Lauf gelöscht. Alternativ kann `OPENCODE_API_KEY` direkt gesetzt werden; dann
ist kein Export nötig. Durch das Opt-in verbraucht der Standardjob nicht
unbeabsichtigt Go-Kontingent.

Für NVIDIA Nemotron 3.5 Super VL über OpenRouter wird der Key einmalig
geschützt außerhalb des Projekts gespeichert:

```bash
install -d -m 700 ~/.config/harbour
(umask 077; printf '%s' '<openrouter-key>' > ~/.config/harbour/openrouter.key)

./run.sh -c configs/caesar-openrouter.yaml
```

Die Jobdatei verwendet `openrouter/nvidia/nemotron-3.5-super-vl:free`.
`run.sh` mountet `~/.config/harbour/openrouter.key` nur für diese Konfiguration
read-only in den Controller. Alternativ funktioniert
`export OPENROUTER_API_KEY=...`; die Umgebungsvariable hat Vorrang. Der Pfad
lässt sich über `OPENROUTER_HOST_SECRET_FILE` ändern.

OpenRouter begrenzt kostenlose Modelle derzeit kontoseitig auf **50 Requests
pro Tag**. Ein Modellwechsel umgeht dieses Limit nicht. Für einen späteren Lauf
gibt es zusätzlich:

```bash
./run.sh -c configs/mysterytwister-all-openrouter-lightning.yaml
# oder sofort mit dem vorhandenen OpenCode-Go-Zugang:
./run.sh -c configs/mysterytwister-all-opencode-go.yaml
```

`OPENCODE_API_KEY`, `OPENROUTER_API_KEY`, `OPENAI_API_KEY` und
`ANTHROPIC_API_KEY` werden nur dann an den Controller durchgereicht, wenn sie
auf dem Host gesetzt sind beziehungsweise die jeweilige Key-Datei existiert.

## Ohne Wrapper

Der Wrapper übernimmt nur Pfade, Socket und den optionalen Host-Workaround.
Äquivalent geht es direkt:

```bash
export HOST_PROJECT_DIR="$PWD"
export PODMAN_SOCKET="${XDG_RUNTIME_DIR}/podman/podman.sock"

podman compose -f compose.yaml build harbor
podman compose -f compose.yaml run --rm -T harbor \
  run -c configs/caesar-opencode2.yaml
```

## Enthaltene Challenges

- **Caesar Encryption**: modifiziertes 62-Zeichen-Alphabet `a-z`, `A-Z`, `0-9`
  mit Shift 4. Der Verifier vergleicht den Klartext case-sensitiv.
- **Autokey Cipher**: kurzes Keyword plus Klartext als Schlüsselstrom; bekannte
  Vokabel `WORLD`. Der Verifier ignoriert Groß-/Kleinschreibung und Leerzeichen.
- **M-138 – Part 1**: 25 bekannte Strips, nur der gemeinsame Offset ist
  unbekannt. Der Verifier ignoriert Groß-/Kleinschreibung und Leerzeichen.
- **Merkle-Hellman Knapsack – Part 1**: superincreasing Subset-Sum mit
  ASCII-kodiertem Klartext. Der Verifier verlangt die exakte Schreibweise.
- **The Impatient Notary** (Level 2): drei RSA-Schlüssel mit kleinem privaten
  Exponenten, Angriff über Wieners Continued Fractions. Der Verifier prüft den
  geforderten SHA-256-Digest.

Jeder Task schreibt `0` oder `1` nach `/logs/verifier/reward.txt`. Die Lösung
steckt nicht im Agenten-Image: `tests/` wird erst für die Verifikation
eingehängt, `solution/` nur für den Oracle-Agenten.

Alle fünf Tasks zusammen:

```bash
./run.sh -c configs/mysterytwister-all-openrouter.yaml
```

## Tool-Usage und Dauer

Nach jedem Agentenlauf erzeugt `run.sh` automatisch:

```text
jobs/<job>/tool_usage.json
```

Darin stehen pro Trial:

- Anzahl der Tool-Aufrufe und Aufrufe je Tool
- Gesamt-, Durchschnitts- und Maximaldauer je Tool
- gesamte Wall-Clock-Zeit und Nicht-Tool-Zeit
- Input-, Output-, Reasoning- und Cache-Tokens
- Modellkosten, soweit der Provider sie meldet

Manuell für einen bestehenden Job:

```bash
python3 local/analyze_job.py jobs/<job>
```

## Neue Challenge hinzufügen

1. Offizielle Challenge-Dateien von MysteryTwister herunterladen.
2. Task-Ordner nach dem bestehenden Schema anlegen:
   `environment/`, `tests/`, `solution/`, `instruction.md`, `task.toml`.
3. `environment/opencode2-wrapper.sh` aus einem bestehenden Task kopieren und
   die offiziellen Dateien im `environment/Dockerfile` nach `/app` kopieren.
4. Nur die Aufgabenstellung in `instruction.md` schreiben; keine Lösung.
5. In `tests/check_answer.py` das erwartete Antwortformat prüfen und in
   `tests/test.sh` bei Erfolg `1` nach `/logs/verifier/reward.txt` schreiben.
6. In `solution/solve.sh` die Antwort tatsächlich aus den Challenge-Daten
   berechnen. `APP_DIR` erlaubt lokale Tests außerhalb des Containers.
7. Prüfen:

```bash
APP_DIR=/tmp/test-task bash mysterytwister-<name>/solution/solve.sh
.venv/bin/harbor lint mysterytwister-<name>
./run.sh -p mysterytwister-<name> -a oracle
./run.sh -p mysterytwister-<name> \
  -a opencode2_agent:PreinstalledOpenCode2 \
  -m openrouter/nvidia/nemotron-3.5-super-vl:free
```

8. Den Task-Pfad in die gewünschte Datei unter `configs/` aufnehmen.

## Validierung

- Gemeinsamer Oracle-Lauf über alle fünf Tasks in
  `jobs/2026-10-30__10-45-54`: **5 Trials, 0 Exceptions, Mean/Reward 1.0**.
- Der Level-2-Task *The Impatient Notary* löst alle drei RSA-Schlüssel per
  Wiener-Angriff (private Exponenten mit 520, 516 und 518 Bit) und erzeugt den
  erwarteten SHA-256-Digest.
- Containerisierter Dry-Run mit Task, Custom Agent und Podman: erfolgreich.
- Oracle-Lauf Caesar `jobs/2026-10-30__09-44-31`: **1 Trial, 0 Exceptions,
  Reward 1.0**.
- Vollständiger OpenCode-2.2.2-Lauf mit `opencode-go/deepseek-v4.1-flash` in
  `jobs/2026-10-30__10-19-08`: **1 Trial, 0 Exceptions, Reward 1.0** in 64
  Sekunden. Der Agent schrieb den korrekten Klartext; EPIPE trat nicht auf.
  Gemessene Modellkosten: etwa 0,00314 USD.
- OpenRouter-Lauf mit `openrouter/nvidia/nemotron-3.5-super-vl:free` in
  `jobs/2026-10-30__10-28-14`: ebenfalls **1 Trial, 0 Exceptions, Reward 1.0**,
  diesmal in 74 Sekunden. Auch hier: kein EPIPE und kein API-Key in den
  Job-Dateien.
- Wiederholung des OpenRouter-Laufs allein über die geschützte Key-Datei in
  `jobs/2026-10-30__10-33-13`: **Reward 1.0, 0 Exceptions**; der Key kommt in
  keiner Job-Datei vor, die Datei hat Modus 0600.
- Sicherheitsprüfung des Go-Laufs: Der aktive API-Key kommt in keiner Datei des
  Job-Verzeichnisses vor, und der temporäre Credential-Export wurde gelöscht.
- Der frühere freie OpenCode-Lauf `jobs/2026-10-30__09-42-53` endete mit Reward
  0, weil das kostenlose Modellkontingent erschöpft war (`provider.free-limit`,
  HTTP 429). Das ist kein Fehler des Tasks oder der Container-Einrichtung.

## Besonderheiten dieses Hosts

`wlp4s0` hat hier das ungewöhnliche Präfix `/0`. Dadurch kann netavark kein
freies Bridge-Subnetz finden. `run.sh` erkennt das automatisch und verwendet:

- `compose.host-network.yaml` für den Controller,
- `local/host-network.override.yaml` für den Task-Container.

Auf einem Host mit normalem Präfix werden diese Dateien nicht aktiviert; die
portable Basiskonfiguration bleibt unverändert.

Der Verifier läuft bewusst im selben Container wie der Agent. `harbor lint`
meldet deshalb nur `shared-verifier`. Ein separater Verifier wäre für strengere
Isolation möglich, ist mit dem Host-Network-Workaround aber derzeit nicht
zuverlässig testbar.

## Offizieller Referenzpunkt

Die Einrichtung folgt der Dokumentation für **Harbor v0.25.0**, insbesondere:

- [Installation](https://github.com/harbor-framework/harbor/blob/v0.25.0/docs-mintlify/getting-started/installation.mdx)
- [Jobs und Configs](https://github.com/harbor-framework/harbor/blob/v0.25.0/docs-mintlify/jobs/configs.mdx)
- [Custom Agents](https://github.com/harbor-framework/harbor/blob/v0.25.0/docs-mintlify/agents/custom-agents.mdx)
- [Task-Environments](https://github.com/harbor-framework/harbor/blob/v0.25.0/docs-mintlify/tasks/environment.mdx)
