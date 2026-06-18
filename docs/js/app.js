// Hermes Community Hub — App
const GITHUB_RAW = 'https://raw.githubusercontent.com/nous-hermeshub/hermes-community-hub/main';

async function loadSkills() {
    try {
        const [indexRes, ratingsRes] = await Promise.all([
            fetch(`${GITHUB_RAW}/index.json`),
            fetch(`${GITHUB_RAW}/data/ratings.json`).catch(() => null)
        ]);
        const index = await indexRes.json();
        const ratings = ratingsRes ? await ratingsRes.json() : null;
        renderSkills(index.skills, ratings);
        renderStats(index.skills);
        renderTrending(index.skills);
        renderFilterTags(index.skills);
    } catch (e) {
        document.getElementById('skills-grid').innerHTML =
            `<div class="empty-state"><h3>Could not load skills</h3><p>GitHub might be throttling us. Refresh in a moment.</p></div>`;
    }
}

function renderStats(skills) {
    const authors = new Set(skills.map(s => s.author?.github || s.author || 'unknown'));
    document.getElementById('total-skills').textContent = skills.length;
    document.getElementById('total-authors').textContent = authors.size;
}

function renderTrending(skills) {
    const grid = document.getElementById('trending-grid');
    const top = skills.slice(0, 3);
    if (!top.length) {
        grid.innerHTML = `<div class="empty-state"><h3>No skills yet</h3><p>Be the first to publish!</p></div>`;
        return;
    }
    grid.innerHTML = top.map(s => skillCard(s, true)).join('');
}

function renderSkills(skills) {
    const grid = document.getElementById('skills-grid');
    if (!skills.length) {
        grid.innerHTML = `<div class="empty-state"><h3>No skills in the hub yet</h3><p>Publish one via <code>hub-publish.sh</code> or submit a PR</p></div>`;
        return;
    }
    grid.innerHTML = skills.map(s => skillCard(s)).join('');
}

function skillCard(skill, featured = false) {
    const tags = skill.tags || [];
    const author = skill.author?.name || skill.author || 'Community';
    const github = skill.author?.github || '';
    const icon = skill.metadata?.hermes?.icon || '📦';
    const cat = skill.category || 'general';
    return `
        <div class="skill-card">
            <div class="card-header">
                <div>
                    <div class="card-icon">${icon}</div>
                    <div class="card-name">${skill.name}</div>
                    <div class="card-author">by ${author} ${github ? '· @' + github : ''}</div>
                </div>
                ${featured ? '<span style="color:var(--orange)">🔥</span>' : ''}
            </div>
            <div class="card-desc">${skill.description || ''}</div>
            <div class="card-tags">${tags.map(t => `<span class="card-tag">${t}</span>`).join('')}</div>
            <div class="card-meta">
                <span>📁 ${cat}</span>
                <span>📅 ${skill.published || '?'}</span>
                <span>⚡ v${skill.version || '1.0'}</span>
            </div>
            <a class="card-install" target="_blank" href="https://github.com/nous-hermeshub/hermes-community-hub/tree/main/skills/${skill.name}">View on GitHub →</a>
        </div>
    `;
}

function renderFilterTags(skills) {
    const allTags = new Set();
    skills.forEach(s => (s.tags || []).forEach(t => allTags.add(t)));
    const container = document.getElementById('filter-tags');
    container.innerHTML = Array.from(allTags).sort().map(t =>
        `<span class="filter-tag" onclick="toggleFilter(this, '${t}')">${t}</span>`
    ).join('');
}

let activeFilters = new Set();

function toggleFilter(el, tag) {
    el.classList.toggle('active');
    if (activeFilters.has(tag)) activeFilters.delete(tag);
    else activeFilters.add(tag);
    filterSkills();
}

function filterSkills() {
    const query = document.getElementById('search-input').value.toLowerCase();
    const cards = document.querySelectorAll('#skills-grid .skill-card');
    cards.forEach(card => {
        const text = card.textContent.toLowerCase();
        const matchesQuery = !query || text.includes(query);
        const matchesTag = activeFilters.size === 0 ||
            Array.from(activeFilters).some(t => text.includes(t.toLowerCase()));
        card.style.display = matchesQuery && matchesTag ? '' : 'none';
    });
}

loadSkills();
