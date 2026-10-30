import { describe, expect, it } from 'vitest';
import { compactDefinition, formatDefinition } from './sql-definition';

describe('SQL definition formatting', () => {
  it('separates event schedule, options and body into readable lines', () => {
    const source = "CREATE DEFINER=`root`@`localhost` EVENT `refresh` ON SCHEDULE EVERY 1 DAY STARTS '2026-10-28 11:30:33' DISABLE COMMENT 'Disabled demonstration event' DO UPDATE demo SET updated_at=CURRENT_TIMESTAMP WHERE id=1";
    const result = formatDefinition(source);
    expect(result.formatted).toBe(true);
    for (const clause of ['ON SCHEDULE', 'EVERY 1 DAY', "STARTS '2026-10-28 11:30:33'", 'DISABLE', "COMMENT 'Disabled demonstration event'", 'DO', 'UPDATE demo', 'SET', 'updated_at=CURRENT_TIMESTAMP', 'WHERE', 'id=1']) {
      expect(result.sql.split('\n').map((line) => line.trim())).toContain(clause);
    }
  });

  it('preserves strings, escaped quotes, quoted identifiers and comments verbatim', () => {
    const protectedText = ["'DO UPDATE; WHERE a = 1'", "'it''s BEGIN END'", "'escaped\\\' quote'", '`SELECT``FROM`', '/* SET WHERE; */', '-- DO UPDATE;'];
    const source = `CREATE VIEW v AS SELECT ${protectedText.slice(0, 4).join(', ')} ${protectedText[4]} FROM t ${protectedText[5]}\nWHERE id=1`;
    const result = formatDefinition(source, '').sql;
    for (const text of protectedText) expect(result).toContain(text);
    expect(result).toContain('-- DO UPDATE;\n  WHERE');
  });

  it('indents procedure bodies without splitting parameter types or expressions', () => {
    const result = formatDefinition('CREATE PROCEDURE p(a DECIMAL(12,2)) BEGIN UPDATE t SET value=ROUND(a,2); SELECT value FROM t; END').sql;
    expect(result).toContain('p(a DECIMAL(12,2))');
    expect(result).toContain('  BEGIN\n    UPDATE t\n      SET\n        value=ROUND(a,2);\n    SELECT\n      value\n    FROM\n      t;\n  END');
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
    expect(result).toContain("SELECT\n      ' WHERE x=1, '\n    FROM\n      t");
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
    expect(result).toContain('    SET\n      @end=2;');
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
    expect(result.sql).toContain('SELECT\n    "x\\"\n  FROM\n    t');
  });

  it('indents schedule details and the event body under their parent clauses', () => {
    expect(formatDefinition("CREATE EVENT e ON SCHEDULE EVERY 1 DAY STARTS '2026-10-28' DISABLE DO UPDATE demo SET a=1,b=2 WHERE id=1;").sql).toBe([
      'CREATE EVENT e',
      '  ON SCHEDULE',
      '    EVERY 1 DAY',
      "    STARTS '2026-10-28'",
      '  DISABLE',
      '  DO',
      '    UPDATE demo',
      '      SET',
      '        a=1,',
      '        b=2',
      '      WHERE',
      '        id=1;',
    ].join('\n'));
  });

  it('indents nested queries and restores the enclosing query indentation', () => {
    const source = 'CREATE VIEW v AS SELECT a, (SELECT MAX(b) FROM t2 WHERE id=t.id) AS latest FROM t WHERE a>0';
    expect(formatDefinition(source).sql).toBe([
      'CREATE VIEW v AS',
      '  SELECT',
      '    a,',
      '    (',
      '      SELECT',
      '        MAX(b)',
      '      FROM',
      '        t2',
      '      WHERE',
      '        id=t.id',
      '    ) AS latest',
      '  FROM',
      '    t',
      '  WHERE',
      '    a>0',
    ].join('\n'));
  });

  it('indents nested BEGIN blocks and keeps trigger timing in the declaration', () => {
    const source = 'CREATE TRIGGER t BEFORE UPDATE ON demo FOR EACH ROW BEGIN BEGIN SET NEW.a=1; END; SET NEW.b=2; END';
    expect(formatDefinition(source).sql).toBe([
      'CREATE TRIGGER t BEFORE UPDATE ON demo',
      '  FOR EACH ROW',
      '  BEGIN',
      '    BEGIN',
      '      SET',
      '        NEW.a=1;',
      '    END;',
      '    SET',
      '      NEW.b=2;',
      '  END',
    ].join('\n'));
  });

  it('keeps CASE expressions inside their enclosing BEGIN block', () => {
    const result = formatDefinition('CREATE PROCEDURE p() BEGIN SELECT CASE WHEN x=1 THEN 2 ELSE 3 END AS n FROM t; SELECT 4; END').sql;
    expect(result).toContain('      CASE\n        WHEN x=1 THEN 2\n        ELSE 3\n      END AS n\n    FROM\n      t;\n    SELECT\n      4;\n  END');
  });

  it('indents IF branches and leaves scalar IF functions intact', () => {
    const result = formatDefinition('CREATE PROCEDURE p() BEGIN IF (x=1) THEN SET x=2; ELSE SET x=3; END IF; SET @x=IF(1,2,3); SELECT 4; END').sql;
    expect(result).toContain('    IF (x=1) THEN\n      SET\n        x=2;\n    ELSE\n      SET\n        x=3;\n    END IF;');
    expect(result).toContain('    SET\n      @x=IF(1,2,3);\n    SELECT\n      4;\n  END');
  });

  it('does not close a BEGIN frame for unsupported qualified END clauses', () => {
    const result = formatDefinition('CREATE PROCEDURE p() BEGIN WHILE x<2 DO SET x=x+1; END WHILE; SELECT 4; END').sql;
    expect(result).toContain('    END WHILE;\n    SELECT\n      4;\n  END');
  });

  it('keeps formatting stable when applied repeatedly', () => {
    const first = formatDefinition('CREATE TRIGGER t BEFORE UPDATE ON demo FOR EACH ROW BEGIN SET NEW.a=1; SET NEW.b=2; END').sql;
    expect(formatDefinition(first).sql).toBe(first);
  });
});


