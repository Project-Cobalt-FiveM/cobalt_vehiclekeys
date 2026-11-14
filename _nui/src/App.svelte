<script lang="ts">
  import Keyfob from './Keyfob.svelte';
  import { setLocales } from './lib/locale.svelte';
  import { fetchNui, inGame, onMessage } from './lib/nui';
  import { toLocked } from './lib/types';
  import type { FobVehicle, KeyfobAction } from './lib/types';

  const shortcuts: Record<string, KeyfobAction> = { '1': 'lock', '2': 'unlock', '3': 'trunk', '4': 'alarm' };

  let vehicle = $state<FobVehicle | undefined>(
    inGame ? undefined : { label: 'Karin Sultan RS', plate: '84CBL291', locked: true },
  );
  let closeKey = '';
  let busy = $state(false);
  let presses = $state(0);

  $effect(() =>
    onMessage((message) => {
      if (message.action === 'open') {
        busy = false;
        closeKey = message.closeKey;
        setLocales(message.locales);
        vehicle = message.data;
        return;
      }

      vehicle = undefined;
    }),
  );

  function close() {
    vehicle = undefined;
    fetchNui('close');
  }

  async function act(action: KeyfobAction) {
    if (busy) return;

    presses += 1;
    busy = true;

    const locked = toLocked(await fetchNui('action', { action }));

    if (vehicle && locked !== undefined) vehicle.locked = locked;

    busy = false;
  }

  function onkeydown(event: KeyboardEvent) {
    if (!vehicle) return;

    const key = event.key.toLowerCase();

    if (key === 'escape' || key === closeKey) return close();

    const action = shortcuts[key];

    if (action) act(action);
  }
</script>

<svelte:window {onkeydown} />

{#if vehicle}
  <Keyfob {vehicle} {busy} {presses} onaction={act} />
{/if}
