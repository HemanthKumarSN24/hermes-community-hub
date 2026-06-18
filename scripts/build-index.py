#!/usr/bin/env python3
"""Build index.json from skills/*/SKILL.md files"""
import json, os, glob

skills_dir = 'skills'
skills = []
if os.path.exists(skills_dir):
    for skill_path in sorted(glob.glob(f'{skills_dir}/*/SKILL.md')):
        skill_name = os.path.basename(os.path.dirname(skill_path))
        with open(skill_path) as f:
            content = f.read()

        parts = content.split('---', 2)
        if len(parts) >= 3:
            frontmatter = parts[1]
        else:
            continue

        meta = {'name': skill_name}
        for line in frontmatter.split('\n'):
            line = line.strip()
            if ':' in line and not line.startswith('#'):
                key, _, val = line.partition(':')
                key = key.strip()
                val = val.strip().strip("'").strip('"')
                if val.startswith('[') and val.endswith(']'):
                    try:
                        val = json.loads(val)
                    except Exception:
                        val = [v.strip().strip("'").strip('"') for v in val.strip('[]').split(',') if v.strip()]
                elif val in ('true', 'false'):
                    val = val == 'true'
                meta[key] = val

        skills.append(meta)

with open('index.json', 'w') as f:
    json.dump({'skills': skills, 'count': len(skills)}, f, indent=2)
print(f'Built index.json with {len(skills)} skills')