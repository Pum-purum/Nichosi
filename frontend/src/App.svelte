<script lang="ts">
  import { Braces, Clock, Code2, Columns3, Database, Eye, Filter, HardDrive, KeyRound, Pencil, Search, Server, ShieldCheck, SlidersHorizontal, TableProperties, Trash2, Unplug, UserRound, Zap } from '@lucide/svelte';
  import { onMount } from 'svelte';
  import type { components } from './lib/api/schema';

  type Connection = components['schemas']['Connection'];
  type TableInfo = components['schemas']['TableInfo'];
  type RowsPage = components['schemas']['RowsPage'];
  type DatabaseObject = components['schemas']['DatabaseObject'];
  type ObjectType = DatabaseObject['type'] | 'table';

  const objectSections: { type: ObjectType; label: string }[] = [
    { type: 'table', label: 'Tables' },
    { type: 'view', label: 'Views' },
    { type: 'trigger', label: 'Triggers' },
    { type: 'role', label: 'Roles' },
    { type: 'procedure', label: 'Procedures' },
    { type: 'function', label: 'Functions' },
    { type: 'event', label: 'Events' },
  ];

  let connections = $state<Connection[]>([]);
  let error = $state('');
  let loading = $state(true);
  let selectedConnection = $state<Connection | null>(null);
  let selectedTable = $state('');
  let activeObjectType = $state<ObjectType>('table');
  let selectedObject = $state<DatabaseObject | null>(null);
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
    selectedConnection = connection; selectedTable = ''; activeObjectType = 'table'; selectedObject = null; rowsPage = null; tables = []; objects = []; error = ''; databaseLoading = true;
    try {
      const connected = await request<Connection>(`/api/connections/${encodeURIComponent(connection.id)}/connect`, { method: 'POST' });
      selectedConnection = connected;
      connections = connections.map((item) => item.id === connected.id ? connected : item);
      const schema = await request<components['schemas']['Schema']>(`/api/connections/${encodeURIComponent(connection.id)}/schema`);
      tables = schema.tables; objects = schema.objects;
      if (tables.length) await selectTable(tables[0].name);
    } catch (cause) { error = cause instanceof Error ? cause.message : 'Could not read database schema'; }
    finally { databaseLoading = false; }
  }

  async function selectTable(name: string) {
    if (!selectedConnection) return;
    activeObjectType = 'table'; selectedObject = null; selectedTable = name; error = ''; rowsPage = null;
    try { rowsPage = await request<RowsPage>(`/api/connections/${encodeURIComponent(selectedConnection.id)}/tables/${encodeURIComponent(name)}/rows`, { method: 'POST', body: JSON.stringify({ limit: 200 }) }); }
    catch (cause) { error = cause instanceof Error ? cause.message : 'Could not read table rows'; rowsPage = null; }
  }

  function selectSection(type: ObjectType) {
    activeObjectType = type;
    selectedObject = null;
    tableSearch = '';
    if (type === 'table' && !selectedTable && tables.length) void selectTable(tables[0].name);
  }

  function sectionCount(type: ObjectType) {
    return type === 'table' ? tables.length : objects.filter((object) => object.type === type).length;
  }

  async function disconnect() {
    if (!selectedConnection) return;
    try {
      const closed = await request<Connection>(`/api/connections/${encodeURIComponent(selectedConnection.id)}/disconnect`, { method: 'POST' });
      connections = connections.map((item) => item.id === closed.id ? closed : item);
      selectedConnection = null;
      selectedTable = '';
      selectedObject = null;
      rowsPage = null;
      error = '';
    } catch (cause) {
      error = cause instanceof Error ? cause.message : 'Could not disconnect from the database';
    }
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
  <main class:has-connections={connections.length > 0} class:database-open={selectedConnection !== null}>
    {#if selectedConnection}
      <section class="database-workspace" aria-label="Database tables">
        <nav class="app-rail" aria-label="Workspace navigation">
          {#each objectSections as section}
            <button class:active={activeObjectType === section.type} class="rail-button category-rail-button" aria-label={section.label} aria-current={activeObjectType === section.type ? 'page' : undefined} title={section.label} onclick={() => selectSection(section.type)}>
              {#if section.type === 'table'}<TableProperties size={19} />{:else if section.type === 'view'}<Eye size={19} />{:else if section.type === 'trigger'}<Zap size={19} />{:else if section.type === 'role'}<ShieldCheck size={19} />{:else if section.type === 'event'}<Clock size={19} />{:else if section.type === 'procedure'}<Braces size={19} />{:else}<Code2 size={19} />{/if}
              {#if sectionCount(section.type) > 1}<small>{sectionCount(section.type) > 99 ? '99+' : sectionCount(section.type)}</small>{/if}
            </button>
          {/each}
          <span class="rail-spacer"></span>
        </nav>
        <aside class="schema-sidebar">
          <div class="tree-branch">
            <div class="object-list-heading"><strong>{objectSections.find((section) => section.type === activeObjectType)?.label}</strong>{#if sectionCount(activeObjectType) > 1}<small>{sectionCount(activeObjectType)}</small>{/if}</div>
            <label class="table-search"><Search size={14} /><input bind:value={tableSearch} placeholder={`Filter ${objectSections.find((section) => section.type === activeObjectType)?.label.toLowerCase() ?? 'objects'}`} aria-label="Filter database objects" /></label>
            <nav class="table-nav" aria-label={objectSections.find((section) => section.type === activeObjectType)?.label ?? 'Database objects'}>
              {#if activeObjectType === 'table'}
                {#each tables.filter((table) => table.name.toLowerCase().includes(tableSearch.toLowerCase())) as table}
                  <button class:active={selectedTable === table.name} class="table-nav-item" aria-current={selectedTable === table.name ? 'page' : undefined} onclick={() => void selectTable(table.name)}>
                    <TableProperties size={17} /><span>{table.name}</span><small>{formatBytes(table.dataBytes + table.indexBytes)}</small>
                  </button>
                {/each}
              {:else}
                {#each objects.filter((object) => object.type === activeObjectType && object.name.toLowerCase().includes(tableSearch.toLowerCase())) as object}
                  <button class:active={selectedObject?.name === object.name} class="table-nav-item" aria-current={selectedObject?.name === object.name ? 'page' : undefined} onclick={() => selectedObject = object}>
                    {#if activeObjectType === 'view'}<Eye size={17} />{:else if activeObjectType === 'trigger'}<Zap size={17} />{:else if activeObjectType === 'role'}<ShieldCheck size={17} />{:else if activeObjectType === 'event'}<Clock size={17} />{:else if activeObjectType === 'procedure'}<Braces size={17} />{:else}<Code2 size={17} />{/if}<span>{object.name}</span>
                  </button>
                {/each}
              {/if}
              {#if sectionCount(activeObjectType) === 0}<p class="object-list-empty">No {objectSections.find((section) => section.type === activeObjectType)?.label.toLowerCase()} found.</p>{/if}
            </nav>
          </div>
          <div class="sidebar-footer">
            <button class="connection-status" onclick={() => void disconnect()} aria-label={`Disconnect from ${selectedConnection.name}`} title="Disconnect">
              <span class="connection-dot"></span><span>Connected</span><span class="sidebar-footer-host">{selectedConnection.host}:{selectedConnection.port}</span><Unplug size={15} />
            </button>
          </div>
        </aside>

        {#if activeObjectType === 'table'}
          <div class="table-main">
            <div class="table-toolbar"><span class="read-only-note"><ShieldCheck size={14} /> {selectedConnection.readOnly ? 'Read only · Production' : 'Read only preview'}</span><span class="toolbar-spacer"></span><label class="data-filter"><Search size={16} /><input placeholder="Filter rows…" aria-label="Filter rows" /></label><button class="toolbar-control"><SlidersHorizontal size={16} /> Filter</button><button class="icon-button" aria-label="Column visibility"><Columns3 size={18} /></button></div>
            <div class="data-grid-wrap">{#if databaseLoading}<p>Loading database…</p>{:else if error}<p>{error}</p>{:else if rowsPage}<table class="data-grid"><thead><tr><th class="actions-head">Actions</th><th class="row-index-head">#</th>{#each rowsPage.columns as column}<th><span class="column-name">{#if column.primaryKey}<KeyRound size={13} />{/if}{column.name}<span class="sort-arrows">↕</span></span><small>{column.type}{#if column.primaryKey}<em>PK</em>{/if}</small></th>{/each}</tr></thead><tbody>{#each rowsPage.rows as row, rowIndex}<tr><td class="row-actions"><button aria-label="Edit row"><Pencil size={16} /></button><button aria-label="Delete row"><Trash2 size={16} /></button></td><td class="row-index">{rowIndex + 1}</td>{#each row as value, columnIndex}<td>{#if columnIndex === 4}<span class:status-active={value === 'active'} class:status-pending={value === 'pending'} class:status-inactive={value === 'inactive'} class="status-pill"><span></span>{value}</span>{:else}<span class:muted-value={value === '—'}>{value ?? 'NULL'}</span>{/if}</td>{/each}</tr>{/each}</tbody></table>{:else if !databaseLoading}<p class="grid-empty">{#if tables.length === 0}No tables in this database.{:else}Select a table from the left menu.{/if}</p>{/if}</div>
            <footer class="grid-footer"><span>Showing <strong>{rowsPage?.rows.length ?? 0} of {tables.find((table) => table.name === selectedTable)?.rowsEstimate ?? 0} rows</strong></span><label class="page-size-label">Rows/page: <select aria-label="Rows per page"><option>50</option><option>100</option><option>200</option></select></label><span class="grid-summary">Rows: <strong>{rowsPage?.rows.length ?? 0}</strong> &nbsp; Columns: <strong>{rowsPage?.columns.length ?? 0}</strong></span><span class="pagination"><button disabled aria-label="First page">«</button><button disabled aria-label="Previous page">‹</button><span>Page 1 of 1</span><button disabled aria-label="Next page">›</button><button disabled aria-label="Last page">»</button></span></footer>
          </div>
        {:else}
          <section class="object-main" aria-label={`${objectSections.find((section) => section.type === activeObjectType)?.label ?? 'Database objects'} details`}>
            {#if selectedObject}
              <div class="object-detail-card"><span class="object-detail-icon"><Database size={22} /></span><p>{objectSections.find((section) => section.type === activeObjectType)?.label}</p><h1>{selectedObject.name}</h1><div class="object-detail-meta"><span>Type</span><strong>{selectedObject.type}</strong><span>Database</span><strong>{selectedConnection.database}</strong></div></div>
            {:else}
              <div class="object-empty-state"><Database size={28} /><h1>{objectSections.find((section) => section.type === activeObjectType)?.label}</h1><p>Select an object from the left menu to view its details.</p></div>
            {/if}
          </section>
        {/if}
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
                <span class:connected={connection.connected} class="preview-badge"><span></span>{connection.connected ? 'Connected' : 'Disconnected'}</span>
              </div>
            </button>
          {/each}
        </div>
      </section>
    {/if}
  </main>
</div>
