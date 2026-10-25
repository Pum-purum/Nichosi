<script lang="ts">
  import { ArrowRight, Check, Database, LockKeyhole, Plus, ShieldCheck, X } from '@lucide/svelte';
  import type { components } from './lib/api/schema';

  type Connection = components['schemas']['Connection'];
  type ConnectionInput = components['schemas']['ConnectionInput'];

  let adminToken = $state('');
  let tokenDraft = $state('');
  let showTokenForm = $state(true);
  let showConnectionModal = $state(false);
  let connectionName = $state('');
  let host = $state('mysql');
  let port = $state('3306');
  let database = $state('bitrix_test');
  let username = $state('nichosi');
  let password = $state('');
  let connections = $state<Connection[]>([]);
  let notice = $state('');
  let error = $state('');
  let busy = $state(false);

  async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
    const response = await fetch(path, {
      ...init,
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${adminToken}`, ...init.headers },
    });
    if (!response.ok) {
      const body = await response.json().catch(() => null);
      throw new Error(body?.message ?? `Request failed (${response.status})`);
    }
    return response.json() as Promise<T>;
  }

  async function unlock(event: SubmitEvent) {
    event.preventDefault();
    adminToken = tokenDraft.trim();
    busy = true;
    error = '';
    try {
      connections = await request<Connection[]>('/api/connections');
      showTokenForm = false;
    } catch (cause) {
      adminToken = '';
      error = cause instanceof Error ? cause.message : 'Could not authorize';
    } finally { busy = false; }
  }

  async function saveConnection(event: SubmitEvent) {
    event.preventDefault();
    busy = true;
    error = '';
    try {
      const payload: ConnectionInput = {
        name: connectionName.trim(), driver: 'mysql', host: host.trim(), port: Number(port),
        user: username.trim(), password, database: database.trim(), environment: 'dev',
      };
      const created = await request<Connection>('/api/connections', {
        method: 'POST',
        body: JSON.stringify(payload),
      });
      connections = [...connections, created];
      showConnectionModal = false;
      password = '';
      connectionName = '';
      notice = 'Connected. Credentials are held in memory until the container restarts.';
      window.setTimeout(() => (notice = ''), 5000);
    } catch (cause) {
      error = cause instanceof Error ? cause.message : 'Could not connect';
    } finally { busy = false; }
  }

  function closeModal() { showConnectionModal = false; error = ''; password = ''; }
  function handleWindowKeydown(event: KeyboardEvent) { if (event.key === 'Escape') closeModal(); }
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

<svelte:window onkeydown={handleWindowKeydown} />
<svelte:head><title>Databases · Nichosi</title></svelte:head>

<div class="app-shell">
  <header class="topbar">
    <a class="brand" href="#home" aria-label="Nichosi home"><span class="brand-mark" aria-hidden="true"><span></span><span></span><span></span></span><span class="brand-name">nichosi<span>.</span></span></a>
    <span class="workspace-label">DATABASE WORKSPACE</span>
    {#if !showTokenForm && connections.length > 0}<button class="primary-button header-action" onclick={() => (showConnectionModal = true)}><Plus size={16} /> Add connection</button>{/if}
  </header>

  <main class:has-connections={connections.length > 0}>
    {#if showTokenForm}
      <section class="empty-state" aria-labelledby="empty-title">
        <div class="empty-icon"><LockKeyhole size={24} /></div>
        <span class="eyebrow">LOCAL ADMIN ACCESS</span>
        <h1 id="empty-title">Unlock your workspace.</h1>
        <p>Enter the admin token from the project’s local <code>.env</code> file. It stays in this browser session only.</p>
        <form class="unlock-form" onsubmit={unlock}>
          <label class="field-label">Admin token<input bind:value={tokenDraft} type="password" autocomplete="off" placeholder="Paste NICHOSI_ADMIN_TOKEN" required /></label>
          <button class="primary-button empty-action" type="submit" disabled={busy}>{busy ? 'Checking…' : 'Unlock workspace'} <ArrowRight size={15} /></button>
        </form>
        {#if error}<p class="error-message">{error}</p>{/if}
        <div class="preview-note"><LockKeyhole size={13} /> Token is not stored on disk or in local storage.</div>
      </section>
    {:else if connections.length === 0}
      <section class="empty-state" aria-labelledby="empty-title">
        <div class="empty-icon"><Database size={24} strokeWidth={1.7} /></div>
        <span class="eyebrow">A QUIETER WAY TO WORK WITH DATA</span>
        <h1 id="empty-title">Connect your first database.</h1>
        <p>Connect to a MySQL or MariaDB database and keep its details in one clear workspace.</p>
        <button class="primary-button empty-action" onclick={() => (showConnectionModal = true)}><Plus size={17} /> Connect to a database</button>
        <div class="driver-list"><span class="driver-list-label">MYSQL</span><span class="driver-separator"></span><span class="driver-list-label">MARIADB</span></div>
        <div class="preview-note"><LockKeyhole size={13} /> Passwords stay in memory and are cleared when Nichosi restarts.</div>
      </section>
    {:else}
      <section class="connections-view" aria-labelledby="connections-title">
        <div class="page-heading"><div><span class="eyebrow">YOUR WORKSPACE</span><h1 id="connections-title">Connections <span>{connections.length.toString().padStart(2, '0')}</span></h1></div><p>Database details at a glance.</p></div>
        <div class="connection-list">
          {#each connections as connection (connection.id)}
            <article class="connection-card">
              <div class="connection-main"><span class="database-icon amber"><Database size={19} strokeWidth={1.7} /></span><div class="connection-title"><h2>{connection.name}</h2><p>{connection.database}<span>·</span>{connection.host}:{connection.port}</p></div><span class="preview-badge connected"><span></span> Connected</span></div>
              <dl class="connection-details"><div><dt>DATABASE TYPE</dt><dd>{connection.driver.toUpperCase()}</dd></div><div><dt>DATABASE SIZE</dt><dd>{formatBytes(connection.databaseSizeBytes)}</dd></div><div><dt>LAST CONNECTION</dt><dd>{formatDate(connection.lastConnectedAt)}</dd></div><div><dt>DATABASE CREATED</dt><dd>{formatDate(connection.databaseCreatedAt)}</dd></div></dl>
              {#if connection.readOnly}<div class="production-note"><ShieldCheck size={14} /> Production connections are read-only.</div>{/if}
            </article>
          {/each}
        </div>
        <p class="list-footnote"><LockKeyhole size={13} /> Connection passwords remain in memory only for this container session.</p>
      </section>
    {/if}
  </main>
</div>

{#if showConnectionModal}
  <div class="modal-backdrop" role="presentation" onclick={(event) => { if (event.target === event.currentTarget) closeModal(); }}>
    <div class="connection-modal" role="dialog" aria-modal="true" aria-labelledby="modal-title" tabindex="-1">
      <div class="modal-top"><span class="modal-brand-mark"><Database size={18} /></span><button class="close-button" aria-label="Close dialog" onclick={closeModal}><X size={17} /></button></div>
      <div class="modal-intro"><span class="modal-eyebrow">NEW CONNECTION</span><h2 id="modal-title">Connect a database.</h2><p>Credentials are used to connect and held in memory for this session.</p></div>
      <form onsubmit={saveConnection}>
        <label class="field-label">Connection name <span>OPTIONAL</span><input bind:value={connectionName} placeholder="e.g. Local development" /></label>
        <div class="field-pair"><label class="field-label">Host<input bind:value={host} placeholder="mysql" required /></label><label class="field-label">Port<input bind:value={port} inputmode="numeric" placeholder="3306" required /></label></div>
        <label class="field-label">Database name<input bind:value={database} placeholder="bitrix_test" required /></label>
        <div class="field-pair"><label class="field-label">Username<input bind:value={username} autocomplete="username" placeholder="Database user" required /></label><label class="field-label">Password<input bind:value={password} type="password" autocomplete="current-password" placeholder="Database password" required /></label></div>
        {#if error}<p class="error-message">{error}</p>{/if}
        <div class="modal-actions"><button type="button" class="cancel-button" onclick={closeModal}>Cancel</button><button type="submit" class="primary-button modal-submit" disabled={busy}>{busy ? 'Connecting…' : 'Connect'} <ArrowRight size={14} /></button></div>
      </form>
      <div class="modal-footnote"><LockKeyhole size={12} /> The password is never returned by the API.</div>
    </div>
  </div>
{/if}

{#if notice}<div class="toast"><span><Check size={14} /></span>{notice}<button aria-label="Dismiss" onclick={() => (notice = '')}><X size={14} /></button></div>{/if}
