import { describe, expect, it } from 'vitest';
import { groupMetadataKeys, metadataLabels } from './table-metadata';

describe('table metadata presentation', () => {
  it('shows column properties in reading order regardless of JSON property order', () => {
    expect(metadataLabels([{ Nullable: 'YES', Default: 'NULL', Position: '1', Type: 'int', Name: 'id' }], ['Name', 'Type', 'Default', 'Nullable'])).toEqual(['Name', 'Type', 'Default', 'Nullable', 'Position']);
  });

  it('combines composite indexes in ordinal order, retaining prefixes and descending order', () => {
    const result = groupMetadataKeys([
      { Name: 'by_name', Position: '2', Column: 'last', Ordering: 'D', 'Prefix length': '12', Kind: 'Unique' },
      { Name: 'PRIMARY', Position: '1', Column: 'id', Kind: 'Primary key' },
      { Name: 'by_name', Position: '1', Column: 'first', 'Prefix length': 'NULL', Kind: 'Unique' },
    ]);
    expect(result).toHaveLength(2);
    expect(result[0]).toMatchObject({ Name: 'by_name', Columns: '`first`, `last`(12) DESC', Kind: 'Unique' });
    expect(result[1]).toMatchObject({ Name: 'PRIMARY', Columns: '`id`' });
  });

  it('distinguishes a column named NULL from an expression index without a column name', () => {
    expect(groupMetadataKeys([{ Name: 'literal', Position: '1', Column: 'NULL' }])[0].Columns).toBe('`NULL`');
    expect(groupMetadataKeys([{ Name: 'expression', Position: '1', Column: '' }])[0].Columns).toBe('Expression (see CREATE TABLE)');
  });

  it('keeps composite foreign key source and target columns aligned', () => {
    const common = { Name: 'fk_team', 'Referenced database': 'app', 'Referenced table': 'team', 'On delete': 'CASCADE', 'On update': 'RESTRICT' };
    const result = groupMetadataKeys([
      { ...common, Position: '2', Column: 'team_id', 'Referenced column': 'id' },
      { ...common, Position: '1', Column: 'tenant_id', 'Referenced column': 'tenant' },
    ], true);
    expect(result).toEqual([{ Name: 'fk_team', Columns: '`tenant_id`, `team_id`', References: '`app`.`team` (`tenant`, `id`)', 'On delete': 'CASCADE', 'On update': 'RESTRICT' }]);
  });
});
