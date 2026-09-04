# shared/ — central AI content store

Single source of truth for AI-assistant content used across the stack
(pi, OpenWebUI, and anything else you point at it). Everything here is
plain text and committed to git — no container-local edits.

```
shared/
├── skills/     # Agent skills (agent-skills format: one folder per skill, each with a SKILL.md)
│   └── <skill-name>/
│       └── SKILL.md        # YAML frontmatter (name, description) + markdown body
└── prompts/    # OpenWebUI prompt templates (one .txt or .json per prompt)
    └── <prompt-name>.txt   # may use {{variable}} placeholders
```

## How consumers use it

### pi (this coding agent)
`docker-compose.yml` mounts `./shared/skills` read-only at `/skills` inside
the pi container. The pi entrypoint symlinks each skill folder into
`/root/.agents/skills/` at startup. Drop a new `<name>/SKILL.md` folder in
here and restart pi (`docker compose -p <proj> restart pi`) — no image
rebuild needed.

### OpenWebUI
OpenWebUI has no native skill format, so run the sync script to push content
into its Prompt Manager:

```sh
export OPENWEBUI_API_KEY=...   # user settings -> API keys (manager/admin role)
./scripts/sync-openwebui.sh                # sync shared/prompts/*.txt
./scripts/sync-openwebui.sh --skills       # also upload each skill (frontmatter stripped)
```

Skills uploaded this way show up in OpenWebUI as prompt templates you can
attach to a chat, so the same "dutch energy advisor" guidance works in both
tools.

### Adding a new skill
1. `mkdir shared/skills/my-skill`
2. Write `shared/skills/my-skill/SKILL.md` with `name:` and `description:`
   frontmatter (the description is what makes the agent trigger it).
3. `docker compose restart pi` (and re-run the sync script if you want it
   in OpenWebUI too).
