import { describe, expect, it } from 'vitest';
import { formatDefinition } from './sql-definition';

describe('SQL definition formatting', () => {
  it('separates event schedule, options and body into readable lines', () => {
    const source = "CREATE DEFINER=`root`@`localhost` EVENT `refresh` ON SCHEDULE EVERY 1 DAY STARTS '2026-10-28 11:30:33' DISABLE COMMENT 'Disabled demonstration event' DO UPDATE demo SET updated_at=CURRENT_TIMESTAMP WHERE id=1";
    const result = formatDefinition(source);
    expect(result.formatted).toBe(true);
    for (const clause of ['ON SCHEDULE', 'EVERY 1 DAY', "STARTS '2026-10-28 11:30:33'", 'DISABLE', "COMMENT 'Disabled demonstration event'", 'DO', 'UPDATE demo', 'SET updated_at=CURRENT_TIMESTAMP', 'WHERE id=1']) {
      expect(result.sql.split('\n')).toContain(clause);
    }
  });

  it('preserves strings, escaped quotes, quoted identifiers and comments verbatim', () => {
    const protectedText = ["'DO UPDATE; WHERE a = 1'", "'it''s BEGIN END'", "'escaped\\\' quote'", '`SELECT``FROM`', '/* SET WHERE; */', '-- DO UPDATE;'];
    const source = `CREATE VIEW v AS SELECT ${protectedText.slice(0, 4).join(', ')} ${protectedText[4]} FROM t ${protectedText[5]}\nWHERE id=1`;
    const result = formatDefinition(source, '').sql;
    for (const text of protectedText) expect(result).toContain(text);
    expect(result).toContain('-- DO UPDATE;\nWHERE');
  });

  it('indents procedure bodies without splitting parameter types or expressions', () => {
    const result = formatDefinition('CREATE PROCEDURE p(a DECIMAL(12,2)) BEGIN UPDATE t SET value=ROUND(a,2); SELECT value FROM t; END').sql;
    expect(result).toContain('p(a DECIMAL(12,2))');
    expect(result).toContain('BEGIN\n  UPDATE t\n  SET value=ROUND(a,2);\n  SELECT value\n  FROM t;\nEND');
  });

  it('leaves incomplete quoted text and comments unchanged', () => {
    for (const source of ["SELECT 'unfinished", 'SELECT `unfinished', 'SELECT /* unfinished']) {
      expect(formatDefinition(source)).toEqual({ sql: source, formatted: false });
    }
  });

  it('respects SQL mode when locating string boundaries', () => {
    const source = String.raw`CREATE EVENT e COMMENT 'a\' DO SELECT ' WHERE x=1, ' FROM t`;
    expect(formatDefinition(source)).toEqual({ sql: source, formatted: false });
    const result = formatDefinition(source, 'NO_BACKSLASH_ESCAPES').sql;
    expect(result).toContain(String.raw`COMMENT 'a\'`);
    expect(result).toContain("SELECT ' WHERE x=1, '\nFROM t");
  });

  it('does not treat backslashes as escapes inside backtick identifiers', () => {
    const source = 'CREATE VIEW `a\\` AS SELECT `x\\`, `WHERE` FROM t';
    expect(formatDefinition(source).formatted).toBe(true);
    expect(formatDefinition(source).sql).toContain('`a\\`');
  });

  it('keeps user and system variables opaque even when named after clauses', () => {
    const source = 'CREATE DEFINER=root@every PROCEDURE p() BEGIN SET @comment=1; SET @end=2; SELECT @comment, @@session.sql_mode, @`BEGIN`; END';
    const result = formatDefinition(source).sql;
    for (const token of ['root@every', '@comment', '@end', '@@session.sql_mode', '@`BEGIN`']) expect(result).toContain(token);
    expect(result).toContain('  SET @end=2;');
  });

  it('preserves Unicode and digit-prefixed identifiers as complete tokens', () => {
    const result = formatDefinition('CREATE VIEW v AS SELECT имяFROM, 1comment, @имяEND FROM t').sql;
    for (const token of ['имяFROM', '1comment', '@имяEND']) expect(result).toContain(token);
  });

  it('treats double quotes as identifiers in ANSI_QUOTES mode', () => {
    const source = 'CREATE VIEW "a\\" AS SELECT "x\\" FROM t';
    const result = formatDefinition(source, 'ANSI_QUOTES');
    expect(result.formatted).toBe(true);
    expect(result.sql).toContain('"a\\"');
    expect(result.sql).toContain('SELECT "x\\"\nFROM t');
  });

  it('keeps formatting stable when applied repeatedly', () => {
    const first = formatDefinition('CREATE TRIGGER t BEFORE UPDATE ON demo FOR EACH ROW BEGIN SET NEW.a=1; SET NEW.b=2; END').sql;
    expect(formatDefinition(first).sql).toBe(first);
  });
});
