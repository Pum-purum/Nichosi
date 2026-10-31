import type { components } from './api/schema';

type Entry = components['schemas']['TableMetadata']['indexes'][number];

export function metadataLabels(rows: Entry[], preferred: string[]): string[] {
  const available = new Set(rows.reduce<string[]>((labels, row) => labels.concat(Object.keys(row)), []));
  return [...preferred.filter(label => available.has(label)), ...[...available].filter(label => !preferred.includes(label))];
}

/** Group composite keys without losing the server's column order or prefix semantics. */
export function groupMetadataKeys(rows: Entry[], foreign = false): Entry[] {
  const groups = new Map<string, Entry[]>();
  for (const row of rows) {
    const name = row.Name;
    const group = groups.get(name) ?? [];
    group.push(row);
    groups.set(name, group);
  }
  return [...groups].map(([name, entries]): Entry => {
    const ordered = [...entries].sort((a, b) => Number(a.Position) - Number(b.Position));
    const first = ordered[0];
    const columnName = (value: string) => '`' + value.replace(/`/g, '``') + '`';
    const columns = ordered.map(row => {
      const column = row.Column ? columnName(row.Column) : 'Expression (see CREATE TABLE)';
      const prefix = row['Prefix length'] && row['Prefix length'] !== 'NULL' ? `(${row['Prefix length']})` : '';
      return column + prefix + (row.Ordering === 'D' ? ' DESC' : '');
    }).join(', ');
    if (foreign) {
      const target = [first['Referenced database'], first['Referenced table']].filter(Boolean).map(columnName).join('.');
      return { Name: name, Columns: columns, References: `${target} (${ordered.map(row => columnName(row['Referenced column'])).join(', ')})`, 'On update': first['On update'], 'On delete': first['On delete'] };
    }
    return { Name: name, Columns: columns, Kind: first.Kind, Type: first.Type, 'Estimated cardinality': ordered[ordered.length - 1]['Estimated cardinality'], Comment: first.Comment };
  });
}
