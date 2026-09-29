# MD-LibreTranslate

MessyDesk service descriptor for [LibreTranslate](https://github.com/LibreTranslate/LibreTranslate), a self-hosted
machine translation API. Unlike the other `MD-*` repositories in this workspace, this service does not run its own
Python/FastAPI wrapper — LibreTranslate already exposes an HTTP API, so MessyDesk talks to it directly through a
bespoke adapter in `MD-consumers`.

This repository holds the service descriptor (`service.json`), a Nomad job spec (`nomad.hcl`), and this README.
There is no application code here.

## Prerequisites

A LibreTranslate instance must be running and reachable, by default at `http://localhost:5000`. See the
[LibreTranslate docs](https://docs.libretranslate.com/) for installation options (Docker image, pip package, etc.).
No API key is required for self-hosted instances.

## Tasks

* **`translate`** — Translate plain text. `source` defaults to `auto` (automatic language detection); `target`
  defaults to `en`.
* **`translate_html`** — Same as `translate`, but sends `format: "html"` to LibreTranslate so tags/attributes in the
  input are preserved and only text nodes are translated.
* **`detect_language`** — Detects the language of the input text and returns the LibreTranslate response (language
  code + confidence) as a JSON file, with no translation performed.

## Language list

The `source`/`target` dropdowns are populated **live** from the running LibreTranslate instance: on startup and on
every 30-second heartbeat, the `libretranslate` adapter (in `MD-consumers`) fetches `GET {local_url}/languages` and
replaces the dropdown values in the registered descriptor with whatever languages that instance actually has
installed (via its `enrichDescriptor()` hook — see `descriptor-resolution.md` in the `MD-consumers` wiki). If the
service isn't reachable yet (e.g. still starting up), the fetch is retried up to 5 times with exponential backoff
(1s, 2s, 4s, 8s, 8s) before giving up for that resolution attempt.

The static `values` lists committed in `service.json` are only a fallback, used if the live instance is unreachable
when the descriptor is first resolved — they don't need to be kept in sync manually.

## Limits

LibreTranslate has no built-in request size limit. The `libretranslate` adapter (in `MD-consumers`) enforces a hard
2MB input-size cap before sending text to the API, configurable via the `LIBRETRANSLATE_MAX_INPUT_SIZE` env var
(bytes) on the consumer process.

## Registering the descriptor

Since there's no running Python service to serve `/config`, point the `MD-consumers` process at this descriptor
explicitly via the `SERVICE_JSON_PATH` env var (see `service-descriptor-format.md` in the MessyDesk wiki for the full
descriptor resolution chain), e.g.:

```
SERVICE_JSON_PATH=/path/to/MD-LibreTranslate/service.json TOPIC=md-libretranslate MD_URL=http://localhost:8200 node src/index.mjs
```

## Running via Nomad

`nomad.hcl` runs LibreTranslate image (`localhost/libretranslate:1.9.6`) as a Nomad job.
Since LibreTranslate has no dedicated `/health` endpoint, the Nomad service `check` uses `GET /languages` instead —
it only returns 200 once the language models have finished loading and the API is actually ready. `MD-consumers`
auto-discovers this file (`nomad.hcl` alongside `service.json`, resolved from `SERVICE_JSON_PATH`) and uses it to
start/manage the job instead of requiring `DEV_URL`.

The adapter implementation lives at `MD-consumers/src/adapters/libretranslate.mjs`.
