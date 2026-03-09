# Unofficial Reve API Skill

An [agent skill](https://skills.sh) for generating, editing, and remixing images using the [Reve API](https://api.reve.com).

## Install

```bash
npx skills add wookiehangover/unofficial-reve-api-skill
```

## What it does

- **Create** — generate images from text prompts
- **Edit** — modify existing images with natural language instructions
- **Remix** — blend reference images with text prompts

## Setup

You need a Reve API key. Get one from the [Reve console](https://api.reve.com/console).

Set it as an environment variable:

```bash
export REVE_API_KEY="your-key-here"
```

## Requirements

- `curl`
- `jq`
- `base64`

## Links

- [Reve API docs](https://api.reve.com/console/docs)
- [skills.sh](https://skills.sh)

## Disclaimer

This is an unofficial community skill and is not affiliated with or endorsed by Reve.
