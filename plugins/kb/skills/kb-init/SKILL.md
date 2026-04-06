---
name: kb-init
description: "Use when setting up a new knowledge base, bootstrapping an Obsidian vault, or when user says 'init kb', 'new knowledge base', 'create kb', or 'setup vault'. Triggers on any request to initialize or scaffold a knowledge base project."
---

## Overview

One-time (or re-runnable) setup that bootstraps a knowledge base project as an Obsidian vault.

## Prerequisites

Obsidian must be installed.

## Plugin Setup

After confirming the vault path, run the bundled setup script via Bash tool:

```bash
# Interactive — asks user about each optional plugin
bash plugins/kb/setup.sh /path/to/vault

# Install everything
bash plugins/kb/setup.sh /path/to/vault --all

# Install specific plugins only
bash plugins/kb/setup.sh /path/to/vault --only dataview,obsidian-git
```

**Required plugins** (always installed):
- **Dataview** — query wiki articles like a database
- **Obsidian Git** — auto-backup vault to git

**Optional plugins** (user chooses interactively):
- **Kanban** — track wiki tasks on boards
- **Outliner** — better list editing for article drafts
- **Tag Wrangler** — rename and merge tags across the wiki
- **Local Images Plus** — download and store remote images locally

**Browser extension** (printed as manual step):
- **Web Clipper** — clip web articles into `raw/`

The script is idempotent — safe to re-run. If Obsidian is open, tell the user to restart it.

## Flow

### 1. Vault Setup

Ask: create a new vault or use an existing directory? If new, scaffold `.obsidian/`. If existing, verify it exists.

### 2. Source Gathering Strategy

Ask how the user wants to get raw data in:

- **Self-serve** -- User drops files in `raw/`. Per-type guidance:
  - Web articles: Obsidian Web Clipper extension -> `raw/articles/`
  - Academic papers (PDF): Download to `raw/papers/`
  - GitHub repos: Clone/snapshot to `raw/repos/`
  - Local markdown/text: Copy to `raw/notes/`
  - Images/diagrams: Place in `raw/images/`
  - YouTube transcripts: Transcript tool -> `raw/transcripts/`
  - Datasets (CSV, JSON): Place in `raw/datasets/`
- **Assisted** -- Claude fetches via WebFetch, Bash (clone repos, download PDFs, pull transcripts)
- **Mixed** -- Some of each

### 3. Output Format Preferences

Ask which formats the user wants: markdown (always on), Marp slides, matplotlib charts, HTML, CSV, Excalidraw, other. Use an extensible pattern so new formats can be added later.

### 4. Maintenance Cadence

Inform about options:
- Daily/hourly: `/loop` (e.g., `/loop 1d kb lint`)
- Weekly/monthly: `/schedule`
- Manual: just ask anytime

### 5. Generate `kb.yaml`

Write `kb.yaml` at project root with paths, `output_formats`, and obsidian config.

### 6. Scaffold Directories

Create: `raw/articles/`, `raw/papers/`, `raw/repos/`, `raw/notes/`, `raw/images/`, `raw/transcripts/`, `raw/datasets/`, `wiki/`, `output/`. Plus `.obsidian/` if new vault.

### 7. Write Project Files

- `CLAUDE.md` -- project instructions for future sessions
- `README.md` -- repo docs with prerequisites, setup, workflows, directory structure, and attribution for research skills

### 8. Next Steps Guidance

Tell user what to do next: add sources, compile, and list available workflows (`compile`, `query`, `lint`, `evolve`).

Also share these Obsidian tips from the gist:

**Image downloads:** In Obsidian Settings → Files and links, set "Attachment folder path" to `raw/assets/`. Then in Settings → Hotkeys, search for "Download" and bind "Download attachments for current file" to a hotkey (e.g. Ctrl+Shift+D). After clipping an article, hit the hotkey and all images download locally — the LLM can then view them directly rather than relying on URLs that may break.

**Graph view:** Obsidian's graph view is the best way to see the shape of the wiki — which pages are hubs, which are orphans, what clusters are forming.

**qmd (for large wikis):** Once the wiki grows beyond ~100 articles, [qmd](https://github.com/tobi/qmd) is a local BM25/vector search engine for markdown with LLM re-ranking and an MCP server. The `kb` skill will use it automatically if installed.

### 9. Schema Co-evolution Reminder

The `CLAUDE.md` written at init is a starting point, not a final document. Tell the user:

**"As your wiki grows, evolve `CLAUDE.md` together with me. When you notice a pattern — a new article type that keeps appearing, a convention that's working well, a workflow you want to standardize — tell me and I'll update `CLAUDE.md` to capture it. The schema should reflect how your specific wiki actually works, not just the defaults."**

Common things that evolve over time:
- New article types specific to your domain
- Preferred section structure for your most common article types
- Source types you've added that need their own ingestion notes
- Naming conventions that have emerged organically
- Queries you run often that could be standardized as workflows

## Common Mistakes

- Do not overwrite an existing `kb.yaml` without confirming with the user first.
- Do not skip the source-gathering strategy question -- it determines the entire workflow.
- Do not create `.obsidian/` inside a directory that is already an Obsidian vault.
- Do not assume output formats -- always ask the user.
