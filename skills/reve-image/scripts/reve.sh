#!/usr/bin/env bash
set -euo pipefail

# Reve API image generation/editing/remixing
# Usage: reve.sh <create|edit|remix> "prompt" [options]
#
# Requires: curl, jq, base64
# Auth: REVE_API_KEY environment variable

REVE_API_KEY="${REVE_API_KEY:?REVE_API_KEY environment variable is required}"
BASE_URL="https://api.reve.com/v1/image"

ACTION="${1:?Usage: reve.sh <create|edit|remix> \"prompt\" [options]}"
shift

PROMPT=""
ASPECT=""
OUTPUT=""
INPUTS=()
UPSCALE=""
TTS=""
FAST=""
EFFECT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --aspect) ASPECT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --input)  INPUTS+=("$2"); shift 2 ;;
    --upscale) UPSCALE="$2"; shift 2 ;;
    --tts)    TTS="$2"; shift 2 ;;
    --fast)   FAST="1"; shift ;;
    --effect) EFFECT="$2"; shift 2 ;;
    --effects) 
      curl -s "https://api.reve.com/v1/image/effect" \
        -H "Authorization: Bearer $REVE_API_KEY" | jq -r '.effects[] | "\(.name) — \(.description) [\(.category)]"'
      exit 0 ;;
    *)
      if [[ -z "$PROMPT" ]]; then
        PROMPT="$1"
      fi
      shift ;;
  esac
done

[[ -z "$PROMPT" ]] && { echo "Error: prompt required" >&2; exit 1; }
[[ -z "$OUTPUT" ]] && OUTPUT="./reve_$(date +%s).png"

# Build postprocessing array
PP="[]"
if [[ -n "$UPSCALE" ]]; then
  PP=$(echo "$PP" | jq --argjson f "$UPSCALE" '. + [{"process":"upscale","upscale_factor":$f}]')
fi
if [[ -n "$EFFECT" ]]; then
  PP=$(echo "$PP" | jq --arg e "$EFFECT" '. + [{"process":"effect","effect_name":$e}]')
fi
# Only pass PP if we have entries
[[ "$PP" == "[]" ]] && PP=""

case "$ACTION" in
  create)
    BODY=$(jq -n \
      --arg prompt "$PROMPT" \
      --arg aspect "${ASPECT:-3:2}" \
      '{prompt: $prompt, aspect_ratio: $aspect}')

    [[ -n "$PP" ]] && BODY=$(echo "$BODY" | jq --argjson pp "$PP" '. + {postprocessing: $pp}')
    [[ -n "$TTS" ]] && BODY=$(echo "$BODY" | jq --argjson tts "$TTS" '. + {test_time_scaling: $tts}')

    RESPONSE=$(curl -s -w "\n%{http_code}" "$BASE_URL/create" \
      -H "Authorization: Bearer $REVE_API_KEY" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -d "$BODY")
    ;;

  edit)
    [[ ${#INPUTS[@]} -eq 0 ]] && { echo "Error: --input required for edit" >&2; exit 1; }

    # Cross-platform base64 encoding (macOS vs Linux)
    if base64 --help 2>&1 | grep -q '\-w'; then
      REF_B64=$(base64 -w0 "${INPUTS[0]}")
    else
      REF_B64=$(base64 -i "${INPUTS[0]}")
    fi

    BODY=$(jq -n \
      --arg instruction "$PROMPT" \
      --arg ref "$REF_B64" \
      '{edit_instruction: $instruction, reference_image: $ref}')

    [[ -n "$ASPECT" ]] && BODY=$(echo "$BODY" | jq --arg a "$ASPECT" '. + {aspect_ratio: $a}')
    [[ -n "$PP" ]] && BODY=$(echo "$BODY" | jq --argjson pp "$PP" '. + {postprocessing: $pp}')
    [[ -n "$TTS" ]] && BODY=$(echo "$BODY" | jq --argjson tts "$TTS" '. + {test_time_scaling: $tts}')
    [[ -n "$FAST" ]] && BODY=$(echo "$BODY" | jq '. + {version: "latest-fast"}')

    RESPONSE=$(curl -s -w "\n%{http_code}" "$BASE_URL/edit" \
      -H "Authorization: Bearer $REVE_API_KEY" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -d "$BODY")
    ;;

  remix)
    [[ ${#INPUTS[@]} -eq 0 ]] && { echo "Error: --input required for remix (1-6 images)" >&2; exit 1; }

    # Build reference_images array
    REF_ARRAY="[]"
    for img in "${INPUTS[@]}"; do
      if base64 --help 2>&1 | grep -q '\-w'; then
        B64=$(base64 -w0 "$img")
      else
        B64=$(base64 -i "$img")
      fi
      REF_ARRAY=$(echo "$REF_ARRAY" | jq --arg b "$B64" '. + [$b]')
    done

    BODY=$(jq -n \
      --arg prompt "$PROMPT" \
      --argjson refs "$REF_ARRAY" \
      '{prompt: $prompt, reference_images: $refs}')

    [[ -n "$ASPECT" ]] && BODY=$(echo "$BODY" | jq --arg a "$ASPECT" '. + {aspect_ratio: $a}')
    [[ -n "$PP" ]] && BODY=$(echo "$BODY" | jq --argjson pp "$PP" '. + {postprocessing: $pp}')
    [[ -n "$TTS" ]] && BODY=$(echo "$BODY" | jq --argjson tts "$TTS" '. + {test_time_scaling: $tts}')
    [[ -n "$FAST" ]] && BODY=$(echo "$BODY" | jq '. + {version: "latest-fast"}')

    RESPONSE=$(curl -s -w "\n%{http_code}" "$BASE_URL/remix" \
      -H "Authorization: Bearer $REVE_API_KEY" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -d "$BODY")
    ;;

  *)
    echo "Unknown action: $ACTION (use create, edit, or remix)" >&2
    exit 1
    ;;
esac

# Parse response
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY_RESP=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "Error (HTTP $HTTP_CODE):" >&2
  echo "$BODY_RESP" | jq . 2>/dev/null || echo "$BODY_RESP" >&2
  exit 1
fi

# Extract and save image
IMAGE_B64=$(echo "$BODY_RESP" | jq -r '.image // empty')
if [[ -n "$IMAGE_B64" ]]; then
  echo "$IMAGE_B64" | base64 -d > "$OUTPUT"
  CREDITS=$(echo "$BODY_RESP" | jq -r '.credits_used // "unknown"')
  REMAINING=$(echo "$BODY_RESP" | jq -r '.credits_remaining // "unknown"')
  VERSION=$(echo "$BODY_RESP" | jq -r '.version // "unknown"')
  echo "Saved: $OUTPUT"
  echo "Model: $VERSION | Credits used: $CREDITS | Remaining: $REMAINING"
else
  echo "No image in response:" >&2
  echo "$BODY_RESP" | jq . 2>/dev/null || echo "$BODY_RESP" >&2
  exit 1
fi
