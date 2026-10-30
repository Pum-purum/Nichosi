import type { components } from './api/schema';
type Connection = components['schemas']['Connection'];

/** Resolve a refreshed profile without reconnecting to a different database. */
export function recoveryConnection(previous: Connection, current: Connection[]): Connection | null {
  const matches = current.filter((item) => item.name === previous.name && item.driver === previous.driver
    && item.host === previous.host && item.port === previous.port && item.user === previous.user
    && item.database === previous.database);
  return matches.find((item) => item.id === previous.id) ?? (matches.length === 1 ? matches[0] : null);
}
