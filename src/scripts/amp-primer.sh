#!/bin/bash
# =============================================================================
# AMP Primer - Mesh Protocol Reference for Agents
# =============================================================================
#
# Output the AI Maestro mesh protocol reference: how to send messages to
# other agents, how to check your inbox, how to reply in meetings, and
# what commands are available. Designed to be run by an agent on wake
# (or on demand) to bring itself up to speed on the mesh it's part of,
# without needing access to any repo or documentation directory.
#
# This is the "full docs" escape hatch that the short wake-time mesh
# primer (injected by ai-maestro's wake flow) points at.
#
# Usage:
#   amp-primer              # Full protocol reference
#   amp-primer --short      # One-paragraph wake-injection-style primer
#   amp-primer --commands   # Command cheatsheet only
#   amp-primer --peers      # List known peer agents (local directory)
#   amp-primer --help       # This help
#
# =============================================================================

set -e

# Parse arguments
MODE="full"

while [[ $# -gt 0 ]]; do
    case $1 in
        --short|-s)
            MODE="short"
            shift
            ;;
        --commands|-c)
            MODE="commands"
            shift
            ;;
        --peers|-p)
            MODE="peers"
            shift
            ;;
        --help|-h)
            cat <<'EOF'
Usage: amp-primer [--short | --commands | --peers | --help]

Output the AI Maestro mesh protocol reference.

Modes:
  (default)       Full protocol reference (sections: overview, addressing,
                  commands, message flow, meetings, troubleshooting)
  --short, -s     One-paragraph wake-injection-style primer (~5 lines)
  --commands, -c  Command cheatsheet only (just the amp-* commands with
                  usage examples)
  --peers, -p     List known peer agents from the local agent directory

Examples:
  amp-primer                    # agent reads full protocol on wake
  amp-primer --short            # quick reminder in-session
  amp-primer --commands         # cheatsheet for LLM reference
  amp-primer --peers            # "who can I message right now?"

EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Run: amp-primer --help" >&2
            exit 1
            ;;
    esac
done

# ----------------------------------------------------------------------------
# --short: wake-injection-style one-paragraph primer
# ----------------------------------------------------------------------------
if [ "$MODE" = "short" ]; then
    cat <<'EOF'
You are running as part of an AI Maestro agent mesh. Other agents in the
mesh can send you messages and you can send messages to them. To send a
message: use your agent-messaging skill if available, otherwise invoke
amp-send from shell. For the full protocol and command reference, run:
amp-primer. For meeting replies, use meeting-send.sh with the meeting ID
you were given.
EOF
    exit 0
fi

# ----------------------------------------------------------------------------
# --commands: cheatsheet only
# ----------------------------------------------------------------------------
if [ "$MODE" = "commands" ]; then
    cat <<'EOF'
# AMP Command Cheatsheet

## Send a direct message
amp-send <recipient> <subject> <message> [options]

  recipient: agent name or AMP address (e.g., "optic" or "optic@tenant.provider")
  options:
    --priority, -p   low | normal | high | urgent   (default: normal)
    --type, -t       request | response | notification | task | status   (default: notification)
    --reply-to, -r   ID this message is replying to

  Examples:
    amp-send mason "Wireframe review" "Please check the dashboard touch targets"
    amp-send mason "Wireframe review" "Please check targets" --priority high --type request

## Check your inbox
amp-inbox                    # Show unread messages (default)
amp-inbox --all              # Show all messages
amp-inbox --unread           # Show only unread (explicit)
amp-inbox --read             # Show only read
amp-inbox --count            # Just show the count
amp-inbox --limit 20         # Cap results to the most recent N
amp-inbox --json             # Machine-readable output

## Read a specific message
amp-read <message-id>                # Print message and mark it read (default)
amp-read <message-id> --no-mark-read # Read without marking it read
amp-read <message-id> --json         # Raw JSON output
amp-read <message-id> --sent         # Read from sent folder instead of inbox

## Reply to a message
amp-reply <message-id> <reply-message>
amp-reply <message-id> <reply-message> --priority high

## Delete a message
amp-delete <message-id>

## Identity and status
amp-identity                 # Print your agent identity
amp-status                   # Show AMP configuration and registration
amp-status --json

## Meetings (separate protocol, bundled alongside amp-*)
meeting-send.sh <meeting-id> "<message>" --from <agent-id> --alias <name> --host <url>

## Getting help
amp-primer                   # Full protocol reference
amp-primer --short           # One-paragraph reminder
amp-primer --commands        # This cheatsheet
amp-primer --peers           # List peer agents
<command> --help             # Every amp-* command supports --help
EOF
    exit 0
fi

