<script lang="ts">
  import { cellValue } from './cell-value';
  let { value, sqlType }: { value: unknown; sqlType: string } = $props();
  const cell = $derived(cellValue(value, sqlType));
</script>

<span class="cell-value cell-{cell.kind}" class:cell-numeric={cell.numeric} title={cell.label} aria-label={cell.label}>
  {#if cell.kind === 'enum'}
    <span class="value-badge">{cell.text}</span>
  {:else if cell.kind === 'set'}
    <span class="value-badges">
      {#each cell.text.split(',').map((item) => item.trim()).filter(Boolean) as item}
        <span class="value-badge">{item}</span>
      {/each}
    </span>
  {:else}
    <span class="cell-content">{cell.text}</span>
  {/if}
</span>
