<script lang="ts">
  import { LockKeyhole, LockKeyholeOpen, Server, UserRound } from '@lucide/svelte';
  import type { components } from './api/schema';

  let { user }: { user: components['schemas']['DatabaseObject'] } = $props();
  const lock = $derived(user.details?.['Locked']);
  const lockLabel = $derived(lock === 'Y' ? 'Locked' : lock === 'N' ? 'Not locked' : 'Unknown');
  const category = $derived(user.details?.['Account category']);
  const categoryLabel = $derived(category === 'internal' ? 'Built-in' : category === 'default-admin' ? 'Default admin' : 'Other account');
</script>

<section class="user-details" aria-label="User account details">
  <div class="user-summary">
    <div class="user-summary-card">
      {#if lock === 'Y'}<LockKeyhole size={18} />{:else if lock === 'N'}<LockKeyholeOpen size={18} />{:else}<UserRound size={18} />{/if}
      <span>Account lock</span><strong>{lockLabel}</strong>
    </div>
    <div class="user-summary-card"><UserRound size={18} /><span>Account category</span><strong>{categoryLabel}</strong></div>
    <div class="user-summary-card"><Server size={18} /><span>Scope</span><strong>Server-wide</strong></div>
  </div>
  <dl>
    <div><dt>Account name</dt><dd>{user.details?.['Account name'] ?? 'Unavailable'}</dd></div>
    <div><dt>Host pattern</dt><dd>{user.details?.['Host'] ?? 'Unavailable'}</dd></div>
  </dl>
  <div class="user-explanation">
    {#if lock === 'Y'}
      <p>This account is locked for client connections.</p>
    {:else if lock === 'N'}
      <p>This account is not locked. Authentication and privilege checks still apply.</p>
    {:else}
      <p>The account lock state is unavailable to this connection.</p>
    {/if}
    <p>The host is part of the account identity. Accounts with the same name and different hosts are separate accounts.</p>
    {#if category === 'internal'}
      <p>Recognized internal MySQL account. This label does not indicate SYSTEM_USER privileges.</p>
    {:else if category === 'default-admin'}
      <p>The standard initial administrator identity. Current privileges and creation history are not verified.</p>
    {:else}
      <p>Creation history is unavailable; this account may have been created by an administrator, installer or service.</p>
    {/if}
  </div>
  <p class="user-privacy">Passwords and authentication data are never displayed.</p>
</section>

<style>
  .user-details { margin-top: 24px; }
  .user-summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 12px; }
  .user-summary-card { display: grid; grid-template-columns: 20px 1fr; align-items: center; gap: 8px 10px; padding: 16px; border: 1px solid var(--line); border-radius: 7px; background: var(--surface); }
  .user-summary-card :global(svg) { color: var(--muted); }
  .user-summary-card span { color: var(--muted); font-size: 12px; }
  .user-summary-card strong { grid-column: 2; color: var(--text); font-size: 15px; font-weight: 500; }
  dl { display: grid; gap: 0; margin: 24px 0 0; }
  dl > div { display: grid; grid-template-columns: minmax(100px, 140px) minmax(0, 1fr); gap: 16px; padding: 13px 0; border-bottom: 1px solid var(--line); font-size: 13px; }
  dt { color: var(--muted); }
  dd { margin: 0; color: var(--text); font-family: var(--mono); overflow-wrap: anywhere; white-space: pre-wrap; }
  .user-explanation { margin-top: 20px; color: var(--muted); font-size: 13px; line-height: 1.6; }
  .user-explanation p { margin: 8px 0; }
  .user-privacy { margin: 20px 0 0; padding-top: 16px; border-top: 1px solid var(--line); color: var(--muted); font-size: 12px; }
</style>
