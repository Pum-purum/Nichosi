<script lang="ts">
  import { ArrowDownToLine, ChevronDown, ChevronRight, Clock, Columns3, Database, FileText, Filter, HardDrive, KeyRound, Maximize2, MoreHorizontal, Pencil, Plus, RefreshCw, Search, Server, Settings, ShieldCheck, SlidersHorizontal, TableProperties, TerminalSquare, Trash2, UserRound } from '@lucide/svelte';
  import { onMount } from 'svelte';
  import type { components } from './lib/api/schema';

  type Connection = components['schemas']['Connection'];
  type TableInfo = components['schemas']['TableInfo'];
  type RowsPage = components['schemas']['RowsPage'];

  let connections = $state<Connection[]>([]);
  let error = $state('');
  let loading = $state(true);
  let selectedConnection = $state<Connection | null>(null);
  let selectedTable = $state('customers');
  let tableSearch = $state('');
  let tables = $state<TableInfo[]>([]);
  let objects = $state<components['schemas']['DatabaseObject'][]>([]);
  let rowsPage = $state<RowsPage | null>(null);
  let databaseLoading = $state(false);


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

  async function openDatabase(connection: Connection) {
    selectedConnection = connection; selectedTable = ''; rowsPage = null; tables = []; objects = []; error = ''; databaseLoading = true;
    try {
      const schema = await request<components['schemas']['Schema']>(`/api/connections/${encodeURIComponent(connection.id)}/schema`);
      tables = schema.tables; objects = schema.objects;
      if (tables.length) await selectTable(tables[0].name);
    } catch (cause) { error = cause instanceof Error ? cause.message : 'Could not read database schema'; }
    finally { databaseLoading = false; }
  }

  async function selectTable(name: string) {
    if (!selectedConnection) return;
    selectedTable = name; error = ''; rowsPage = null;
    try { rowsPage = await request<RowsPage>(`/api/connections/${encodeURIComponent(selectedConnection.id)}/tables/${encodeURIComponent(name)}/rows`, { method: 'POST', body: JSON.stringify({ limit: 200 }) }); }
    catch (cause) { error = cause instanceof Error ? cause.message : 'Could not read table rows'; rowsPage = null; }
  }

  onMount(() => { void loadConnections(); });

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
    <p class="config-source">All database connections are loaded from <code>connections.json</code>.</p>
    <ol class="config-steps">
      <li><span>01</span><p>Add a connection object and fill in its host, port, user and database name.</p></li>
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
  </div>
{/snippet}

<svelte:head><title>Databases · Nichosi</title></svelte:head>

