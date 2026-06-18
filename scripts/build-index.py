#!/usr/bin/env python3
"""Build index.json from skills/*/SKILL.md files"""
import json, os, glob, re

def parse_frontmatter(frontmatter: str) -> dict:
    """Parse YAML-like frontmatter into a dict."""
    meta = {}
    lines = frontmatter.split('\n')
    stack = []  # list of (key, dict_level)
    current_dict = meta

    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        if ':' not in stripped:
            continue

        indent = len(line) - len(line.lstrip())
        key, _, raw_val = stripped.partition(':')
        key = key.strip()
        val = raw_val.strip()

        # Determine dict level based on indent
        level = indent // 2

        # Pop stack back to correct level
        while stack and stack[-1][1] >= level:
            stack.pop()

        if not val or val == '':
            # This key is a parent (like "author:" or "metadata:")
            new_dict = {}
            parent = stack[-1][0] if stack else None
            if parent:
                # We're inside another dict
                current_dict = meta
                for p_key, _ in stack:
                    current_dict = current_dict.get(p_key, {})
                current_dict[key] = new_dict
            else:
                meta[key] = new_dict
            current_dict = new_dict
            stack.append((key, level))
            continue

        # This key has a value
        # Process value
        val = raw_val.strip()

        # Handle quoted strings
        if val.startswith('"') and val.endswith('"'):
            val = val[1:-1]
        elif val.startswith("'") and val.endswith("'"):
            val = val[1:-1]

        # Handle arrays
        if val.startswith('[') and val.endswith(']'):
            inner = val[1:-1]
            try:
                val = json.loads(f'[{inner}]')
            except:
                val = [v.strip().strip("'\"").strip('"') for v in inner.split(',') if v.strip()]

        # Handle booleans
        if isinstance(val, str) and val.lower() in ('true', 'false'):
            val = val.lower() == 'true'

        # Handle numbers
        if isinstance(val, str) and val.replace('.', '').isdigit():
            try:
                val = int(val)
            except ValueError:
                try:
                    val = float(val)
                except ValueError:
                    pass

        # Find where to put this value
        if not stack:
            meta[key] = val
        else:
            # Navigate to current parent dict
            current_dict = meta
            for p_key, _ in stack:
                if isinstance(current_dict.get(p_key), dict):
                    current_dict = current_dict[p_key]
                else:
                    break
            current_dict[key] = val

    return meta


skills_dir = 'skills'
skills = []
if os.path.exists(skills_dir):
    for skill_path in sorted(glob.glob(f'{skills_dir}/**/SKILL.md', recursive=True)):
        skill_name = os.path.basename(os.path.dirname(skill_path))

        with open(skill_path) as f:
            content = f.read()

        parts = content.split('---', 2)
        if len(parts) >= 3:
            frontmatter = parts[1]
        else:
            continue

        meta = parse_frontmatter(frontmatter)
        # Override name with directory name (canonical)
        meta['name'] = skill_name
        skills.append(meta)

with open('index.json', 'w') as f:
    json.dump({'skills': skills, 'count': len(skills)}, f, indent=2)
print(f'Built index.json with {len(skills)} skills')