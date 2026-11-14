import { toMessage } from './types';
import type { Message } from './types';

declare global {
  interface Window {
    GetParentResourceName?: () => string;
  }
}

export const inGame = typeof window.GetParentResourceName === 'function';

export async function fetchNui(name: string, data: unknown = {}): Promise<unknown> {
  if (!inGame) return null;

  try {
    const response = await fetch(`https://${window.GetParentResourceName!()}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data),
    });

    return await response.json();
  } catch {
    return null;
  }
}

export function onMessage(handler: (message: Message) => void): () => void {
  const listener = (event: MessageEvent<unknown>) => {
    const message = toMessage(event.data);
    if (message) handler(message);
  };

  window.addEventListener('message', listener);
  return () => window.removeEventListener('message', listener);
}
