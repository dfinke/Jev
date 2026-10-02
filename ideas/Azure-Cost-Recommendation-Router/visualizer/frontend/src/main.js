const app = window.go.main.App;
const elements = {
  path: document.getElementById('csv-path'),
  count: document.getElementById('record-count'),
  run: document.getElementById('run-button'),
  choose: document.getElementById('choose-csv'),
  pace: document.getElementById('pace'),
  status: document.getElementById('status'),
  statusText: document.getElementById('status-text'),
  currentId: document.getElementById('current-id'),
  currentContent: document.getElementById('current-content'),
  progress: document.getElementById('row-progress'),
  classification: document.getElementById('classification'),
  confidence: document.getElementById('confidence'),
  route: document.getElementById('route'),
  routeReason: document.getElementById('route-reason'),
  activity: document.getElementById('activity-list'),
  completed: document.getElementById('completed-count'),
  output: document.getElementById('output-note'),
  diagramAnswer: document.getElementById('diagram-answer'),
  diagramConfidence: document.getElementById('diagram-confidence'),
  diagramCase: document.getElementById('diagram-case'),
  themeToggle: document.getElementById('theme-toggle'),
  themeIcon: document.getElementById('theme-icon'),
  themeLabel: document.getElementById('theme-label'),
  particle: document.getElementById('flow-particle'),
  trail: document.getElementById('flow-trail'),
};

const bucketCounts = {
  cost_owner_review: 0,
  technical_review: 0,
  needs_context: 0,
};
let currentTotal = 0;
let particleGeneration = 0;
let particleQueue = Promise.resolve();

function setTheme(theme) {
  const isDark = theme === 'dark';
  document.documentElement.dataset.theme = isDark ? 'dark' : 'light';
  elements.themeToggle.setAttribute('aria-pressed', String(isDark));
  elements.themeToggle.setAttribute('aria-label', `Switch to ${isDark ? 'light' : 'dark'} mode`);
  elements.themeIcon.textContent = isDark ? '☀' : '☾';
  elements.themeLabel.textContent = isDark ? 'Light mode' : 'Dark mode';
}

const savedTheme = localStorage.getItem('azure-cost-flow-theme');
setTheme(savedTheme === 'dark' ? 'dark' : 'light');

function setStatus(text, state = '') {
  elements.statusText.textContent = text;
  elements.status.className = `status ${state}`.trim();
}

