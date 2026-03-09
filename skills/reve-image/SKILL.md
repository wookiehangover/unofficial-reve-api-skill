---
name: reve-image
description: Generate, edit, and remix images using the Reve API (api.reve.com). Use when the user asks to create images from text prompts, edit existing images with natural language instructions, or remix/blend reference images with prompts. Triggers on image generation, creation, editing, or remix requests mentioning Reve or when Reve is the preferred image tool.
---

# Reve Image

Generate, edit, and remix images via the [Reve API](https://api.reve.com).

## Setup

Set `REVE_API_KEY` as an environment variable. Get an API key from the [Reve console](https://api.reve.com/console).

## Create (text → image)

Generate an image from a text prompt.

```bash
REVE_API_KEY="$REVE_API_KEY" bash SKILL_DIR/scripts/reve.sh create "a sunset over mountains" [--aspect 16:9] [--upscale 2] [--output path.png]
```

**Options:**
- `--aspect`: `16:9`, `9:16`, `3:2` (default), `2:3`, `4:3`, `3:4`, `1:1`
- `--upscale 2|3|4`: Upscale after generation (costs extra credits)
- `--effect NAME`: Apply a postprocessing effect (e.g. `risograph`, `gameboy`, `jazz_album`)
- `--effects`: List all available effects and exit
- `--tts N`: Test-time scaling 1-15 (higher = more effort, costs extra credits)
- `--output path.png`: Output path (defaults to `./reve_TIMESTAMP.png`)

## Edit (image + instruction → image)

Modify an existing image with a text instruction.

```bash
REVE_API_KEY="$REVE_API_KEY" bash SKILL_DIR/scripts/reve.sh edit "make the sky purple" --input photo.png [--output edited.png]
```

- `--input` is required (path to source image)
- `--fast` uses the fast edit model (cheaper/faster)
- `--aspect` to change aspect ratio

## Remix (images + prompt → image)

Blend reference images with a text prompt.

```bash
REVE_API_KEY="$REVE_API_KEY" bash SKILL_DIR/scripts/reve.sh remix "combine into a collage" --input img1.png --input img2.png [--output remix.png]
```

- 1-6 reference images via multiple `--input` flags
- Prompt can use `<img0>`, `<img1>` to reference specific images
- `--fast` uses the fast remix model

## Notes

- Max prompt length: 2560 characters
- Prompts are automatically enhanced by the model
- Postprocessing: upscale, remove_background, fit_image, effects
- Effects categories: textures (risograph, gameboy, charcoal, engraving, stippling, dither, grain...), light (bokeh, tilt_shift, lens_flare, halation, sun_rays...), color (jazz_album, duotone, neon_night, drama_cine, grit_mono...)
- Credits used and remaining are shown after each request
- Requires `curl`, `jq`, and `base64` (standard on most systems)
