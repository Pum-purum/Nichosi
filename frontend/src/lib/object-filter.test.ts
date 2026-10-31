import { describe, expect, it } from 'vitest';
import { matchesObjectFilter } from './object-filter';

describe('database object filtering', () => {
  it('ignores surrounding whitespace, case and compatibility Unicode differences', () => {
    expect(matchesObjectFilter('  ORDERS  ', 'customer_orders')).toBe(true);
    expect(matchesObjectFilter('заказы', 'ЗаказыКлиентов')).toBe(true);
    expect(matchesObjectFilter('ＣＵＳＴＯＭＥＲ', 'customer_orders')).toBe(true);
    expect(matchesObjectFilter(' \t\n ', 'anything')).toBe(true);
  });

  it('matches every word without requiring adjacent text', () => {
    expect(matchesObjectFilter('order item', 'order_line_items')).toBe(true);
    expect(matchesObjectFilter('order missing', 'order_items')).toBe(false);
  });

  it('supports account name and host in displayed or server-reported identities', () => {
    expect(matchesObjectFilter('root localhost', 'root@localhost', "'root'@'localhost'")).toBe(true);
    expect(matchesObjectFilter("'root'", 'root@localhost', "'root'@'localhost'")).toBe(true);
    expect(matchesObjectFilter('root remote', 'root@localhost')).toBe(false);
  });

  it('treats punctuation as literal text rather than a pattern', () => {
    expect(matchesObjectFilter('[a]', 'table[a]')).toBe(true);
    expect(matchesObjectFilter('*', 'orders')).toBe(false);
    expect(matchesObjectFilter('nomatch', 'orders')).toBe(false);
  });
});