function escapeHTML(value) {
  return String(value ?? '').replace(/[&<>"']/g, (char) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[char]);
}

function displayName(path) {
  return String(path || '').split(/[\\/]/).pop() || path;
}

async function inspectFile(path) {
  if (!path) return;
  try {
    const info = await app.InspectCSV(path);
    elements.path.textContent = info.path;
    elements.path.title = info.path;
    elements.count.textContent = info.recordCount;
    setStatus('Ready');
  } catch (error) {
    elements.path.textContent = path;
    elements.path.title = path;
    elements.count.textContent = '—';
    setStatus('CSV needs attention', 'error');
    showError(error);
  }
}

function showError(error) {
  const message = String(error?.message || error || 'Unknown error').replace(/^Error:\s*/, '');
  elements.currentId.textContent = 'Could not run';
  elements.currentContent.innerHTML = `<p class="error-message">${escapeHTML(message)}</p>`;
}

function startParticleAtInput() {
  const generation = particleGeneration;
  particleQueue = particleQueue.then(() => {
    if (generation !== particleGeneration) return;
    elements.particle.setAttribute('cx', '230');
    elements.particle.setAttribute('cy', '106');
    elements.particle.setAttribute('visibility', 'visible');
    elements.trail.setAttribute('visibility', 'hidden');
  }).catch(() => {});
}

function animateParticleAlong(pathIds) {
  const generation = particleGeneration;
  elements.particle.setAttribute('visibility', 'visible');
  particleQueue = particleQueue.then(async () => {
    for (const pathId of pathIds) {
      if (generation !== particleGeneration) return;
      const path = document.getElementById(pathId);
      if (!path) continue;
      const length = path.getTotalLength();
      const duration = pathId.startsWith('path-route-') ? 260 : pathId.startsWith('path-process-') ? 240 : 180;
      elements.trail.setAttribute('d', path.getAttribute('d'));
      elements.trail.setAttribute('stroke-dasharray', `${length} ${length}`);
      elements.trail.setAttribute('stroke-dashoffset', String(length));
      elements.trail.setAttribute('visibility', 'visible');
      await new Promise((resolve) => {
        const startedAt = performance.now();
        const move = (now) => {
          if (generation !== particleGeneration) return resolve();
          const progress = Math.min((now - startedAt) / duration, 1);
          const point = path.getPointAtLength(length * progress);
          elements.particle.setAttribute('cx', point.x);
          elements.particle.setAttribute('cy', point.y);
          elements.trail.setAttribute('stroke-dashoffset', String(length * (1 - progress)));
          if (progress < 1) requestAnimationFrame(move);
          else resolve();
        };
        requestAnimationFrame(move);
      });
    }
  }).catch(() => {});
}

function resetRun() {
  particleGeneration++;
  particleQueue = Promise.resolve();
  elements.particle.setAttribute('visibility', 'hidden');
  elements.trail.setAttribute('visibility', 'hidden');
  for (const key of Object.keys(bucketCounts)) bucketCounts[key] = 0;
  updateCounts();
  elements.completed.textContent = '0';
  elements.activity.innerHTML = '<div class="empty-state">Waiting for the first recommendation…</div>';
  elements.currentId.textContent = 'Starting…';
  elements.currentContent.innerHTML = '<p class="empty-state">Reading the selected CSV.</p>';
  elements.progress.textContent = `0 / ${currentTotal}`;
  elements.classification.textContent = '—';
  elements.confidence.textContent = '—';
  elements.route.textContent = '—';
  elements.routeReason.textContent = '';
  elements.diagramAnswer.textContent = 'reviewLane';
  elements.diagramConfidence.textContent = 'category + confidence';
  elements.diagramCase.textContent = 'match a case';
  document.querySelectorAll('.flow-node, .bucket-node, .connector').forEach((node) => {
    node.classList.remove('active', 'done');
  });
}

function activate(stage) {
  const stages = ['input', 'jev', 'classify', 'switch'];
  const activeIndex = stages.indexOf(stage);
  document.querySelectorAll('.flow-node').forEach((node) => {
    const index = stages.indexOf(node.dataset.stage);
    node.classList.toggle('active', node.dataset.stage === stage);
    if (index >= 0 && index < activeIndex) node.classList.add('done');
  });
  const connectors = [...document.querySelectorAll('.connector:not(.route-connector)')];
  connectors.forEach((connector, index) => {
    connector.classList.toggle('active', index === activeIndex - 1);
    if (index < activeIndex - 1) connector.classList.add('done');
  });
}

function formatRecord(record) {
  elements.currentContent.innerHTML = `
    <div class="record-meta">
      <span class="pill">${escapeHTML(record.RecommendationId)}</span>
      <span class="pill">${escapeHTML(record.Environment)}</span>
      <span class="pill">$${escapeHTML(record.PotentialMonthlySavingsUsd)} / mo potential</span>
    </div>
    <div class="record-text"><strong>${escapeHTML(record.ResourceType)}</strong> · ${escapeHTML(record.Recommendation)}</div>
    <div class="record-note">“${escapeHTML(record.OwnerNote)}”</div>`;
}

function updateCounts() {
  document.getElementById('count-cost').textContent = bucketCounts.cost_owner_review;
  document.getElementById('count-technical').textContent = bucketCounts.technical_review;
  document.getElementById('count-context').textContent = bucketCounts.needs_context;
  document.getElementById('summary-cost').textContent = bucketCounts.cost_owner_review;
  document.getElementById('summary-technical').textContent = bucketCounts.technical_review;
  document.getElementById('summary-context').textContent = bucketCounts.needs_context;
  const total = Object.values(bucketCounts).reduce((sum, count) => sum + count, 0);
  elements.completed.textContent = total;
}

function handleFlowEvent(event) {
  switch (event.type) {
    case 'run_started':
      currentTotal = event.total || 0;
      elements.output.textContent = `Results → ${event.outputPath || ''}`;
      setStatus('Running', 'running');
      break;
    case 'record_started':
      startParticleAtInput();
      activate('input');
      elements.currentId.textContent = event.record?.RecommendationId || `Record ${event.index}`;
      elements.progress.textContent = `${event.index} / ${event.total}`;
      elements.classification.textContent = 'waiting for Jev';
      elements.confidence.textContent = '—';
      elements.route.textContent = '—';
      elements.routeReason.textContent = '';
      elements.diagramAnswer.textContent = 'reviewLane';
      elements.diagramConfidence.textContent = 'category + confidence';
      elements.diagramCase.textContent = 'match a case';
      document.querySelectorAll('.route-connector, .bucket-node').forEach((node) => node.classList.remove('active'));
      formatRecord(event.record || {});
      break;
    case 'jev_started':
      activate('jev');
      animateParticleAlong(['path-input-jev']);
      break;
    case 'classified':
      activate('classify');
      animateParticleAlong(['path-process-jev', 'path-jev-answer']);
      elements.classification.textContent = event.reviewLane || '—';
      elements.confidence.textContent = `${Math.round((event.confidence || 0) * 100)}%`;
      elements.diagramAnswer.textContent = event.reviewLane || 'classified';
      elements.diagramConfidence.textContent = `${Math.round((event.confidence || 0) * 100)}% confidence`;
      break;
    case 'switch_matched':
      activate('switch');
      animateParticleAlong([
        'path-process-answer',
        'path-answer-switch',
        'path-process-switch',
        `path-route-${event.reviewLane}`,
      ]);
      elements.diagramCase.textContent = `case '${event.reviewLane}'`;
      elements.route.textContent = event.route || '—';
      elements.routeReason.textContent = event.reason || '';
      document.querySelectorAll('.route-connector').forEach((node) => {
        node.classList.toggle('active', node.dataset.lane === event.reviewLane);
      });
      break;
    case 'routed': {
      document.querySelectorAll('.flow-node').forEach((node) => {
        node.classList.remove('active');
        node.classList.add('done');
      });
      document.querySelectorAll('.connector:not(.route-connector)').forEach((node) => {
        node.classList.remove('active');
        node.classList.add('done');
      });
      document.querySelectorAll('.route-connector').forEach((node) => {
        node.classList.toggle('active', node.dataset.lane === event.reviewLane);
      });
      document.querySelectorAll('.bucket-node').forEach((node) => {
        node.classList.toggle('active', node.dataset.bucket === event.reviewLane);
      });
      if (Object.prototype.hasOwnProperty.call(bucketCounts, event.reviewLane)) {
        bucketCounts[event.reviewLane]++;
      }
      updateCounts();
      appendActivity(event);
      break;
    }
    case 'error':
      setStatus('Run stopped', 'error');
      showError(event.message || 'The PowerShell run failed.');
      break;
    case 'run_finished':
      elements.run.disabled = false;
      elements.run.innerHTML = '<span class="play-icon">▶</span> Run again';
      if (event.success) {
        setStatus('Complete', 'success');
        elements.currentId.textContent = 'Run complete';
        elements.progress.textContent = `${event.total} / ${event.total}`;
      } else {
        setStatus('Run failed', 'error');
        if (event.message) showError(event.message);
      }
      if (event.outputPath) elements.output.textContent = `Results → ${event.outputPath}`;
      break;
    default:
      break;
  }
}

function appendActivity(event) {
  const empty = elements.activity.querySelector('.empty-state');
  if (empty) empty.remove();
  const item = event.record || {};
  const line = document.createElement('div');
  line.className = 'activity-item';
  line.innerHTML = `
    <span class="activity-id">${escapeHTML(item.RecommendationId || `#${event.index}`)}</span>
    <span class="activity-lane">${escapeHTML(event.reviewLane)}</span>
    <span class="activity-route">${escapeHTML(event.route)}</span>`;
  elements.activity.prepend(line);
}

window.runtime.EventsOn('flow:event', handleFlowEvent);

elements.themeToggle.addEventListener('click', () => {
  const nextTheme = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
  setTheme(nextTheme);
  localStorage.setItem('azure-cost-flow-theme', nextTheme);
});

elements.choose.addEventListener('click', async () => {
  try {
    const selected = await app.SelectCSV();
    if (selected) await inspectFile(selected);
  } catch (error) {
    showError(error);
    setStatus('Could not open CSV', 'error');
  }
});

elements.run.addEventListener('click', async () => {
  const inputPath = elements.path.title || elements.path.textContent;
  const delayMs = Number(elements.pace.value);
  elements.run.disabled = true;
  elements.run.textContent = 'Starting…';
  resetRun();
  setStatus('Starting PowerShell', 'running');
  try {
    await app.RunDemo(inputPath, delayMs);
  } catch (error) {
    elements.run.disabled = false;
    elements.run.innerHTML = '<span class="play-icon">▶</span> Run flow';
    setStatus('Could not start', 'error');
    showError(error);
  }
});

async function initialize() {
  try {
    const path = await app.GetSampleCSV();
    await inspectFile(path);
  } catch (error) {
    setStatus('Sample CSV not found', 'error');
    showError(error);
  }
}

initialize();