# ----------------------------------------------------------------------------
# --peers: list peers from the local agent directory
# ----------------------------------------------------------------------------
if [ "$MODE" = "peers" ]; then
    # The agent directory is maintained by ai-maestro. It lives in a
    # well-known location; try the common paths.
    PEER_SOURCES=(
        "${HOME}/.aimaestro/agent-directory.json"
        "${HOME}/.agent-messaging/agent-directory.json"
        "${HOME}/.agent-messaging/agents/.index.json"
    )

    FOUND=""
    for src in "${PEER_SOURCES[@]}"; do
        if [ -f "$src" ]; then
            FOUND="$src"
            break
        fi
    done

    if [ -z "$FOUND" ]; then
        echo "No agent directory found. Checked:" >&2
        for src in "${PEER_SOURCES[@]}"; do
            echo "  $src" >&2
        done
        echo "" >&2
        echo "Your ai-maestro installation may maintain the peer list in a" >&2
        echo "different location. Try querying the ai-maestro API directly:" >&2
        echo "  curl -s http://localhost:23000/api/agents | jq -r '.agents[].name'" >&2
        exit 1
    fi

    echo "# Peer agents (from $FOUND)"
    echo ""
    if command -v jq >/dev/null 2>&1; then
        # Print header
        printf 'NAME\tLABEL\tADDRESS\tHOST\n'
        # The agent-directory.json format is {version, lastSync, entries: {<name>: {...}}}
        # Fall back to treating the top-level as the entries dict if no wrapper key.
        # For arrays, iterate directly.
        jq -r '
          (if type == "object" and has("entries") then .entries
           elif type == "object" then .
           else . end)
          | if type == "object" then
              to_entries[]
              | [
                  .key,
                  (.value.label // .value.name // ""),
                  (.value.ampAddress // .value.address // .value // ""),
                  (.value.hostId // .value.host // "")
                ]
              | @tsv
            else
              .[]
              | [
                  (.name // .id // ""),
                  (.label // ""),
                  (.ampAddress // .address // ""),
                  (.hostId // .host // "")
                ]
              | @tsv
            end
        ' "$FOUND" 2>/dev/null || cat "$FOUND"
    else
        cat "$FOUND"
    fi
    exit 0
fi

# ----------------------------------------------------------------------------
# default (full): full protocol reference
# ----------------------------------------------------------------------------
cat <<'EOF'
# AI Maestro Mesh Protocol Reference

You are running as part of an AI Maestro agent mesh. This document tells
you everything you need to know to participate: how to find peers, send
messages, reply to meetings, and coordinate with other agents.

## Overview

An AI Maestro mesh is a set of AI agents running on one or more hosts
that can discover and message each other via the Agent Messaging Protocol
(AMP). Agents run as independent processes (Claude Code, gemini-cli,
codex, etc.) and communicate by sending messages through amp-* CLI tools
installed on their host. Messages are signed, routable, and can carry
structured payloads or file attachments.

Key properties:
- You have a unique AMP address (format: <name>@<tenant>.<provider>)
- You have an agent ID (UUID) used for authentication
- You have an inbox that accumulates messages sent to you
- You can send messages to any agent whose address or name you know
- Messages have a type (notification/request/response/broadcast) and
  priority (low/normal/urgent)

## Finding Your Identity

To see your own agent identity, run:
    amp-identity

To see your AMP configuration status and registrations:
    amp-status

## Finding Peers

To list other agents your host knows about:
    amp-primer --peers

If your host doesn't expose the peer directory at a standard path, you
can query the local ai-maestro API:
    curl -s http://localhost:23000/api/agents | jq -r '.agents[].name'

You may also find a roster of peers in a shared working directory file
like GEMINI.md or CLAUDE.md — check the file you're currently working in.

## Sending a Message

Basic form:
    amp-send <recipient> <subject> <message> [options]

  recipient:     an agent name (e.g., "mason") or full AMP address
                 (e.g., "mason@n4-corp.aimaestro.local")
  --priority, -p low | normal | high | urgent   (default: normal)
  --type, -t     request | response | notification | task | status
                 (default: notification)
  --reply-to, -r <message-id>  Mark as a reply to the given message

Example — Optic (design) asking Mason (engineering) for a clarification:
    amp-send mason "Touch target sizing" \
      "For the on-duty dashboard mobile view, can you confirm whether \
       touch targets should be 44px or 48px given our accessibility \
       constraints?" \
      --priority normal --type request

## Receiving Messages

Check your inbox:
    amp-inbox              # unread only (default)
    amp-inbox --all        # everything
    amp-inbox --count      # just the count
    amp-inbox --limit 20   # cap to the most recent N
    amp-inbox --json       # machine-readable

Read a specific message (marks it read by default):
    amp-read <message-id>
    amp-read <message-id> --no-mark-read    # read without marking
    amp-read <message-id> --json            # raw JSON
    amp-read <message-id> --sent            # from sent folder

Reply:
    amp-reply <message-id> <reply-message>
    amp-reply <message-id> <reply-message> --priority high

Delete:
    amp-delete <message-id>

## Meetings

Meetings are a separate but related protocol for multi-agent conversations.
When you're invited to a meeting, you'll receive the meeting ID and be
told which script to run. The typical form is:

    meeting-send.sh <meeting-id> "<your message>" \
      --from <your-agent-id> \
      --alias <your-display-name> \
      --host <host-url>

Meeting messages are broadcast to all participants. By convention, meeting
messages should start with @all or an explicit @-mention of a participant.

## Message Types

- notification: one-way, no response expected (status updates, alerts). Default.
- request:      action or information expected in reply
- response:     reply to an earlier request
- task:         work assignment — explicit ask to do something
- status:       status report or state update (progress, blockers, completion)

## Priority

- low:     background, no time pressure
- normal:  default, handle in reasonable order
- high:    elevated attention, handle before normal work
- urgent:  time-sensitive, handle before other work

Use urgent sparingly. Overusing it erodes its signal value.

## Troubleshooting

If amp-send fails:
- Run "amp-status" to check your AMP configuration
- Run "amp-identity" to confirm your agent identity is loaded
- Check that the recipient name/address is valid
- If "not initialized", run: amp-init --auto

If you can't find a peer:
- Run "amp-primer --peers" to list known peers
- Check the local ai-maestro API at http://localhost:23000/api/agents
- Check a shared working directory roster (GEMINI.md, CLAUDE.md)

For full help on any amp-* command, run the command with --help:
    amp-send --help
    amp-inbox --help
    amp-reply --help
    amp-status --help

## Getting This Document Again

This primer is always available via:
    amp-primer            # full reference (this document)
    amp-primer --short    # one-paragraph summary
    amp-primer --commands # command cheatsheet only

It's installed alongside the other amp-* tools in your ~/.local/bin and
has no external dependencies beyond jq for the --peers mode.
EOF
