type Token = { text: string; word?: string; whitespace?: boolean; lineComment?: boolean };

// Only whitespace between tokens is changed. Quoted text and comments stay opaque.
function tokenize(sql: string, noBackslashEscapes: boolean | undefined, ansiQuotes: boolean): Token[] | null {
  const tokens: Token[] = [];
  for (let i = 0; i < sql.length;) {
    const start = i;
    const char = sql[i];
    if (/\s/.test(char)) {
      while (i < sql.length && /\s/.test(sql[i])) i++;
      tokens.push({ text: sql.slice(start, i), whitespace: true });
    } else if (char === "'" || char === '"' || char === '`') {
      i++;
      let closed = false;
      while (i < sql.length) {
        if (sql[i] === '\\' && char !== '`' && !(char === '"' && ansiQuotes)) {
          // Without SQL mode, a backslash makes string boundaries ambiguous.
          if (noBackslashEscapes === undefined) return null;
          if (!noBackslashEscapes) { i += 2; continue; }
        }
        if (sql[i++] === char) {
          if (sql[i] === char) { i++; continue; }
          closed = true;
          break;
        }
      }
      if (!closed) return null;
      tokens.push({ text: sql.slice(start, i) });
    } else if (sql.startsWith('/*', i)) {
      const end = sql.indexOf('*/', i + 2);
      if (end < 0) return null;
      i = end + 2;
      tokens.push({ text: sql.slice(start, i) });
    } else if (char === '#' || (sql.startsWith('--', i) && /\s/.test(sql[i + 2] ?? ''))) {
      while (i < sql.length && sql[i] !== '\n' && sql[i] !== '\r') i++;
      tokens.push({ text: sql.slice(start, i), lineComment: true });
    } else if (char === '@') {
      // User/system variables and unquoted DEFINER hosts are not SQL clauses.
      i++;
      while (i < sql.length && /[\w$@.\u0080-\uFFFF]/.test(sql[i])) i++;
      tokens.push({ text: sql.slice(start, i) });
    } else if (/[\w$\u0080-\uFFFF]/.test(char)) {
      while (i < sql.length && /[\w$\u0080-\uFFFF]/.test(sql[i])) i++;
      const text = sql.slice(start, i);
      tokens.push({ text, word: text.toUpperCase() });
    } else {
      tokens.push({ text: sql[i++] });
    }
  }
  return tokens;
}

const clauses = [
  'ON SCHEDULE', 'ON COMPLETION', 'FOR EACH ROW', 'SQL SECURITY',
  'NOT DETERMINISTIC', 'DETERMINISTIC', 'READS SQL DATA', 'MODIFIES SQL DATA',
  'CONTAINS SQL', 'NO SQL', 'GROUP BY', 'ORDER BY', 'INSERT INTO', 'DELETE FROM',
  'LEFT JOIN', 'RIGHT JOIN', 'INNER JOIN', 'CROSS JOIN', 'UNION ALL',
  'EVERY', 'STARTS', 'ENDS', 'ENABLE', 'DISABLE', 'COMMENT', 'DO',
  'RETURNS', 'RETURN', 'BEGIN', 'END', 'SELECT', 'FROM', 'WHERE',
  'HAVING', 'LIMIT', 'OFFSET', 'UNION', 'JOIN', 'SET', 'UPDATE', 'VALUES',
].map((clause) => clause.split(' '));

/** A conservative MySQL DDL layout; never rewrites literals, identifiers or keywords. */
export function formatDefinition(sql: string, sqlMode?: string): { sql: string; formatted: boolean } {
  const modes = sqlMode?.toUpperCase().split(',').map((mode) => mode.trim());
  const noBackslashEscapes = modes?.includes('NO_BACKSLASH_ESCAPES');
  const tokens = tokenize(sql, noBackslashEscapes, modes?.includes('ANSI_QUOTES') ?? false);
  if (!tokens) return { sql, formatted: false };
  let output = '';
  let pendingSpace = false;
  let lineStart = true;
  let parentheses = 0;
  let blocks = 0;
  const newline = () => {
    output = output.replace(/\s+$/, '');
    if (output) output += '\n';
    lineStart = true;
    pendingSpace = false;
  };
  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i];
    if (token.whitespace) { pendingSpace = true; continue; }
    let phraseEnd = i;
    let clause = false;
    if (parentheses === 0 && token.word) {
      for (const words of clauses) {
        let index = i;
        let matched = true;
        for (let j = 0; j < words.length; j++) {
          if (j) {
            index++;
            while (tokens[index]?.whitespace) index++;
          }
          if (tokens[index]?.word !== words[j]) { matched = false; break; }
        }
        if (matched) { phraseEnd = index; clause = true; break; }
      }
    }
    let next = phraseEnd + 1;
    while (tokens[next]?.whitespace) next++;
    const closesBegin = token.word === 'END' && !['IF', 'LOOP', 'WHILE', 'REPEAT', 'CASE'].includes(tokens[next]?.word ?? '');
    if (parentheses === 0 && closesBegin) blocks = Math.max(0, blocks - 1);
    if (clause) newline();
    if (lineStart) output += '  '.repeat(blocks);
    else if (pendingSpace) output += ' ';
    output += tokens.slice(i, phraseEnd + 1).map((part) => part.whitespace ? ' ' : part.text).join('');
    lineStart = false;
    pendingSpace = false;
    if (token.text === '(') parentheses++;
    if (token.text === ')') parentheses = Math.max(0, parentheses - 1);
    if (parentheses === 0 && token.word === 'BEGIN') { blocks++; newline(); }
    if (token.lineComment || (parentheses === 0 && (token.text === ';' || token.text === ','))) newline();
    i = phraseEnd;
  }
  return { sql: output.replace(/\s+$/, ''), formatted: true };
}
