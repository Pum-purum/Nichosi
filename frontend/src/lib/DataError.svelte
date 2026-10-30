<script lang="ts">
  import { Unplug, RotateCw, ArrowLeft } from '@lucide/svelte';
  let { message, busy, reconnect, back }: { message: string; busy: boolean; reconnect: () => void; back: () => void } = $props();
</script>

<div class="data-error" role="alert" aria-busy={busy}>
  <div class="error-symbol"><Unplug size={28} strokeWidth={1.5} /></div>
  <h2>Database error</h2>
  <pre class="error-message">{message}</pre>
  <div class="error-actions">
    <button class="primary-button" disabled={busy} onclick={reconnect}><RotateCw size={15} class={busy ? 'retry-spinning' : ''} />{busy ? 'Reconnecting…' : 'Reconnect'}</button>
    <button class="secondary-button" onclick={back}><ArrowLeft size={15} />Connections</button>
  </div>
</div>

<style>
  .data-error { display: flex; min-height: 320px; height: 100%; box-sizing: border-box; flex-direction: column; align-items: center; justify-content: center; padding: 48px 24px; text-align: center; }
  .error-symbol { display: grid; place-items: center; width: 62px; height: 62px; margin-bottom: 22px; border: 1px solid var(--line); border-radius: 16px; color: var(--muted); background: var(--surface-raised); }
  h2 { margin: 0 0 12px; color: var(--text); font-size: 22px; font-weight: 600; }
  .error-message { width: min(100%, 720px); margin: 0; padding: 16px 18px; box-sizing: border-box; border: 1px solid var(--line); border-radius: 8px; background: var(--surface); color: var(--text); font: 13px/1.7 var(--mono); text-align: left; white-space: pre-wrap; overflow-wrap: anywhere; }
  .error-actions { display: flex; flex-wrap: wrap; justify-content: center; gap: 10px; margin-top: 26px; }
  .error-actions button { min-height: 38px; padding: 0 14px; font-size: 12px; }
  :global(.retry-spinning) { animation: reconnect-spin 1s linear infinite; }
  @keyframes reconnect-spin { to { transform: rotate(360deg); } }
  @media (prefers-reduced-motion: reduce) { :global(.retry-spinning) { animation: none; } }
</style>
