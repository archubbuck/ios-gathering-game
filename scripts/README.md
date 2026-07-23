# Baby names dataset ingestion

Standalone scripts (run via `tsx`, not Vercel functions) that populate the
`names` dataset from national/regional birth registries and Wikidata. All
are idempotent — safe to re-run for any year range or the full dataset.

This is being expanded beyond Wikidata per the decentralized-sources plan
(see the implementation plan referenced in this repo's history) —
additional registries, curated open-license datasets, enrichment APIs, and
a gender-inference synthesis script have all landed. Implemented: all 14
national/regional registries below, `ingest-sigpwned.ts` (see "Curated
datasets"), Wikidata, `ingest-usbabynames.ts`/`enrich-netstudy.ts` (see
"Enrichment"), and `infer-gender.ts` (see "Synthesis"). This completes
every source category from the original plan.

Two curated datasets from the original research were evaluated and
deliberately **not** built:

- **The Economist's baby-names repo** (connotation vectors) — its GitHub
  repo has no LICENSE file, so it defaults to standard copyright (all
  rights reserved) rather than a declared-open dataset like sigpwned's CC0
  or the government registries above. Skipped for the same reason as
  Behind-The-Name.
- **futureformed/baby-name-generator** — real and MIT-licensed (unlike the
  original research's description, which turned out not to match: it's a
  small demo React app, not a substantial dataset), but its `names.ts` is
  only ~120 hardcoded, unsourced entries for common names that already
  exist in this dataset from SSA/ONS — no meaningful new coverage, and the
  meaning/origin values have no stated provenance. Not worth ingesting as
  a claim source.

## Registries

All registry scripts share `scripts/lib/registryIngest.ts` — a common
upsert-names / write-`name_frequency` / derive-gender-claims pipeline. Each
script's own code is just "parse this source's specific file/API format
into a flat list of `{name, sex, year, rank, count}` rows," everything
after that is identical shared logic.

- `npm run ingest:ssa -- [--source=./names.zip] [--source-url=https://...] [--from-year=1980] [--to-year=2025] [--dry-run]`
  National SSA baby name data (`yobYYYY.txt` files, distributed as a zip or
  a directory of extracted files). Populates `names`, `name_frequency`
  (`source='ssa'`, `country='US'`), and `name_popularity_history` (unchanged
  shape — one row per name per year, using that name's own gender; SSA-only,
  see `migrations/1700000700000_add-name-frequency.js`). When `--source` is
  omitted, downloads `names.zip` from `https://www.ssa.gov/oact/babynames/names.zip`
  automatically; `--source-url` overrides the URL (use this to point at a mirror
  if ssa.gov is blocking requests — see "If the SSA auto-download fails" below).
- `npm run ingest:ons -- --source=./ons-data [--dry-run]`
  UK ONS baby name workbooks (`.xlsx`, one per sex per year, filenames like
  `boys-2022.xlsx`). Populates `names` and `name_frequency`
  (`source='ons'`, `country='GB'`) only. Column auto-detection can be
  overridden with `--name-column`/`--rank-column`/`--count-column`/`--sheet`
  for years whose table layout doesn't match the default headers.
- `npm run ingest:nyc -- [--page-size=5000] [--limit=50000] [--dry-run]`
  NYC DOHMH "Popular Baby Names" via the live Socrata SODA API (no local
  file needed). Rows are broken out by ethnicity subgroup — the script sums
  counts per (year, sex, name) and re-derives rank before writing. Populates
  `name_frequency` (`source='nyc'`, `country='US-NY'`). Optional
  `SODA_APP_TOKEN` env var (or `--app-token`) avoids throttling on repeated
  runs; works fine unauthenticated at lower volume.
- `npm run ingest:ontario -- --source=./data/ontario [--dry-run]`
  Ontario's two long-format CSVs (`baby_names_-_female_.csv`,
  `baby_names_-_male.csv`, from data.ontario.ca — download them yourself
  first). No rank column; derived by sorting count descending per
  (sex, year). Populates `name_frequency` (`source='ontario'`,
  `country='CA-ON'`).
- `npm run ingest:bc -- --source=./data/bc [--dry-run]`
  BC Vital Statistics' two **wide**-format CSVs (`baby-names-trends-f-*.csv`,
  `baby-names-trends-m-*.csv` from www2.gov.bc.ca — download them yourself
  first): one row per name, one column per year, not one row per
  name/year. The script pivots each into per-year rows and derives rank the
  same way as Ontario. Populates `name_frequency` (`source='bc'`,
  `country='CA-BC'`).
