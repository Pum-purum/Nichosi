<script lang="ts">
  import { ArrowRight, Check, ChevronDown, Database, LockKeyhole, Plus, ShieldCheck, X } from '@lucide/svelte';

  type Driver = 'MySQL' | 'PostgreSQL' | 'SQLite';
  type ConnectionPreview = {
    name: string;
    driver: Driver;
    host: string;
    database: string;
    environment: string;
    color: string;
    databaseSize: string | null;
    lastConnected: string | null;
    databaseCreatedAt: string | null;
  };

  let showConnectionModal = $state(false);
  let connectionName = $state('');
  let driver = $state<Driver>('MySQL');
  let host = $state('127.0.0.1');
  let port = $state('3306');
  let database = $state('');
  let username = $state('');
  let password = $state('');
  let environment = $state('Development');
  let notice = $state('');
  let connections = $state<ConnectionPreview[]>([]);

  function closeModal() {
    showConnectionModal = false;
  }

  function handleWindowKeydown(event: KeyboardEvent) {
    if (event.key === 'Escape') closeModal();
  }

  function saveConnection(event: SubmitEvent) {
    event.preventDefault();
    const nextName = connectionName.trim() || database.trim() || `${driver} connection`;
    connections = [...connections, {
      name: nextName,
      driver,
      host: driver === 'SQLite' ? 'Local file' : host,
      database: database || 'Untitled database',
      environment,
      color: driver === 'MySQL' ? 'amber' : driver === 'PostgreSQL' ? 'blue' : 'mint',
      databaseSize: null,
      lastConnected: null,
      databaseCreatedAt: null,
    }];
    closeModal();
    notice = 'Added a connection preview. Live database access is not available yet.';
    window.setTimeout(() => (notice = ''), 4200);
    connectionName = '';
    database = '';
    username = '';
    password = '';
  }
</script>

<svelte:window onkeydown={handleWindowKeydown} />

<svelte:head>
  <title>Databases · Nichosi</title>
</svelte:head>

