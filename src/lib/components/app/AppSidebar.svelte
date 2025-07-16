<script lang="ts">
	import Tooltip from '$lib/components/common/Tooltip.svelte';
	import Plus from '$lib/components/icons/Plus.svelte';
	import { WEBUI_BASE_URL } from '$lib/constants';

	let selected = '';
</script>

<div class="min-w-[4.5rem] bg-gradient-to-b from-black via-gray-900 to-black border-r border-orange-500/20 flex gap-2.5 flex-col pt-8 shadow-xl">
	<div class="flex justify-center relative">
		{#if selected === 'home'}
			<div class="absolute top-0 left-0 flex h-full">
				<div class="my-auto rounded-r-lg w-1 h-8 bg-gradient-to-b from-orange-500 to-orange-600"></div>
			</div>
		{/if}

		<Tooltip content="Home" placement="right">
			<button
				class=" cursor-pointer transition-all duration-200 hover:scale-105 {selected === 'home' ? 'rounded-2xl shadow-lg shadow-orange-500/20' : 'rounded-full hover:shadow-md hover:shadow-orange-500/10'}"
				on:click={() => {
					selected = 'home';

					if (window.electronAPI) {
						window.electronAPI.load('home');
					}
				}}
			>
				<img
					src="{WEBUI_BASE_URL}/static/splash.png"
					class="size-11 p-0.5 filter brightness-0 invert"
					alt="logo"
					draggable="false"
				/>
			</button>
		</Tooltip>
	</div>

	<div class=" -mt-1 border-[1.5px] border-orange-500/30 mx-4"></div>

	<div class="flex justify-center relative group">
		{#if selected === ''}
			<div class="absolute top-0 left-0 flex h-full">
				<div class="my-auto rounded-r-lg w-1 h-8 bg-gradient-to-b from-orange-500 to-orange-600"></div>
			</div>
		{/if}
		<button
			class=" cursor-pointer bg-transparent transition-all duration-200 hover:scale-105 {selected === '' ? 'shadow-lg shadow-orange-500/20' : 'hover:shadow-md hover:shadow-orange-500/10'}"
			on:click={() => {
				selected = '';
			}}
		>
			<div class="relative">
				<div class="absolute inset-0 bg-gradient-to-r from-orange-500 to-orange-600 rounded-full blur-sm opacity-75"></div>
				<img
					src="{WEBUI_BASE_URL}/static/favicon.png"
					class="relative size-10 {selected === '' ? 'rounded-2xl' : 'rounded-full'}"
					alt="SneakyHub AI"
					draggable="false"
				/>
			</div>
		</button>
	</div>

	<!-- <div class="flex justify-center relative group text-gray-400">
		<button class=" cursor-pointer p-2" on:click={() => {}}>
			<Plus className="size-4" strokeWidth="2" />
		</button>
	</div> -->
</div>