- `npm run ingest:chhs -- --source=./data/chhs/babyname.csv [--dry-run]`
  California CHHS "Top 25 Baby Names by Sex by Year" CSV (data.chhs.ca.gov —
  download it yourself first; the URL embeds a revision date that changes
  on every republish). Rank is already provided. Populates `name_frequency`
  (`source='chhs'`, `country='US-CA'`).
- `npm run ingest:alberta -- --source=./data/alberta [--dry-run]`
  Alberta's two XLSX files ("1980 to 2020" and "2021 to 2024",
  open.alberta.ca — download them yourself first). Full distribution
  (ranks observed past 2000), rank already provided. Populates
  `name_frequency` (`source='alberta'`, `country='CA-AB'`).
- `npm run ingest:nisra -- --source=./data/nisra-dashboard.xlsx [--sheet="Table 1 - Ranks and Geography"] [--dry-run]`
  NISRA's "Data for Baby Names Dashboard" workbook (nisra.gov.uk — download
  it yourself first). Rows are broken out by Local Government District
  (including a literal `'NULL'` catch-all bucket) — like `ingest-nyc.ts`,
  this script sums counts across every LGD row per (year, sex, name) and
  re-derives rank; NISRA's own per-row Rank column isn't usable directly.
  Populates `name_frequency` (`source='nisra'`, `country='GB-NIR'`).
- `npm run ingest:nrs -- --source=./data/nrs [--dry-run]`
  National Records of Scotland's "Babies' First Names" annual workbooks,
  one file per year (nrscotland.gov.uk — download them yourself first; year
  is auto-detected from the filename, or pass `--year` for a single file
  whose name has no 4-digit year in it). Rank already provided. Populates
  `name_frequency` (`source='nrs'`, `country='GB-SCT'`).
- `npm run ingest:insee -- --source=./data/insee/nat.zip [--encoding=utf-8] [--dry-run]`
  INSEE's French national "Fichier des prénoms" (insee.fr, 1900-present,
  ~725k rows — national file only; the ~3.9M-row departmental breakdown is
  intentionally not ingested, nothing in this schema has a region
  dimension). Rank already provided. Use `--encoding=latin1` if an older
  archival edition parses with garbled accented characters. Populates
  `name_frequency` (`source='insee'`, `country='FR'`).
- `npm run ingest:sweden -- [--male-source=./data/sweden/swename2023-linktable-m.txt --female-source=./data/sweden/swename2023-linktable-f.txt] [--source-url=<swename2023.zip URL>] [--dry-run]`
  Språkbanken Text's swename2023 dataset (spraakbanken.gu.se — download it
  yourself first, or run with no source flags and it will fetch the zip from
  the web). **Architecturally different from every other registry
  here**: a single 2023 snapshot, not a time series — no rank, one
  `name_frequency` row per name at `year=2023`. Also writes `name_variants`
  (`variant_type='spelling'`) linking each non-canonical spelling to its
  canonical form, using the dataset's own similarity-based grouping.
  Pass both local source flags to use local files; if omitted, the script
  auto-discovers a `swename2023*.zip` link from the official resource page.
  `--source-url` overrides the zip URL directly.
  Populates `name_frequency` (`source='swename'`, `country='SE'`).
- `npm run ingest:cso -- [--dry-run]`
  Ireland CSO's "Irish Babies' Names" tables (VSA50 boys / VSA60 girls) via
  the live PxStat JSON-stat 2.0 API (ws.cso.ie, no local file, no auth).
  Rank is self-derived by sorting each year's counts descending (CSO's own
  Rank statistic isn't used). Populates `name_frequency` (`source='cso'`,
  `country='IE'`).
