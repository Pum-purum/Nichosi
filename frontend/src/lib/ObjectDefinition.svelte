<script lang="ts">
  import { Copy, Check } from '@lucide/svelte';
  import { formatDefinition } from './sql-definition';

  let { definition, name, sqlMode }: { definition: string; name: string; sqlMode?: string } = $props();
  let showOriginal = $state(false);
  const formatted = $derived(formatDefinition(definition, sqlMode));
  const displayedSQL = $derived(showOriginal ? definition : formatted.sql);
  let copied = $state(false);
  let copyError = $state('');
  let copyAttempt = 0;
  $effect(() => { displayedSQL; copied = false; copyError = ''; copyAttempt++; });

  async function copyDefinition() {
    const attempt = ++copyAttempt;
    try {
      await navigator.clipboard.writeText(displayedSQL);
      if (attempt === copyAttempt) { copied = true; copyError = ''; }
    } catch {
      if (attempt === copyAttempt) copyError = 'Could not copy SQL. Select the code and copy it manually.';
    }
  }
</script>

<div class="definition-panel">
  <div class="definition-toolbar">
    <h2>SQL definition</h2>
    <span>Read-only</span>
    <label class="definition-original"><input type="checkbox" bind:checked={showOriginal} /> Original SQL</label>
    <button onclick={copyDefinition} aria-label={`Copy SQL definition of ${name}`}>
      {#if copied}<Check size={14} />{:else}<Copy size={14} />{/if}
      {copied ? 'Copied' : 'Copy SQL'}
    </button>
  </div>
  <div class="definition-code">
    <div class="definition-lines" aria-hidden="true">{displayedSQL.split('\n').map((_, index) => index + 1).join('\n')}</div>
    <!-- svelte-ignore a11y_no_noninteractive_tabindex (Scrollable SQL needs keyboard access.) -->
    <pre role="region" tabindex="0" aria-label={`SQL definition of ${name}`}><code>{displayedSQL}</code></pre>
  </div>
  {#if !showOriginal && !formatted.formatted}
    <p class="definition-feedback">Formatting is unavailable for this syntax. Showing the original SQL.</p>
  {/if}
  <p class="definition-feedback" role="status">{copyError || (copied ? 'SQL copied to clipboard.' : '')}</p>
</div>

<style>
  .definition-panel { margin-top: 28px; min-width: 0; }
  .definition-toolbar { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; padding: 10px 12px; background: #252829; border: 1px solid #414546; border-radius: 6px 6px 0 0; }
  .definition-toolbar h2 { margin: 0; font-size: 14px; }
  .definition-toolbar > span { color: #a8aeaa; font-size: 11px; }
  .definition-original { margin-left: auto; display: inline-flex; align-items: center; gap: 6px; font-size: 12px; color: #c6cdc8; }
  button { display: inline-flex; align-items: center; gap: 6px; padding: 6px 10px; border: 1px solid #555d58; border-radius: 4px; background: #303633; color: #e5e7e4; cursor: pointer; }
  button:focus-visible, pre:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
  .definition-code { display: flex; overflow: auto; background: #202324; border: 1px solid #414546; border-top: 0; border-radius: 0 0 6px 6px; }
  .definition-lines, pre { margin: 0; padding: 16px; font: 13px/1.7 ui-monospace, monospace; white-space: pre; tab-size: 4; }
  .definition-lines { flex: none; color: #8e9892; text-align: right; border-right: 1px solid #373d39; user-select: none; }
  pre { flex: 1; min-width: 0; overflow: auto; color: #e5e7e4; }
  code { font: inherit; }
  .definition-feedback { margin: 8px 0 0; color: #c6cdc8; font-size: 12px; }
  .definition-feedback:empty { display: none; }
</style>
