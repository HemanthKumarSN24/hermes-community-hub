#!/bin/bash
# ==============================
# Hermes Community Hub - Notify
# ==============================
# Evaluates new skills for relevance to the user's setup
# and shows a notification.
#
# Called by: hub-sync.sh when new skills are found
# Relevance logic: compares skill tags/category against user's installed skills

set -e

HUB_DIR="$HOME/.hermes/hub"
SCRIPTS_DIR="$HUB_DIR/scripts"
INSTALLED_DIR="$HUB_DIR/installed"
HERMES_SKILLS_DIR="$HOME/.hermes/skills"
REPO_DIR="$HUB_DIR/repo"
LAST_SEEN="$HUB_DIR/last-seen.json"

NEW_SKILLS_JSON="${1:-}"

if [ -z "$NEW_SKILLS_JSON" ] || [ "$NEW_SKILLS_JSON" = "" ]; then
    # Read from stdin if not provided as arg
    NEW_SKILLS_JSON=$(cat)
fi

if [ -z "$NEW_SKILLS_JSON" ]; then
    exit 0
fi

# Gather user's existing skills for relevance matching
USER_SKILLS=""
if [ -d "$HERMES_SKILLS_DIR" ]; then
    USER_SKILLS=$(ls "$HERMES_SKILLS_DIR" 2>/dev/null || echo "")
fi

if [ -d "$INSTALLED_DIR" ]; then
    INSTALLED_HUB_SKILLS=$(ls "$INSTALLED_DIR" 2>/dev/null || echo "")
fi

# Evaluate each new skill for relevance
python3 -c "
import json, sys, os

new_skills = json.loads('''$NEW_SKILLS_JSON''')
user_skills_str = '''$USER_SKILLS'''
installed_str = '''$INSTALLED_HUB_SKILLS'''
user_skills = set(user_skills_str.split()) if user_skills_str else set()

# User's domain keywords — extracted from what they have installed
user_tags = set()
for s in user_skills:
    user_tags.add(s.lower().replace('-', ' ').replace('_', ' '))

# Common business domains to detect relevance
domains = {
    'lead': 'lead generation',
    'scrap': 'data scraping', 
    'market': 'marketing',
    'email': 'email marketing',
    'social': 'social media',
    'whatsapp': 'messaging',
    'automation': 'workflow automation',
    'n8n': 'workflow automation',
    'crm': 'customer management',
    'analytics': 'data analysis',
    'business': 'business operations',
    'content': 'content creation',
    'seo': 'SEO / marketing',
    'web': 'web development',
    'devops': 'devops / deployment',
    'data': 'data science',
}

for skill in new_skills:
    name = skill.get('name', 'unknown')
    desc = skill.get('description', '')
    ver = skill.get('version', '?')
    tags = skill.get('tags', [])
    category = skill.get('category', '')
    author = skill.get('author', {})
    author_name = author.get('name', 'Unknown') if isinstance(author, dict) else author
    
    # Check relevance
    name_lower = name.lower() + ' ' + desc.lower()
    tag_lower = ' '.join(tags).lower() + ' ' + category.lower()
    
    relevant_reasons = []
    for keyword, area in domains.items():
        if keyword in name_lower or keyword in tag_lower:
            relevant_reasons.append(area)
    
    # Check against user's existing skills
    for us in user_skills:
        us_lower = us.lower().replace('-', ' ').replace('_', ' ')
        if any(word in us_lower for word in name_lower.split()):
            relevant_reasons.append(f'related to your installed skill \"{us}\"')
    
    is_relevant = len(relevant_reasons) > 0
    relevance_label = '✅ RELEVANT' if is_relevant else 'ℹ️ Not directly relevant'
    
    # Print notification block
    print()
    print('╔════════════════════════════════════════════════════════╗')
    print(f'║  🆕 {name:<48} ║')
    print(f'║     v{ver:<46} ║')
    print(f'║     by {author_name:<42} ║')
    print('╠════════════════════════════════════════════════════════╣')
    print(f'║  {relevance_label:<52} ║')
    if is_relevant:
        for r in relevant_reasons[:3]:
            print(f'║     → {r:<48} ║')
    print('╠════════════════════════════════════════════════════════╣')
    print(f'║  {desc:<52} ║')
    print('║                                                        ║')
    print('║  Install: bash ~/.hermes/hub/scripts/hub-install.sh \\')
    print(f'║           {name:<48} ║')
    print('╚════════════════════════════════════════════════════════╝')
    print()
" 2>/dev/null || echo "[hub-notify] New skills available — run 'hub-install.sh list' to see them"