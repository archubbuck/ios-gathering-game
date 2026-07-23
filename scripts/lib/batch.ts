export function chunkArray<T>(items: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < items.length; i += size) {
    chunks.push(items.slice(i, i + size));
  }
  return chunks;
}

// A single multi-row `INSERT ... ON CONFLICT DO UPDATE` cannot affect the
// same target row twice — Postgres raises "ON CONFLICT DO UPDATE command
// cannot affect row a second time" if two input rows in the same batch
// share a conflict key. Every ingestion script upserts `names` keyed by
// (normalized_name, gender), and source data can plausibly contain two
// rows that collide on that key within one chunk (e.g. multiple Wikidata
// QIDs normalizing to the same name+gender). Call this before building a
// batch's unnest() arrays; last item for a given key wins.
export function dedupeByKey<T>(items: T[], keyFn: (item: T) => string): T[] {
  const byKey = new Map<string, T>();
  for (const item of items) {
    byKey.set(keyFn(item), item);
  }
  return [...byKey.values()];
}
