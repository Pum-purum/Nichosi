import { describe, expect, it } from 'vitest';
import type { components } from './api/schema';
import { recoveryConnection } from './connection-recovery';

type Connection = components['schemas']['Connection'];
const profile: Connection = {
  id: 'old-id', name: 'Local database', driver: 'mysql', host: 'localhost', port: 3306,
  user: 'app', database: 'demo', readonly: false, connected: false,
  databaseSizeBytes: null, lastConnectedAt: null,
};

describe('Connection recovery', () => {
  it('recovers a new ID after a server restart and uses the latest read-only setting', () => {
    const current = { ...profile, id: 'new-id', readonly: true };
    expect(recoveryConnection(profile, [current])).toBe(current);
  });

  it('refuses a different database, account or endpoint even if the ID is reused', () => {
    for (const change of [{ database: 'other' }, { user: 'other' }, { host: 'remote' }, { port: 3307 }, { name: 'Other profile' }, { driver: 'postgres' as const }]) {
      expect(recoveryConnection(profile, [{ ...profile, ...change }])).toBeNull();
    }
  });

  it('does not choose arbitrarily between duplicate profiles after IDs change', () => {
    expect(recoveryConnection(profile, [{ ...profile, id: 'a' }, { ...profile, id: 'b' }])).toBeNull();
    expect(recoveryConnection(profile, [{ ...profile, id: 'a' }, profile])).toBe(profile);
    expect(recoveryConnection(profile, [])).toBeNull();
  });
});
