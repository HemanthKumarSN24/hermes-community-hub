# Hermes Community Hub

A community skill marketplace for **Hermes Agent** — discover, install, and share skills.

## How it works

1. **Add the hub** to your Hermes with one command
2. Your Hermes **auto-checks daily** for new skills
3. New skills are **evaluated for relevance** to YOUR workflow
4. You get a notification: "New skill available — relevant to your setup" or "Not relevant, here's why"
5. **One-click install** if you want it

## Quick Start

```bash
# Add the hub to your Hermes
curl -sL https://raw.githubusercontent.com/HemanthKumarSN24/hermes-community-hub/main/scripts/hub-setup.sh | bash

# That's it. Your Hermes will now check the hub every 6 hours.
```

## For Skill Authors

```bash
# Publish a skill to the hub
curl -sL https://raw.githubusercontent.com/HemanthKumarSN24/hermes-community-hub/main/scripts/hub-publish.sh | bash -s -- --name "my-skill"
```

See [SKILL_FORMAT.md](./SKILL_FORMAT.md) for the skill specification.

## Skill Categories

- automation
- devops
- data-science
- web
- creative
- productivity
- business
- gaming
- communication
- research
- social-media
- mlops
- custom

## License

MIT