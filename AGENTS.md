# Agent instructions

Edit project rules in `AGENTS.md`, never an assistant-specific copy — those are symlinks, so edits apply everywhere at once.

In a git worktree with no `.env`, run `bash scripts/worktree-init.sh` before anything else.

## Design principles

- Do not preserve backward compatibility. Remove obsolete paths instead of adding compatibility layers, fallbacks, or migrations.
- Choose the simplest implementation that fully meets the current requirements. Avoid speculative abstractions, configuration, and indirection.
- Grow the system in layers. Start from the smallest version that works end to end, and add each new capability on top of a product that already works. Never trade a working product for unfinished complexity.
- Keep components modular and concerns clearly separated.
- Prefer established, well-maintained libraries when they reduce complexity or improve reliability. Do not reimplement common functionality without a clear reason.
- Lean on the dependencies already in the project before writing your own implementation or adding packages. Do not assume a library lacks a capability without checking its documentation and types.
- Make architectural decisions for the long term. Do not accept a stopgap that only works for now and is meant to be replaced later.
- Prefer infrastructure as code under `infra/`. Creating cloud resources by hand is fine while prototyping, but nothing ships that way: once the design settles, capture it in code and remove the manual setup.

## Comments

- Comment only what the code cannot say. Try a better name first.
- Keep comments local to the file: no callers, other modules, or assumptions about how it is used.

## Agent skills

A skill's instructions are mandatory. When a skill names another skill, invoke it with the Skill tool instead of working from memory. When it names a file, read that file this session and follow it. Before finishing, check that each of those directives ran as a tool call.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root, or multi-context: a `GLOSSARY-MAP.md` at the root pointing at one `GLOSSARY.md` per context, each with its own `docs/adr/`. See `docs/agents/domain.md`.
