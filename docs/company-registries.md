# Registries by jurisdiction

Status verified 2026-07-31. Registries beat aggregators; aggregators beat
commentary. Cite the registry, not the summary of it.

## Hong Kong

The primary record. Most HK company questions are answered here.

- **ICRIS Cyber Search Centre** — https://www.icris.cr.gov.hk/csci/
  Company particulars, directors, status, charges. The authoritative source.
  **Paid per search** (small fee, requires an account). Document search costs extra.
- **Companies Registry** — https://www.cr.gov.hk/en/home/index.htm
  Registry front door; annual return requirements, dissolution notices.
- **HKEXnews** — https://www.hkexnews.hk/
  Free. Filings for **listed** companies only: announcements, annual reports,
  shareholding disclosures. If the target is listed, start here rather than ICRIS.
- **SFC Public Register** — https://apps.sfc.hk/publicregWeb/
  Free. Licensed corporations and individuals. Anyone claiming to do regulated
  financial activity in HK should appear here. Absence is a finding.
- **Judiciary judgment search** — https://legalref.judiciary.hk/lrs/common/ju/judgment.jsp
  Free. Litigation history. Winding-up petitions surface here.

**Reading a HK result.** A company being registered proves only registration.
Shell structures are legal and common. Weight goes on: directors also appearing
on many unrelated entities, a registered office shared with hundreds of
companies, dormant annual returns, recent change of name or directors, and
absence from the SFC register while advertising regulated services.

## Mainland China

- **gsxt.gov.cn** — National Enterprise Credit Information Publicity System.
  Returned **HTTP 521 from this network**. If you need it, say it was
  unreachable rather than substituting a commercial aggregator silently.
- Commercial mirrors (Qichacha, Tianyancha) hold the same data behind accounts.
  Name the mirror in the report if used.

## United Kingdom

- **Companies House** — https://find-and-update.company-information.service.gov.uk/
  Free web search, no key. Full filing history, officers, charges.
- The **API** returned 401; the key is free to request and worth having for
  bulk work.

## United States

- **SEC EDGAR** — https://www.sec.gov/edgar and full-text search at
  https://efts.sec.gov/LATEST/search-index — free, no key, confirmed live.
  Send a descriptive `User-Agent` with a contact address or SEC will block you.
- State Secretary of State registries for anything not SEC-registered.

## Global

- **GLEIF LEI** — https://api.gleif.org/api/v1/lei-records — free, no key,
  confirmed live. Legal entity identifiers, parent and child relationships.
  The best free way to map corporate structure across borders.
- **OpenCorporates** — 401 without a key. Listed as free in the old version of
  this skill; it is not.
- **Wayback Machine** — https://archive.org/wayback/available — free. What the
  company's own site claimed, and when it changed.
