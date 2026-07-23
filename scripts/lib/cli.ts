// Minimal --flag=value / --flag (boolean) argv parser. No CLI-framework
// dependency — this repo has none, and ingestion scripts only need a
// handful of flags each.
export type ParsedArgs = Map<string, string | true>;

export function parseArgs(argv: string[] = process.argv.slice(2)): ParsedArgs {
  const args: ParsedArgs = new Map();
  for (const token of argv) {
    if (!token.startsWith('--')) continue;
    const eqIndex = token.indexOf('=');
    if (eqIndex === -1) {
      args.set(token.slice(2), true);
    } else {
      args.set(token.slice(2, eqIndex), token.slice(eqIndex + 1));
    }
  }
  return args;
}

export function getStringArg(args: ParsedArgs, name: string, fallback?: string): string | undefined {
  const value = args.get(name);
  if (typeof value === 'string') return value;
  return fallback;
}

export function getIntArg(args: ParsedArgs, name: string, fallback?: number): number | undefined {
  const raw = getStringArg(args, name);
  if (raw === undefined) return fallback;
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

export function getBooleanFlag(args: ParsedArgs, name: string): boolean {
  return args.has(name) && args.get(name) !== 'false';
}
