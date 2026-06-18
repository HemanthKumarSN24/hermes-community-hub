#!/usr/bin/env python3
import glob, sys

skills_dir = 'skills'
count = 0
errors = 0
broken = []
for skill_path in sorted(glob.glob(f'{skills_dir}/**/SKILL.md', recursive=True)):
    skill_name = skill_path.split('/')[-2]
    with open(skill_path) as f:
        content = f.read()
    parts = content.split('---', 2)
    if len(parts) < 3:
        errors += 1
        broken.append(skill_path)
        continue
    count += 1

print(f'Total OK: {count}, Errors: {errors}')
if broken:
    for b in broken[:10]:
        print(f'  BROKEN: {b}')