- `npm run ingest:nz -- --source=./data/nz/baby-names.csv [--dry-run]`
  New Zealand DIA's "Baby Name popularity over time" CSV. **data.govt.nz is
  behind bot-detection that blocks non-browser requests** (same class of
  problem as SSA's 403-from-CI issue below) — download the CSV yourself
  from a real browser first. Column layout couldn't be verified end-to-end
  against a live download, so Year/Sex/Name/Count columns are auto-detected
  by header text with `--year-column`/`--sex-column`/`--name-column`/
  `--count-column` overrides if auto-detection doesn't match. DIA's
  separate "Top 1000 Māori Baby Names" dataset is not yet ingested (tracked
  for follow-up — see the script's header comment). Populates
  `name_frequency` (`source='nz'`, `country='NZ'`).
- `npm run ingest:vic -- [--source=./data/vic] [--dry-run]`
  Victoria (Australia) "Popular Baby Names" XLSX exports, one file per year
  since 2008 (bdm.vic.gov.au — downloads them automatically via the CKAN
  API when `--source` is omitted; `--source` overrides with local files).
  Rank already provided (top 100 only). Populates `name_frequency`
  (`source='vic'`, `country='AU-VIC'`).

## Curated datasets

- `npm run ingest:sigpwned -- [--source=./data/sigpwned/common-forenames-by-country.csv] [--dry-run]`
  sigpwned/popular-names-by-country-dataset (CC0, GitHub — forenames only,
  the surnames half is irrelevant here), 2,370 forenames across 106
  countries. Fetches the live CSV by default (small, ~2,480 rows — no
  local download required); `--source` overrides with a local file. Does
  **not** write `name_frequency` (this dataset's per-country "Index" is a
  rank within one country's own top list, not a birth-year count — no year
  dimension fits) or `origin` (its country grouping isn't the same as
  Wikidata's etymological-origin claims). Instead upserts `names` (keyed
  on the dataset's Romanized Name) and links each distinct localized/
  native spelling via `name_variants` (`variant_type='transliteration'`,
  `source='sigpwned'`).
- `npm run ingest:wikidata -- [--page-size=5000] [--delay-ms=1000] [--after-qid=Q12345] [--dry-run]`
  Paginated (keyset, not `OFFSET` — see the file header comment) SPARQL
  queries against Wikidata given-name entities. Populates
  `names.wikidata_qid` and `name_attributes` (`language`, `origin`,
  `etymology`) for both existing and newly-discovered names. If a run gets
  interrupted (Wikidata's query service can still return 502/504 under
  load even with keyset pagination), each logged page prints a
  `--after-qid=...` value to resume from instead of restarting.

## Enrichment

Unlike every ingest-*.ts script above (which ingest everything a bulk
source returns), these two populate data for names that already exist in
`names` from the registries/Wikidata above, one name at a time.

- `npm run ingest:usbabynames -- [--source=./node_modules/usbabynames/sqlite/us-name-details.sqlite] [--limit=1000] [--dry-run]`
  The `usbabynames` npm package's (MIT) bundled `us-name-details.sqlite` —
  115,263 GPT-4o-mini-enriched records, one per (name, sex). `--source`
  defaults to the installed package's own bundled file (no local download
  needed as long as `npm install` has run). Populates `name_attributes`
  (`meaning`, `pronunciation`, `origin`, `source='usbabynames'`, confidence
  0.5 — lower than Wikidata's 1.0, since this content is LLM-generated and
  unverified).
- `npm run enrich:netstudy -- [--limit=500] [--delay-ms=200] [--dry-run]`
  Backfills `meaning`/`origin` from the Netstudy Free Baby Names API
  (babynames.netstudy.in, unauthenticated, no documented SLA) for names
  that still have **no** `meaning` claim from any source at all — not
  every name in the table, since hitting an unofficial single-name-lookup
  API for the full dataset would be slow and largely redundant with what
  usbabynames/Wikidata already cover. Uses `name_enrichment_checks`
  (`source='netstudy'`) so re-runs skip names already resolved
  found/not_found, but retry ones that previously errored. Run this after
  `ingest:usbabynames` so it only backfills genuine gaps. Confidence 0.4.

## Synthesis

- `npm run infer:gender -- [--from-year=1900] [--to-year=2025] [--dry-run]`
  Ports the R `gender` package's `"ssa"` method (proportion of male vs.
  female occurrences → male/female/"either" classification), generalized
  to pool `name_frequency` counts across **every** ingested source/country
  at once rather than SSA alone — see the file's header comment for why
  this is a legitimate superset of the original method. Reuses the same
  `UNISEX_MINORITY_SHARE_THRESHOLD=0.15` convention every registry script
  already applies. Populates `name_attributes`
  (`source='gender-inference'`). Run this **last**, after every registry
  script — the more sources have landed in `name_frequency`, the more
  signal it has to pool from.
- `npm run resolve:attributes -- [--dry-run]`
  Applies a fixed source priority per attribute type — `gender`: every
  direct registry → Wikidata → `gender-inference` (lowest priority, only
  fills gaps no direct source covers); `origin`: Wikidata → usbabynames →
  netstudy; `meaning`/`pronunciation`: usbabynames → netstudy; `etymology`/
  `language`: Wikidata-only (see the file's `SOURCE_PRIORITY` constant for
  the exact list) — flags the winning `name_attributes` row, and mirrors
  it onto the flat `names.gender`/`origin`/`meaning`/`pronunciation_ipa`
  columns the existing API routes read. Run this last of all, after any
  combination of the scripts above (including `infer:gender`).

Every script supports `--dry-run` (parses/queries but writes nothing,
logging what it would have changed) and prints a final summary line.

## Run order

```
ingest:ssa, ingest:ons, ingest:nyc, ingest:ontario, ingest:bc, ingest:chhs,
ingest:alberta, ingest:nisra, ingest:nrs, ingest:insee, ingest:sweden,
ingest:cso, ingest:nz, ingest:vic, ingest:sigpwned, ingest:wikidata
  (any order, independent)
    → ingest:usbabynames → enrich:netstudy
    → infer:gender
    → resolve:attributes (last of all)
```

Every registry/curated-dataset/Wikidata ingestion script can run in any
order or independently. The enrichment scripts depend on names already
existing (run them after the ingestion scripts above), `infer:gender`
depends on `name_frequency` already being populated (run it after the
registries), and `resolve:attributes` should run last of all — it's also
the only one safe to re-run any time after new `name_attributes` rows land
from any source, in any order.

## Country codes

`name_frequency.country` uses bare codes for national sources (`US`, `GB`,
`FR`, `IE`, `NZ`, `AU`) and ISO-3166-2-style codes for subnational ones
(`US-NY`, `US-CA`, `CA-ON`, `CA-BC`, `CA-AB`, `GB-NIR`, `GB-SCT`, `AU-VIC`)
so they can never collide with an existing national source's rows on
`name_frequency`'s `(name_id, source, country, sex, year)` primary key.
Follow this convention for any further registry scripts added later.

## Scheduling

Runs are manually dispatched via the `Ingest Names Dataset` GitHub Actions
workflow (`.github/workflows/ingest-names.yml`), mirroring `migrate.yml`'s
pattern: same `DATABASE_URL_UNPOOLED` secret, `workflow_dispatch`-only for
now. Vercel Cron isn't used here — these are long-running batch jobs well
past Vercel's serverless function time limits.

## Sources that block non-browser downloads

Both SSA and NZ's data.govt.nz have been observed rejecting requests from
this environment/CI (403 and a bot-detection interstitial, respectively) —
in both cases, this isn't reliably fixable client-side (see the SSA section
immediately below for the specifics and workaround shape; the same
"download from a real browser, then pass a local `--source`" approach
applies to `ingest:nz`). If another source starts doing the same, the fix
is the same: download it yourself once, point `--source` at the local file.

