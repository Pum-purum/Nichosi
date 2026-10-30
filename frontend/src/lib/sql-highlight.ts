import hljs from 'highlight.js/lib/core';
import sql from 'highlight.js/lib/languages/sql';

hljs.registerLanguage('sql', sql);

/** Returns escaped HTML produced only by the bundled SQL highlighter. */
export function highlightSQL(source: string): string {
  return hljs.highlight(source, { language: 'sql', ignoreIllegals: true }).value;
}
