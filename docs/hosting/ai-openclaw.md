# OpenClaw Defaults for Sure

This guide describes the default OpenClaw configuration files that ship in this repository and how they are wired into `compose.example.ai.yml`.

## Directory Layout

All default OpenClaw files live under:

- `docs/hosting/openclaw/`

Contents:

- `BOOTSTRAP.md` — startup instructions and operational guardrails for Sure-specific assistant behavior.
- `SOUL.md` — identity, values, and response behavior defaults for a finance-focused assistant persona.
- `skills/sure-mcp/SKILL.md` — a first skill pack describing when and how to use Sure MCP tools for account/transaction analysis.

## Docker Compose Wiring

In `compose.example.ai.yml`, the `openclaw-gateway` service mounts this directory read-only at `/opt/openclaw-defaults` and seeds it into the writable OpenClaw home volume (`/home/node/.openclaw`) on startup.

The startup command:

1. ensures `/home/node/.openclaw` exists and has the right ownership,
2. copies defaults with `cp -rn` (non-destructive; does not overwrite existing files),
3. configures Control UI allowed origins,
4. starts the OpenClaw gateway.

This allows a clean first-run experience while preserving user customizations after initial boot.

## Notes

- The default `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` is permissive (`["*"]`) for local onboarding. Tighten this value for production deployments.
- You can customize defaults by editing files under `docs/hosting/openclaw/` before starting Compose.
