/** Match all search words literally, ignoring case and surrounding whitespace. */
export function matchesObjectFilter(query: string, ...names: string[]): boolean {
  const normalize = (text: string) => text.normalize('NFKC').toLowerCase();
  const terms = normalize(query).trim().split(/\s+/).filter(Boolean);
  const candidates = names.map(normalize);
  return terms.every(term => candidates.some(name => name.includes(term)));
}