<div class="app-shell">
  <header class="topbar">
    <a class="brand" href="#home" aria-label="Nichosi home">
      <span class="brand-mark" aria-hidden="true"><span></span><span></span><span></span></span>
      <span class="brand-name">nichosi<span>.</span></span>
    </a>
    <span class="workspace-label">DATABASE WORKSPACE</span>
    {#if connections.length > 0}
      <button class="primary-button header-action" onclick={() => (showConnectionModal = true)}><Plus size={16} /> Add connection</button>
    {/if}
  </header>

  <main class:has-connections={connections.length > 0}>
    {#if connections.length === 0}
      <section class="empty-state" aria-labelledby="empty-title">
        <div class="empty-icon"><Database size={24} strokeWidth={1.7} /></div>
        <span class="eyebrow">A QUIETER WAY TO WORK WITH DATA</span>
        <h1 id="empty-title">Connect your first database.</h1>
        <p>Bring your database connections together in one clear, focused workspace.</p>
        <button class="primary-button empty-action" onclick={() => (showConnectionModal = true)}><Plus size={17} /> Connect to a database</button>
        <div class="driver-list" aria-label="Planned database types">
          <span class="driver-list-label">MYSQL</span><span class="driver-separator"></span>
          <span class="driver-list-label">POSTGRESQL</span><span class="driver-separator"></span>
          <span class="driver-list-label">SQLITE</span>
        </div>
        <div class="preview-note"><LockKeyhole size={13} /> Early preview: credentials are not saved and no database is contacted.</div>
      </section>
    {:else}
      <section class="connections-view" aria-labelledby="connections-title">
        <div class="page-heading">
          <div>
            <span class="eyebrow">YOUR WORKSPACE</span>
            <h1 id="connections-title">Connections <span>{connections.length.toString().padStart(2, '0')}</span></h1>
          </div>
          <p>Database details at a glance.</p>
        </div>

        <div class="connection-list">
          {#each connections as connection}
            <article class="connection-card">
              <div class="connection-main">
                <span class="database-icon {connection.color}"><Database size={19} strokeWidth={1.7} /></span>
                <div class="connection-title">
                  <h2>{connection.name}</h2>
                  <p>{connection.database}<span>·</span>{connection.host}</p>
                </div>
                <span class="preview-badge"><span></span> Preview</span>
              </div>
              <dl class="connection-details">
                <div><dt>DATABASE TYPE</dt><dd>{connection.driver}</dd></div>
                <div><dt>DATABASE SIZE</dt><dd>{connection.databaseSize ?? 'No data yet'}</dd></div>
                <div><dt>LAST CONNECTION</dt><dd>{connection.lastConnected ?? 'Not connected'}</dd></div>
                <div><dt>DATABASE CREATED</dt><dd>{connection.databaseCreatedAt ?? 'Unavailable'}</dd></div>
              </dl>
              {#if connection.environment === 'Production'}
                <div class="production-note"><ShieldCheck size={14} /> Production connections will default to read-only.</div>
              {/if}
            </article>
          {/each}
        </div>
        <p class="list-footnote"><LockKeyhole size={13} /> Previews last for this session. Live connections and saved profiles are coming next.</p>
      </section>
    {/if}
  </main>
</div>

{#if showConnectionModal}
  <div class="modal-backdrop" role="presentation" onclick={(event) => { if (event.target === event.currentTarget) closeModal(); }}>
    <div class="connection-modal" role="dialog" aria-modal="true" aria-labelledby="modal-title" tabindex="-1">
      <div class="modal-top">
        <span class="modal-brand-mark"><Database size={18} /></span>
        <button class="close-button" aria-label="Close dialog" onclick={closeModal}><X size={17} /></button>
      </div>
      <div class="modal-intro">
        <span class="modal-eyebrow">NEW CONNECTION</span>
        <h2 id="modal-title">Add a database.</h2>
        <p>Set up a connection preview. Live database access is coming next.</p>
      </div>
      <form onsubmit={saveConnection}>
        <label class="field-label">Connection name <span>OPTIONAL</span><input bind:value={connectionName} placeholder="e.g. Local development" /></label>
        <fieldset class="driver-field">
          <legend>Database type</legend>
          <div class="driver-options">
            {#each ['MySQL', 'PostgreSQL', 'SQLite'] as choice}
              <button type="button" class:chosen={driver === choice} class="driver-option" onclick={() => { driver = choice as Driver; port = driver === 'PostgreSQL' ? '5432' : '3306'; }}>
                <span class="driver-glyph {choice === 'MySQL' ? 'amber' : choice === 'PostgreSQL' ? 'blue' : 'mint'}"><Database size={14} /></span>
                <span>{choice}</span>
                {#if driver === choice}<Check size={14} class="driver-check" />{/if}
              </button>
            {/each}
          </div>
        </fieldset>
        {#if driver !== 'SQLite'}
          <div class="field-pair">
            <label class="field-label">Host<input bind:value={host} placeholder="127.0.0.1" required /></label>
            <label class="field-label">Port<input bind:value={port} inputmode="numeric" placeholder="3306" required /></label>
          </div>
          <label class="field-label">Database name<input bind:value={database} placeholder="Database name" required /></label>
          <div class="field-pair">
            <label class="field-label">Username<input bind:value={username} autocomplete="username" placeholder="Database user" required /></label>
            <label class="field-label">Password<input bind:value={password} type="password" autocomplete="current-password" placeholder="••••••••" required /></label>
          </div>
        {:else}
          <label class="field-label">Database file path<input bind:value={database} placeholder="/path/to/database.sqlite" required /></label>
        {/if}
        <label class="field-label">Environment<select bind:value={environment}><option>Development</option><option>Staging</option><option>Production</option></select></label>
        <div class="modal-actions">
          <button type="button" class="cancel-button" onclick={closeModal}>Cancel</button>
          <button type="submit" class="primary-button modal-submit">Create preview <ArrowRight size={14} /></button>
        </div>
      </form>
      <div class="modal-footnote"><LockKeyhole size={12} /> Preview only — credentials are not saved or sent.</div>
    </div>
  </div>
{/if}

{#if notice}<div class="toast"><span><Check size={14} /></span>{notice}<button aria-label="Dismiss" onclick={() => (notice = '')}><X size={14} /></button></div>{/if}
