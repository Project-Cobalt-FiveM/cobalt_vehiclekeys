import type { Locales } from './types';

let dict: Locales = $state.raw({});

export function t(key: string): string {
  return dict[key] ?? key;
}

export function setLocales(locales: Locales): void {
  dict = locales;
}

function flatten(tree: unknown, prefix = '', into: Locales = {}): Locales {
  if (typeof tree === 'string') {
    into[prefix] = tree;
    return into;
  }

  if (typeof tree !== 'object' || tree === null) return into;

  for (const [key, value] of Object.entries(tree)) {
    flatten(value, prefix === '' ? key : `${prefix}.${key}`, into);
  }

  return into;
}

async function loadDevLocales(): Promise<void> {
  const files = import.meta.glob<unknown>('../../../locales/en.json', { import: 'default' });
  const load = Object.values(files)[0];

  if (load) dict = flatten(await load());
}

if (import.meta.env.DEV) void loadDevLocales();
