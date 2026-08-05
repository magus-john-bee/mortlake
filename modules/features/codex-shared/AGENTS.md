# Global Codex instructions

## Web research

When researching a library, framework, or tool, check whether `https://<domain>/llms.txt` exists — many projects serve a machine-readable documentation index at this URL. Use the web_fetch_exa tool (or web_search/web_extract) to fetch it and treat it as a table of contents to locate the relevant docs before doing a broader search. This is a fast-path optimization, not a requirement — if it 404s, just search normally.