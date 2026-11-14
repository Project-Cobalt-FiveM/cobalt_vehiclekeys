export type KeyfobAction = 'lock' | 'unlock' | 'trunk' | 'alarm';

export type FobVehicle = {
  label: string;
  plate: string;
  locked: boolean;
};

export type Locales = Record<string, string>;

export type Message = { action: 'open'; data: FobVehicle; closeKey: string; locales: Locales } | { action: 'close' };

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

export function toFobVehicle(value: unknown): FobVehicle | undefined {
  if (!isRecord(value) || typeof value.label !== 'string' || typeof value.plate !== 'string') return undefined;

  return { label: value.label, plate: value.plate, locked: value.locked === true };
}

export function toLocked(value: unknown): boolean | undefined {
  if (!isRecord(value) || typeof value.locked !== 'boolean') return undefined;

  return value.locked;
}

function toLocales(value: unknown): Locales {
  const locales: Locales = {};

  if (!isRecord(value)) return locales;

  for (const [key, text] of Object.entries(value)) {
    if (typeof text === 'string') locales[key] = text;
  }

  return locales;
}

export function toMessage(value: unknown): Message | undefined {
  if (!isRecord(value)) return undefined;

  if (value.action === 'close') return { action: 'close' };

  if (value.action === 'open') {
    const data = toFobVehicle(value.data);
    const closeKey = typeof value.closeKey === 'string' ? value.closeKey : '';

    return data && { action: 'open', data, closeKey, locales: toLocales(value.locales) };
  }

  return undefined;
}