describe('SQL clipboard compaction', () => {
  it('copies multiline DDL as a single line without changing string spaces', () => {
    const source = "CREATE EVENT e\n  COMMENT 'keep  two spaces'\n  DO\n    UPDATE demo\n      SET a=1\n      WHERE id=2;";
    expect(compactDefinition(source)).toBe("CREATE EVENT e COMMENT 'keep  two spaces' DO UPDATE demo SET a=1 WHERE id=2;");
  });

  it('removes ordinary comments so line comments cannot swallow subsequent SQL', () => {
    const source = 'SELECT 1 -- explanation\n + 2; # another comment\nSELECT/* multiline\n comment */3;';
    expect(compactDefinition(source)).toBe('SELECT 1 + 2; SELECT 3;');
  });

  it('recognizes MySQL line comments followed by control characters', () => {
    expect(compactDefinition('SELECT 1 --\u0001comment\n +2;')).toBe('SELECT 1 +2;');
  });

  it('preserves executable comments and optimizer hints while compacting their layout', () => {
    const source = 'SELECT /*+\n MAX_EXECUTION_TIME(1000)\n */ 1; /*!50003\n CREATE EVENT e DO SELECT 1;\n */ /*M!100100\n SET @x=1\n */';
    const result = compactDefinition(source);
    expect(result).not.toMatch(/[\r\n]/);
    expect(result).toContain('/*+ MAX_EXECUTION_TIME(1000)*/');
    expect(result).toContain('/*!50003 CREATE EVENT e DO SELECT 1;*/');
    expect(result).toContain('/*M!100100 SET @x=1*/');
  });

  it('preserves comment-looking text and escaped content inside quoted tokens', () => {
    const source = "SELECT\n 'a -- b # c /* d */', `a  b`, 'it''s a value', 'a\\nb';";
    expect(compactDefinition(source, '')).toBe(source.replace('SELECT\n ', 'SELECT '));
  });

  it('keeps literal newlines and ambiguous quoting unchanged rather than corrupting data', () => {
    expect(compactDefinition("SELECT 'line 1\nline 2';")).toBe("SELECT 'line 1\nline 2';");
    const source = String.raw`SELECT 'a\' FROM t`;
    expect(compactDefinition(source)).toBe(source);
  });
});
