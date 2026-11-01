# MysteryTwister × Harbor

Reproducible Harbor benchmark for challenges from
[MysteryTwister](https://www.mysterytwister.org/) (MTC3, CrypTool). Harbor and
OpenCode run in containers; the host only needs Podman and a Compose provider.

## Pinned versions

| Component | Version | Location |
|---|---:|---|
| Harbor | 0.25.0 | Controller image |
| Python | 3.14.8 | Controller and task image |
| OpenCode | 2.2.2 (`@opencode/cli`) | Task image |
| podman-compose | 1.6.0 | Controller image |
| Python dependencies | fully pinned | `requirements.lock` |

Versions are deliberately pinned so a later run does not silently install
different software. `latest` is not used.

## Architecture

```text
Host
└── rootless Podman + API socket
    ├── Controller container
    │   └── Harbor 0.25.0 + podman-compose
    └── Task container per trial
        ├── OpenCode 2.2.2
        ├── Challenge files
        └── Agent + verifier (shared)
```

The controller controls the host's Podman service through the mounted socket.
The project is mounted at the same absolute path as on the host so that the
bind mounts created by Harbor also resolve correctly for the Podman service.

> The Podman socket allows control of the containers of the logged-in user.
> The controller container is intentionally granted this permission.

## Project structure

```text
.
├── Containerfile                  # Harbor controller
├── compose.yaml                   # declarative controller start
├── compose.host-network.yaml      # optional host-network workaround
├── compose.opencode-go.yaml       # optional Go key for the controller
├── compose.openrouter.yaml        # optional OpenRouter key for the controller
├── requirements.lock              # pinned Python dependencies
├── run.sh                         # build + start, no host venv
├── configs/
│   ├── caesar-opencode2.yaml      # free Zen model
│   ├── caesar-opencode-go.yaml    # paid Go model (opt-in)
│   ├── caesar-openrouter.yaml     # free Nemotron model via OpenRouter
│   ├── mysterytwister-all-*.yaml  # all tasks, different models
│   └── mysterytwister-all-opencode-go.yaml
├── local/
│   ├── analyze_job.py             # tool durations and token analysis
│   ├── containers.conf            # Compose provider in the controller
│   ├── harbor-entrypoint.sh       # reads optional credentials
│   ├── host-network.override.yaml # workaround for task containers
│   ├── opencode-auth.override.yaml # read-only host login, if present
│   └── opencode2_agent.py         # uses the preinstalled OpenCode 2
└── mysterytwister-caesar-62/
    ├── instruction.md
    ├── task.toml
    ├── environment/
    │   ├── Dockerfile             # task + OpenCode 2.2.2
    │   ├── opencode2-wrapper.sh   # CLI compatibility + private server
    │   └── ciphertext.txt
    ├── solution/solve.sh          # oracle solution
    └── tests/                     # verifier
```

## Quick start on a new Linux system

Requirements: Podman and a working Compose provider. Python, pip, Node, npm,
Harbor and OpenCode do **not** need to be installed on the host.

```bash
podman --version
podman compose version
systemctl --user enable --now podman.socket

cd /path/to/project
./run.sh
```

`run.sh` builds the images, starts the controller and by default runs
`configs/caesar-opencode2.yaml`. Results are written on the host under `jobs/`.

Validate only, without running task containers:

```bash
./run.sh -c configs/caesar-opencode2.yaml --dry-run
```

Oracle or negative control:

```bash
./run.sh -c configs/caesar-opencode2.yaml -a oracle
./run.sh -c configs/caesar-opencode2.yaml -a nop
```

## Declarative job

`configs/caesar-opencode2.yaml` contains the task, agent, model and runtime:

```yaml
tasks:
  - path: mysterytwister-caesar-62
agents:
  - import_path: opencode2_agent:PreinstalledOpenCode2
    model_name: opencode/deepseek-v4.1-flash-free
environment:
  type: podman
```

The run therefore matches Harbor's documented format
`harbor run --config <config.yaml>`. The custom agent also follows the official
`module.path:ClassName` interface; it only skips installation because OpenCode
is already in the task image.

The job can be combined with further Harbor options without changing any files,
for example:

```bash
./run.sh -c configs/caesar-opencode2.yaml -n 1 --job-name caesar-test
```

An existing host login is reused automatically:

```bash
opencode auth login opencode
```

If `${XDG_CONFIG_HOME:-~/.config}/opencode/service.json` exists, `run.sh`
mounts this file read-only via `local/opencode-auth.override.yaml` to
`/root/.config/opencode/service.json` in the task container. The path is
parameterized via `OPENCODE_HOST_CONFIG_DIR`. Credentials are neither copied
into the image or repository nor stored under `/logs`.

The free Zen model has a usage limit. If Harbor reports
`provider.free-limit` / HTTP 429 in the agent log, the quota is exhausted — not
an error in the task or container setup. Wait for the reset, configure another
model, or use an OpenCode Go subscription:

For an immediate run with the paid Go model:

```bash
# once on the host, if no Go login exists yet
opencode auth login opencode-go

./run.sh -c configs/caesar-opencode-go.yaml
```

Only this explicit Go configuration enables forwarding of the Go key.
`run.sh` calls `opencode auth export` on the host and selects the **active**
`opencode-go` entry in the controller. The temporary export file is created
with mode 0600 in the runtime directory, mounted read-only, and deleted after
the run. Alternatively, `OPENCODE_API_KEY` can be set directly; then no export
is needed. Because of the opt-in, the default job does not unintentionally
consume Go quota.

For NVIDIA Nemotron 3.5 Super VL via OpenRouter, the key is stored once,
protected outside the project:

```bash
install -d -m 700 ~/.config/harbour
(umask 077; printf '%s' '<openrouter-key>' > ~/.config/harbour/openrouter.key)

./run.sh -c configs/caesar-openrouter.yaml
```

The job file uses `openrouter/nvidia/nemotron-3.5-super-vl:free`.
`run.sh` mounts `~/.config/harbour/openrouter.key` read-only into the controller
only for this configuration. Alternatively, `export OPENROUTER_API_KEY=...`
works; the environment variable takes precedence. The path can be changed via
`OPENROUTER_HOST_SECRET_FILE`.

OpenRouter currently limits free models to **50 requests per day** per account.
Switching models does not bypass this limit. For a later run there are also:

```bash
./run.sh -c configs/mysterytwister-all-openrouter-lightning.yaml
# or immediately with the existing OpenCode Go subscription:
./run.sh -c configs/mysterytwister-all-opencode-go.yaml
```

`OPENCODE_API_KEY`, `OPENROUTER_API_KEY`, `OPENAI_API_KEY` and
`ANTHROPIC_API_KEY` are only passed to the controller if they are set on the
host or the respective key file exists.

## Without the wrapper

The wrapper only handles paths, the socket, and the optional host workaround.
The equivalent direct invocation is:

```bash
export HOST_PROJECT_DIR="$PWD"
export PODMAN_SOCKET="${XDG_RUNTIME_DIR}/podman/podman.sock"

podman compose -f compose.yaml build harbor
podman compose -f compose.yaml run --rm -T harbor \
  run -c configs/caesar-opencode2.yaml
```

## Included challenges

- **Caesar Encryption**: modified 62-character alphabet `a-z`, `A-Z`, `0-9`
  with shift 4. The verifier compares the plaintext case-sensitively.
- **Autokey Cipher**: short keyword plus plaintext as the key stream; known
  word `WORLD`. The verifier ignores case and whitespace.
- **M-138 – Part 1**: 25 known strips, only the common offset is unknown. The
  verifier ignores case and whitespace.
- **Merkle-Hellman Knapsack – Part 1**: superincreasing subset-sum with
  ASCII-encoded plaintext. The verifier requires the exact spelling.
- **The Impatient Notary** (Level 2): three RSA keys with small private
  exponents, attack via Wiener's continued fractions. The verifier checks the
  required SHA-256 digest.

Each task writes `0` or `1` to `/logs/verifier/reward.txt`. The solution is not
in the agent image: `tests/` is mounted only for verification, `solution/` only
for the oracle agent.

All five tasks together:

```bash
./run.sh -c configs/mysterytwister-all-openrouter.yaml
```

## Tool usage and duration

After each agent run, `run.sh` automatically creates:

```text
jobs/<job>/tool_usage.json
```

It contains per trial:

- number of tool calls and calls per tool
- total, average, and maximum duration per tool
- total wall-clock time and non-tool time
- input, output, reasoning, and cache tokens
- model cost, if the provider reports it

Manually for an existing job:

```bash
python3 local/analyze_job.py jobs/<job>
```

## Adding a new challenge

1. Download the official challenge files from MysteryTwister.
2. Create a task folder following the existing schema:
   `environment/`, `tests/`, `solution/`, `instruction.md`, `task.toml`.
3. Copy `environment/opencode2-wrapper.sh` from an existing task and copy the
   official files to `/app` in `environment/Dockerfile`.
4. Write only the task statement in `instruction.md`; no solution.
5. In `tests/check_answer.py`, check the expected answer format and, in
   `tests/test.sh`, write `1` to `/logs/verifier/reward.txt` on success.
6. In `solution/solve.sh`, actually compute the answer from the challenge data.
   `APP_DIR` allows local tests outside the container.
7. Validate:

```bash
APP_DIR=/tmp/test-task bash mysterytwister-<name>/solution/solve.sh
.venv/bin/harbor lint mysterytwister-<name>
./run.sh -p mysterytwister-<name> -a oracle
./run.sh -p mysterytwister-<name> \
  -a opencode2_agent:PreinstalledOpenCode2 \
  -m openrouter/nvidia/nemotron-3.5-super-vl:free
```

8. Add the task path to the desired file under `configs/`.

## Validation

- Combined oracle run across all five tasks in
  `jobs/2026-10-30__10-45-54`: **5 trials, 0 exceptions, mean/reward 1.0**.
- The Level 2 task *The Impatient Notary* solves all three RSA keys via
  Wiener's attack (private exponents with 520, 516, and 518 bits) and produces
  the expected SHA-256 digest.
- Containerized dry run with task, custom agent, and Podman: successful.
- Oracle run Caesar `jobs/2026-10-30__09-44-31`: **1 trial, 0 exceptions,
  reward 1.0**.
- Full OpenCode 2.2.2 run with `opencode-go/deepseek-v4.1-flash` in
  `jobs/2026-10-30__10-19-08`: **1 trial, 0 exceptions, reward 1.0** in 64
  seconds. The agent wrote the correct plaintext; EPIPE did not occur. Measured
  model cost: about 0.00314 USD.
- OpenRouter run with `openrouter/nvidia/nemotron-3.5-super-vl:free` in
  `jobs/2026-10-30__10-28-14`: also **1 trial, 0 exceptions, reward 1.0**,
  this time in 74 seconds. Again: no EPIPE and no API key in the job files.
- Repeat of the OpenRouter run using only the protected key file in
  `jobs/2026-10-30__10-33-13`: **reward 1.0, 0 exceptions**; the key does not
  appear in any job file, and the file has mode 0600.
- Security check of the Go run: the active API key does not appear in any file
  in the job directory, and the temporary credential export was deleted.
- The earlier free OpenCode run `jobs/2026-10-30__09-42-53` ended with reward 0
  because the free model quota was exhausted (`provider.free-limit`, HTTP 429).
  This is not an error in the task or container setup.

## Host-specific notes

`wlp4s0` has the unusual prefix `/0` on this host. As a result, netavark cannot
find a free bridge subnet. `run.sh` detects this automatically and uses:

- `compose.host-network.yaml` for the controller,
- `local/host-network.override.yaml` for the task container.

On a host with a normal prefix, these files are not activated; the portable
base configuration remains unchanged.

The verifier intentionally runs in the same container as the agent. `harbor
lint` therefore reports only `shared-verifier`. A separate verifier would be
possible for stricter isolation, but is currently not reliably testable with
the host-network workaround.

## Official reference

The setup follows the documentation for **Harbor v0.25.0**, in particular:

- [Installation](https://github.com/harbor-framework/harbor/blob/v0.25.0/docs-mintlify/getting-started/installation.mdx)
- [Jobs and configs](https://github.com/harbor-framework/harbor/blob/v0.25.0/docs-mintlify/jobs/configs.mdx)
- [Custom agents](https://github.com/harbor-framework/harbor/blob/v0.25.0/docs-mintlify/agents/custom-agents.mdx)
- [Task environments](https://github.com/harbor-framework/harbor/blob/v0.25.0/docs-mintlify/tasks/environment.mdx)