## If the SSA auto-download fails in CI

The `ingest:ssa` script downloads `names.zip` from `ssa.gov` automatically
when `--source` is not provided. This has been observed getting a `403` from
`ssa.gov` when run from GitHub-hosted runners, even with a browser-like
`User-Agent` — most likely IP-reputation/WAF blocking of the runner's (Azure)
network rather than anything header-based, so it isn't guaranteed to be fixable
from the client side. If a `workflow_dispatch` run fails at the download step:

1. **Run it locally instead** (unaffected by the block — this is how the
   ingestion pipeline was originally verified end-to-end): download
   `names.zip` yourself from <https://www.ssa.gov/oact/babynames/names.zip>
   (a browser or local machine isn't subject to the same block), then run
   ```
   DATABASE_URL_UNPOOLED=<neon direct connection string> npm run ingest:ssa -- --source=/path/to/names.zip
   ```
2. **Or supply a mirror.** If you'd rather keep running this via CI, host a
   copy of `names.zip` somewhere you control (a private GitHub Release
   asset, Vercel Blob, S3, etc.) and re-dispatch the workflow with the
   `source_url` input pointed at it — the script will fetch from there
   instead of `ssa.gov`. (`source_path` also still works if you'd rather
   upload the file as a workflow artifact and pass a local path.)

## Safety

- Run migrations `1700000400000`–`1700001100000` (see `/migrations`) before
  running any ingestion script.
- Before the *first* run against a database with existing `names` rows, the
  `1700000400000_add-name-source-provenance-columns` migration needs no
  pre-existing duplicates on `(normalized_name, gender)` — see that
  migration file's pre-flight check.
- Target a Neon branch database for the first full run of any script before
  pointing it at production.
- All writes are `ON CONFLICT ... DO UPDATE` upserts — re-running any
  script (including after a partial failure) is safe.
- `ingest:usbabynames` needs `better-sqlite3` (native bindings) and
  `usbabynames` (its bundled `.sqlite` file is ~300MB unpacked) installed —
  both are `devDependencies`, so a plain `npm ci`/`npm install` covers it.
  `better-sqlite3` ships prebuilt binaries for `linux-x64`, matching
  GitHub's `ubuntu-latest` runners, so no native toolchain step should be
  needed in CI — if a run fails at `npm ci` with a native-build error
  instead of at the ingestion step itself, that's the first thing to check.
