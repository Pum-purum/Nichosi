<script lang="ts">
  import { Clock, Database, FileText, HardDrive, LockKeyhole, Plus, Server, ShieldCheck, UserRound, X } from '@lucide/svelte';
  import { onMount } from 'svelte';
  import type { components } from './lib/api/schema';

  type Connection = components['schemas']['Connection'];

  let showConnectionHelp = $state(false);
  let connections = $state<Connection[]>([]);
  let error = $state('');
  let loading = $state(true);

  async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
    const response = await fetch(path, {
      ...init,
      headers: { 'Content-Type': 'application/json', ...init.headers },
    });
    if (!response.ok) {
      const body = await response.json().catch(() => null);
      throw new Error(body?.message ?? `Request failed (${response.status})`);
    }
    return response.json() as Promise<T>;
  }

  async function loadConnections() {
    loading = true;
    error = '';
    try {
      connections = await request<Connection[]>('/api/connections');
    } catch (cause) {
      error = cause instanceof Error ? cause.message : 'Could not load connections';
    } finally { loading = false; }
  }

  onMount(() => { void loadConnections(); });

  function closeHelp() { showConnectionHelp = false; }
  function handleWindowKeydown(event: KeyboardEvent) { if (event.key === 'Escape') closeHelp(); }
  function formatBytes(bytes: number | null) {
    if (bytes === null) return 'Unavailable';
    if (bytes < 1024) return `${bytes} B`;
    const units = ['KB', 'MB', 'GB', 'TB'];
    let size = bytes / 1024;
    let unit = 0;
    while (size >= 1024 && unit < units.length - 1) { size /= 1024; unit += 1; }
    return `${size.toFixed(1)} ${units[unit]}`;
  }
  function formatDate(value: string | null) {
    return value ? new Intl.DateTimeFormat(undefined, { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }).format(new Date(value)) : 'Unavailable';
  }

</script>

{#snippet connectionInstructions()}
  <div class="config-instructions">
    <div class="config-instructions-heading"><FileText size={17} /><div><span class="modal-eyebrow">CONNECTION PROFILES</span><h2 id="modal-title">Edit connections.json</h2></div></div>
    <p class="config-description">Open this file in the project folder and edit its <code>connections</code> array.</p>
    <ol class="config-steps">
      <li><span>01</span><p>The test profile is already there. Replace its empty <code>password</code> value, or add another object to the array.</p></li>
      <li><span>02</span><p>Enter the password directly in the <code>password</code> field. This local file is excluded from Git and the Docker image.</p></li>
      <li><span>03</span><p>Save the file, then restart Nichosi to load the profile.</p></li>
    </ol>
    <pre class="config-example"><code>{`{
  "name": "My database",
  "driver": "mysql",
  "host": "mysql",
  "port": 3306,
  "user": "database_user",
  "database": "database_name",
  "environment": "dev",
  "password": "paste-password-here"
}`}</code></pre>
    <div class="config-restart"><span>RESTART COMMAND</span><code>docker compose --env-file .env -f deploy/docker-compose.yml restart nichosi</code></div>
    <div class="config-footnote"><LockKeyhole size={12} /> The file is mounted read-only inside the app container.</div>
  </div>
{/snippet}

<svelte:window onkeydown={handleWindowKeydown} />
<svelte:head><title>Databases · Nichosi</title></svelte:head>

<div class="app-shell">
  <header class="topbar">
    <a class="brand" href="#home" aria-label="Nichosi home"><span class="brand-mark" aria-hidden="true"><span></span><span></span><span></span></span><span class="brand-name">nichosi<span>.</span></span></a>
    <span class="workspace-label">DATABASE WORKSPACE</span>
    {#if !loading && !error && connections.length > 0}<button class="primary-button header-action" onclick={() => (showConnectionHelp = true)}><Plus size={16} /> Add connection</button>{/if}
  </header>

  <main class:has-connections={connections.length > 0}>
    {#if loading}
      <section class="empty-state" aria-labelledby="empty-title">
        <div class="empty-icon"><Database size={24} strokeWidth={1.7} /></div>
        <span class="eyebrow">DATABASE WORKSPACE</span>
        <h1 id="empty-title">Loading connections.</h1>
        <p>Reading saved profiles from <code>connections.json</code>.</p>
      </section>
    {:else if error}
      <section class="empty-state" aria-labelledby="empty-title">
        <div class="empty-icon"><Database size={24} strokeWidth={1.7} /></div>
        <span class="eyebrow">DATABASE WORKSPACE</span>
        <h1 id="empty-title">Could not load connections.</h1>
        <p>{error}</p>
        <button class="primary-button empty-action" onclick={() => void loadConnections()}>Try again</button>
      </section>
    {:else if connections.length === 0}
      <section class="empty-state" aria-labelledby="empty-title">
        <div class="empty-icon"><Database size={24} strokeWidth={1.7} /></div>
        <span class="eyebrow">A QUIETER WAY TO WORK WITH DATA</span>
        <h1 id="empty-title">Connect your first database.</h1>
        <p>Add a database profile to <code>connections.json</code> to get started.</p>
        {@render connectionInstructions()}
      </section>
    {:else}
      <section class="connections-view" aria-labelledby="connections-title">
        <div class="page-heading"><div><span class="eyebrow">YOUR WORKSPACE</span><h1 id="connections-title">Connections <span>{connections.length.toString().padStart(2, '0')}</span></h1></div><p>Database details at a glance.</p></div>
        <div class="connection-list">
          {#each connections as connection (connection.id)}
            <article class="connection-card">
              <div class="connection-row">
                <span class="connection-type" role="img" aria-label={connection.driver.toUpperCase()} title={connection.driver.toUpperCase()}><Database size={17} strokeWidth={1.8} /></span>
                <span class="connection-name" title={connection.name}>{connection.name}</span>
                <span class="connection-meta" title="Host and port"><Server size={14} /><span>{connection.host}:{connection.port}</span></span>
                <span class="connection-meta" title="Database user"><UserRound size={14} /><span>{connection.user}</span></span>
                <span class="connection-meta" title="Database"><Database size={14} /><span>{connection.database}</span></span>
                <span class="connection-meta" title="Database size"><HardDrive size={14} /><span>{formatBytes(connection.databaseSizeBytes)}</span></span>
                <span class="connection-meta connection-time" title="Last connection"><Clock size={14} /><span>{formatDate(connection.lastConnectedAt)}</span></span>
                {#if connection.readOnly}<span class="connection-readonly" title="Production · read-only"><ShieldCheck size={14} /> Prod</span>{/if}
                <span class="preview-badge connected"><span></span> Connected</span>
              </div>
            </article>
          {/each}
        </div>
        <p class="list-footnote"><LockKeyhole size={13} /> Profiles are read from the local connections.json file.</p>
      </section>
    {/if}
  </main>
</div>

{#if showConnectionHelp}
  <div class="modal-backdrop" role="presentation" onclick={(event) => { if (event.target === event.currentTarget) closeHelp(); }}>
    <div class="connection-modal config-help" role="dialog" aria-modal="true" aria-labelledby="modal-title" tabindex="-1">
      <div class="modal-top"><span class="modal-brand-mark"><FileText size={18} /></span><button class="close-button" aria-label="Close dialog" onclick={closeHelp}><X size={17} /></button></div>
      {@render connectionInstructions()}
    </div>
  </div>
{/if}