<div class="app-shell">
  <header class="topbar">
    <a class="brand" href="#home" aria-label="Nichosi home"><span class="brand-mark" aria-hidden="true"><span></span><span></span><span></span></span>{#if !selectedConnection}<span class="brand-name">nichosi<span>.</span></span>{/if}</a>
    {#if selectedConnection}
      <label class="global-search"><Search size={17} /><input placeholder="Search rows…" aria-label="Search rows" /></label>
      <div class="topbar-breadcrumbs"><button onclick={() => selectedConnection = null}>{selectedConnection.name}</button><ChevronRight size={15} /><span>{selectedConnection.database}</span><ChevronRight size={15} /><span>public</span><ChevronRight size={15} /><strong>{selectedTable}</strong><ChevronDown size={14} /></div>
      <div class="topbar-tools"><span class="prototype-tag"><span></span> Preview</span><button class="tool-button" aria-label="Refresh"><RefreshCw size={17} /></button><button class="tool-button" aria-label="Expand"><Maximize2 size={17} /></button><button class="tool-button" aria-label="Add row" disabled><Plus size={18} /></button><button class="tool-button edit-tool" aria-label="Edit row"><Pencil size={17} /></button><button class="tool-button delete-tool" aria-label="Delete row"><Trash2 size={17} /></button><button class="tool-button" aria-label="Export"><ArrowDownToLine size={17} /></button></div>
    {/if}
  </header>

  <main class:has-connections={connections.length > 0} class:database-open={selectedConnection !== null}>
    {#if selectedConnection}
      <section class="database-workspace" aria-label="Database tables">
        <nav class="app-rail" aria-label="Workspace navigation"><button class="rail-button active" aria-label="Database objects"><HardDrive size={19} /></button><button class="rail-button" aria-label="SQL editor"><TerminalSquare size={19} /></button><button class="rail-button" aria-label="Tables"><TableProperties size={19} /></button><button class="rail-button" aria-label="Query history"><FileText size={19} /></button><span class="rail-spacer"></span><button class="rail-button" aria-label="Settings"><Settings size={19} /></button></nav>
        <aside class="schema-sidebar">
          <div class="objects-heading"><strong>Database Objects</strong><button aria-label="Collapse sidebar"><ChevronRight size={16} /></button></div>
          <button class="tree-root"><ChevronDown size={15} /><Database size={18} /><span>{selectedConnection.name}</span></button>
          <div class="tree-branch"><button class="tree-database"><ChevronDown size={15} /><Database size={18} /><span>{selectedConnection.database}</span></button>
            <button class="tree-group"><ChevronRight size={15} /><span>pg_toast</span><small>(0)</small></button>
            <button class="tree-group expanded"><ChevronDown size={15} /><span>public</span><small>({tables.length})</small></button>
            <label class="table-search"><Search size={14} /><input bind:value={tableSearch} placeholder="Filter objects" aria-label="Filter tables" /></label>
            <nav class="table-nav" aria-label="Tables">
              {#each tables.filter((table) => table.name.toLowerCase().includes(tableSearch.toLowerCase())) as table}
                <button class:active={selectedTable === table.name} class="table-nav-item" onclick={() => void selectTable(table.name)}>
                  <TableProperties size={17} /><span>{table.name}</span><small>{formatBytes(table.dataBytes + table.indexBytes)}</small>
                </button>
              {/each}
            </nav>
            {#each ['view', 'trigger', 'procedure', 'function', 'event'] as objectType}
              {@const group = objects.filter((object) => object.type === objectType)}
              {#if group.length}<button class="tree-group"><ChevronRight size={15} /><span>{objectType}s</span><small>({group.length})</small></button>{/if}
            {/each}
          </div>
          <div class="sidebar-footer"><span class="connection-dot"></span><span>Connected</span><span class="sidebar-footer-host">{selectedConnection.host}:{selectedConnection.port}</span></div>
        </aside>

        <div class="table-main">
          <div class="table-toolbar"><span class="read-only-note"><ShieldCheck size={14} /> {selectedConnection.readOnly ? 'Read only · Production' : 'Read only preview'}</span><span class="toolbar-spacer"></span><label class="data-filter"><Search size={16} /><input placeholder="Filter rows…" aria-label="Filter rows" /></label><button class="toolbar-control"><SlidersHorizontal size={16} /> Filter</button><button class="icon-button" aria-label="Column visibility"><Columns3 size={18} /></button></div>
          <div class="data-grid-wrap">{#if databaseLoading}<p>Loading database…</p>{:else if error}<p>{error}</p>{:else}<table class="data-grid"><thead><tr><th class="actions-head">Actions</th><th class="row-index-head">#</th>{#each (rowsPage?.columns ?? []) as column}<th><span class="column-name">{#if column.primaryKey}<KeyRound size={13} />{/if}{column.name}<span class="sort-arrows">↕</span></span><small>{column.type}{#if column.primaryKey}<em>PK</em>{/if}</small></th>{/each}</tr></thead><tbody>{#each (rowsPage?.rows ?? []) as row, rowIndex}<tr><td class="row-actions"><button aria-label="Edit row"><Pencil size={16} /></button><button aria-label="Delete row"><Trash2 size={16} /></button></td><td class="row-index">{rowIndex + 1}</td>{#each row as value, columnIndex}<td>{#if columnIndex === 4}<span class:status-active={value === 'active'} class:status-pending={value === 'pending'} class:status-inactive={value === 'inactive'} class="status-pill"><span></span>{value}</span>{:else}<span class:muted-value={value === '—'}>{value}</span>{/if}</td>{/each}</tr>{/each}</tbody></table>{/if}</div>
          <footer class="grid-footer"><span>Showing <strong>1–8 of {tables.find((table) => table.name === selectedTable)?.rowsEstimate ?? 0} rows</strong></span><label class="page-size-label">Rows/page: <select aria-label="Rows per page"><option>50</option><option>100</option><option>200</option></select></label><span class="grid-summary">Rows: <strong>{rowsPage?.rows.length ?? 0}</strong> &nbsp; Columns: <strong>{rowsPage?.columns.length ?? 0}</strong></span><span class="pagination"><button disabled aria-label="First page">«</button><button disabled aria-label="Previous page">‹</button><span>Page 1 of 1</span><button disabled aria-label="Next page">›</button><button disabled aria-label="Last page">»</button></span></footer>
        </div>
      </section>
    {:else if loading}
      <section class="empty-state" aria-labelledby="empty-title">
        <div class="empty-icon"><Database size={24} strokeWidth={1.7} /></div>
        <h1 id="empty-title">Loading connections.</h1>
        <p>Reading saved profiles from <code>connections.json</code>.</p>
      </section>
    {:else if error}
      <section class="empty-state" aria-labelledby="empty-title">
        <div class="empty-icon"><Database size={24} strokeWidth={1.7} /></div>
        <h1 id="empty-title">Could not load connections.</h1>
        <p>{error}</p>
        <button class="primary-button empty-action" onclick={() => void loadConnections()}>Try again</button>
      </section>
    {:else if connections.length === 0}
      <section class="empty-state" aria-labelledby="empty-title">
        <div class="empty-icon"><Database size={24} strokeWidth={1.7} /></div>
        <h1 id="empty-title">Connect your first database.</h1>
        {@render connectionInstructions()}
      </section>
    {:else}
      <section class="connections-view" aria-labelledby="connections-title">
        <div class="page-heading"><h1 id="connections-title">Connections</h1></div>
        <div class="connection-list">
          {#each connections as connection (connection.id)}
            <button class="connection-card" onclick={() => void openDatabase(connection)} aria-label={`Open ${connection.name}`}>
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
            </button>
          {/each}
        </div>
      </section>
    {/if}
  </main>
</div>
