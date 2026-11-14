<script lang="ts">
  import Lock from 'phosphor-svelte/lib/Lock';
  import LockOpen from 'phosphor-svelte/lib/LockOpen';
  import fobImage from './assets/cobalt-keyfob.webp';
  import { t } from './lib/locale.svelte';
  import type { FobVehicle, KeyfobAction } from './lib/types';

  type Hotspot = { action: KeyfobAction; labelKey: string; top: number; height: number };

  const BUTTON_LEFT = 19;
  const BUTTON_WIDTH = 62.6;

  const hotspots: readonly Hotspot[] = [
    { action: 'lock', labelKey: 'ui.lock', top: 19.8, height: 12.6 },
    { action: 'unlock', labelKey: 'ui.unlock', top: 34, height: 12.2 },
    { action: 'trunk', labelKey: 'ui.trunk', top: 48, height: 12 },
    { action: 'alarm', labelKey: 'ui.alarm', top: 61.8, height: 12.4 },
  ];

  type Props = {
    vehicle: FobVehicle;
    busy: boolean;
    presses: number;
    onaction: (action: KeyfobAction) => void;
  };

  let { vehicle, busy, presses, onaction }: Props = $props();

  const StatusIcon = $derived(vehicle.locked ? Lock : LockOpen);
</script>

<div class="pointer-events-none fixed inset-y-0 right-6 flex items-center">
  <section aria-label={t('ui.keyfob')} class="pointer-events-auto flex animate-enter items-center gap-4 font-sans text-foreground">
    <div class="flex w-[13rem] flex-col gap-3 rounded-lg border border-border bg-card p-4">
      <div class="flex min-w-0 flex-col gap-0.5">
        <h1 class="truncate text-base font-semibold">{vehicle.label}</h1>
        <p class="text-xs font-medium tracking-[0.04em] text-muted-foreground tabular-nums">{vehicle.plate}</p>
      </div>
      <div class="flex items-center justify-between border-t border-border pt-3">
        <span class="flex h-[1.375rem] items-center gap-1 rounded-sm bg-secondary px-2 text-xs font-medium">
          <StatusIcon weight="fill" size="0.75rem" />
          {vehicle.locked ? t('ui.locked') : t('ui.unlocked')}
        </span>
        <span class="flex items-center gap-1.5 text-xs text-muted-foreground">
          <kbd class="flex h-5 items-center rounded-sm border border-border bg-muted px-1.5 font-sans font-medium text-foreground">
            {t('ui.escape')}
          </kbd>
          {t('ui.close')}
        </span>
      </div>
    </div>

    <div class="relative h-[22rem] select-none">
      <img src={fobImage} alt="" draggable="false" class="h-full w-auto" />
      {#key presses}
        <span
          aria-hidden="true"
          class={[
            'absolute top-[14.7%] left-1/2 h-[2.2%] w-[4.8%] -translate-x-1/2 -translate-y-1/2 rounded-full',
            vehicle.locked ? 'bg-cobalt' : 'bg-led-off',
            presses > 0 && 'animate-blink',
          ]}
        ></span>
      {/key}
      {#each hotspots as hotspot, index (hotspot.action)}
        {@const label = t(hotspot.labelKey)}
        <button
          type="button"
          aria-label={label}
          aria-keyshortcuts={String(index + 1)}
          title={`${label} (${index + 1})`}
          disabled={busy}
          onclick={() => onaction(hotspot.action)}
          style:left="{BUTTON_LEFT}%"
          style:width="{BUTTON_WIDTH}%"
          style:top="{hotspot.top}%"
          style:height="{hotspot.height}%"
          class="absolute rounded-[0.6rem] transition-transform hover:ring-2 hover:ring-ring-hover focus-visible:ring-2 focus-visible:ring-cobalt focus-visible:outline-none active:scale-[0.97] disabled:cursor-default"
        ></button>
      {/each}
    </div>
  </section>
</div>
