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
  'AS', 'AT', 'IF', 'THEN', 'ELSEIF', 'ELSE', 'CASE', 'WHEN',
].map((clause) => clause.split(' '));

const statementClauses = new Set(['FROM', 'WHERE', 'GROUP BY', 'ORDER BY', 'HAVING', 'LIMIT', 'OFFSET', 'JOIN', 'LEFT JOIN', 'RIGHT JOIN', 'INNER JOIN', 'CROSS JOIN', 'SET', 'VALUES']);
const options = new Set(['ON SCHEDULE', 'ON COMPLETION', 'FOR EACH ROW', 'ENABLE', 'DISABLE', 'COMMENT', 'RETURNS', 'DETERMINISTIC', 'NOT DETERMINISTIC', 'SQL SECURITY', 'READS SQL DATA', 'MODIFIES SQL DATA', 'CONTAINS SQL', 'NO SQL']);

/** A conservative MySQL DDL layout; never rewrites literals, identifiers or keywords. */
export function formatDefinition(sql: string, sqlMode?: string): { sql: string; formatted: boolean } {
  const modes = sqlMode?.toUpperCase().split(',').map((mode) => mode.trim());
  const tokens = tokenize(sql, modes?.includes('NO_BACKSLASH_ESCAPES'), modes?.includes('ANSI_QUOTES') ?? false);
  if (!tokens) return { sql, formatted: false };
  const first = tokens.find((token) => !token.whitespace);
  const kind = first?.word === 'CREATE'
    ? tokens.find((token) => ['EVENT', 'TRIGGER', 'PROCEDURE', 'FUNCTION', 'VIEW', 'ROLE'].includes(token.word ?? ''))?.word
    : undefined;
  let output = '';
  let pendingSpace = false;
  let lineStart = true;
  let indent = 0;
  let bodyIndent = kind ? 1 : 0;
  let statementIndent = bodyIndent;
  let contentIndent = bodyIndent;
  let statement = '';
  let header = !!kind;
  let parentheses = 0;
  const blocks: { kind: string; indent: number; body?: number; expression?: boolean }[] = [];
  const subqueries: { depth: number; indent: number; body: number; statement: number; content: number; kind: string }[] = [];
  const nextToken = (index: number) => {
    while (tokens[index]?.whitespace) index++;
    return index;
  };
  const newline = (level = indent) => {
    output = output.replace(/\s+$/, '');
    if (output) output += '\n';
    lineStart = true;
    pendingSpace = false;
    indent = level;
  };
  const write = (text: string) => {
    if (lineStart) output += '  '.repeat(Math.max(0, indent));
    else if (pendingSpace) output += ' ';
    output += text;
    lineStart = false;
    pendingSpace = false;
  };
  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i];
    if (token.whitespace) { pendingSpace = true; continue; }
    const activeDepth = subqueries.length ? subqueries[subqueries.length - 1].depth : 0;
    const atQueryLevel = parentheses === activeDepth;
    let phraseEnd = i;
    let clause = '';
    if (atQueryLevel && token.word) {
      for (const words of clauses) {
        let index = i;
        let matched = true;
        for (let j = 0; j < words.length; j++) {
          if (j) index = nextToken(index + 1);
          if (tokens[index]?.word !== words[j]) { matched = false; break; }
        }
        if (matched) { phraseEnd = index; clause = words.join(' '); break; }
      }
    }
    // Timing and UPDATE/INSERT/DELETE are part of a trigger declaration.
    if (header && kind === 'TRIGGER' && clause !== 'FOR EACH ROW') clause = '';
    let afterLine: number | undefined;
    if (clause === 'AS' && header && kind === 'VIEW') {
      header = false;
      afterLine = bodyIndent;
    } else if (header && options.has(clause)) {
      newline(1);
      if (clause === 'ON SCHEDULE') afterLine = 2;
      if (clause === 'FOR EACH ROW') { header = false; afterLine = bodyIndent; }
    } else if (header && kind === 'EVENT' && ['EVERY', 'STARTS', 'ENDS', 'AT'].includes(clause)) {
      newline(2);
    } else if (clause === 'DO' && kind === 'EVENT' && header) {
      newline(1);
      header = false;
      bodyIndent = 2;
      statementIndent = bodyIndent;
      afterLine = bodyIndent;
    } else if (clause === 'BEGIN') {
      header = false;
      newline(bodyIndent);
      statement = '';
      blocks.push({ kind: 'BEGIN', indent: bodyIndent });
      bodyIndent++;
      statementIndent = bodyIndent;
      afterLine = bodyIndent;
    } else if (clause === 'END') {
      const next = nextToken(phraseEnd + 1);
      const suffix = tokens[next]?.word ?? '';
      const qualified = ['IF', 'CASE', 'LOOP', 'WHILE', 'REPEAT'].includes(suffix);
      const top = blocks[blocks.length - 1];
      const matches = qualified ? top?.kind === suffix : top?.kind === 'BEGIN' || top?.kind === 'CASE';
      if (matches) {
        const block = blocks.pop()!;
        bodyIndent = block.body ?? block.indent;
        statementIndent = bodyIndent;
        newline(block.indent);
      } else newline(bodyIndent);
      if (qualified) phraseEnd = next;
    } else if (clause === 'CASE') {
      const expression = !!statement;
      const level = expression ? indent : bodyIndent;
      newline(level);
      blocks.push({ kind: 'CASE', indent: level, body: bodyIndent, expression });
      afterLine = level + 1;
    } else if (clause === 'WHEN' && blocks[blocks.length - 1]?.kind === 'CASE') {
      newline(blocks[blocks.length - 1].indent + 1);
    } else if (clause === 'THEN' && blocks[blocks.length - 1]?.kind === 'CASE') {
      const block = blocks[blocks.length - 1];
      if (!block.expression) { bodyIndent = block.indent + 2; statement = ''; afterLine = bodyIndent; }
    } else if (clause === 'ELSE' && blocks[blocks.length - 1]?.kind === 'CASE') {
      const block = blocks[blocks.length - 1];
      newline(block.indent + 1);
      if (!block.expression) { bodyIndent = block.indent + 2; statement = ''; afterLine = bodyIndent; }
    } else if (clause === 'IF' && !header && !statement) {
      newline(bodyIndent);
      blocks.push({ kind: 'IF', indent: bodyIndent });
    } else if (clause === 'THEN' && blocks[blocks.length - 1]?.kind === 'IF') {
      bodyIndent = blocks[blocks.length - 1].indent + 1;
      statement = '';
      afterLine = bodyIndent;
    } else if (['ELSE', 'ELSEIF'].includes(clause) && blocks[blocks.length - 1]?.kind === 'IF') {
      bodyIndent = blocks[blocks.length - 1].indent;
      newline(bodyIndent);
      if (clause === 'ELSE') { bodyIndent++; afterLine = bodyIndent; }
    } else if (['SELECT', 'INSERT INTO', 'DELETE FROM', 'UPDATE', 'RETURN'].includes(clause)) {
      header = false;
      statement = clause;
      statementIndent = bodyIndent;
      newline(statementIndent);
      contentIndent = statementIndent + 1;
      if (clause === 'SELECT') afterLine = contentIndent;
    } else if (statementClauses.has(clause) && !header) {
      if (clause === 'SET' && !statement) { statement = 'SET'; statementIndent = bodyIndent; }
      const level = statement === 'UPDATE' && clause !== 'UPDATE' ? statementIndent + 1 : statementIndent;
      newline(level);
      contentIndent = level + 1;
      afterLine = contentIndent;
    } else if (['UNION', 'UNION ALL'].includes(clause) && !header) {
      newline(statementIndent);
      afterLine = statementIndent;
    }
    if (token.text === ')' && subqueries[subqueries.length - 1]?.depth === parentheses) {
      const parent = subqueries.pop()!;
      newline(parent.indent);
      bodyIndent = parent.body;
      statementIndent = parent.statement;
      contentIndent = parent.content;
      statement = parent.kind;
    }
    write(tokens.slice(i, phraseEnd + 1).map((part) => part.whitespace ? ' ' : part.text).join(''));
    if (afterLine !== undefined) newline(afterLine);
    if (token.text === '(') {
      parentheses++;
      if (tokens[nextToken(i + 1)]?.word === 'SELECT') {
        subqueries.push({ depth: parentheses, indent, body: bodyIndent, statement: statementIndent, content: contentIndent, kind: statement });
        bodyIndent = indent + 1;
        newline(bodyIndent);
      }
    }
    if (token.text === ')') parentheses = Math.max(0, parentheses - 1);
    if (token.lineComment) newline();
    if (atQueryLevel && token.text === ',') newline(contentIndent);
    if (atQueryLevel && token.text === ';') { statement = ''; newline(bodyIndent); }
    i = phraseEnd;
  }
  return { sql: output.replace(/\s+$/, ''), formatted: true };
}
