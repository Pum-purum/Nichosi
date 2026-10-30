import { describe, expect, it } from 'vitest';
import { highlightSQL } from './sql-highlight';

describe('SQL highlighting', () => {
  it('highlights keywords, strings, numbers and comments without changing whitespace', () => {
    const sql = "SELECT\n  'demo', 42 -- comment\nFROM t";
    const html = highlightSQL(sql);
    for (const kind of ['keyword', 'string', 'number', 'comment']) {
      expect(html).toContain(`class="hljs-${kind}"`);
    }
    const text = html.replace(/<[^>]+>/g, '').replace(/&#x27;/g, "'");
    expect(text).toBe(sql);
  });

  it('escapes HTML in database object definitions', () => {
    const html = highlightSQL("SELECT '<img src=x onerror=alert(1)><script>alert(1)</script>&';");
    expect(html).not.toContain('<img');
    expect(html).not.toContain('<script');
    expect(html).toContain('&lt;img');
    expect(html).toContain('&lt;script&gt;');
    expect(html).toContain('&amp;');
  });
});
