# AI assistants

Every AI coding assistant gets the same rules and skills in this project.

- **Rules:** [`AGENTS.md`](../../AGENTS.md) at the repo root, in the [agents.md](https://agents.md) format that most assistants read. `CLAUDE.md` and `GEMINI.md` are symlinks to it for Claude Code and Gemini, so only ever edit `AGENTS.md`.
- **Skills:** installed from [il-skills](https://github.com/ivado-labs/il-skills) with [`npx skills`](https://github.com/vercel-labs/skills), as its [Get started](https://github.com/ivado-labs/il-skills#get-started) shows. They go into the gitignored `.agents/skills/`, and `.claude/skills` for Claude Code.

On Windows, enable symlinks before cloning, or the links come out as plain text files: turn on Developer Mode, then run `git config --global core.symlinks true`.
