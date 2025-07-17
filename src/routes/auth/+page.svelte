<script>
	import DOMPurify from 'dompurify';
	import { marked } from 'marked';

	import { toast } from 'svelte-sonner';

	import { onMount, getContext, tick } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';

	import { getBackendConfig } from '$lib/apis';
	import { ldapUserSignIn, getSessionUser, userSignIn, userSignUp } from '$lib/apis/auths';

	import { WEBUI_API_BASE_URL, WEBUI_BASE_URL } from '$lib/constants';
	import { WEBUI_NAME, config, user, socket } from '$lib/stores';

	import { generateInitialsImage, canvasPixelTest } from '$lib/utils';

	import Spinner from '$lib/components/common/Spinner.svelte';
	import OnBoarding from '$lib/components/OnBoarding.svelte';

	const i18n = getContext('i18n');

	let loaded = false;

	let mode = $config?.features.enable_ldap ? 'ldap' : 'signin';

	let name = '';
	let email = '';
	let password = '';

	let ldapUsername = '';
	let showLogin = false;

	const querystringValue = (key) => {
		const querystring = window.location.search;
		const urlParams = new URLSearchParams(querystring);
		return urlParams.get(key);
	};

	const setSessionUser = async (sessionUser) => {
		if (sessionUser) {
			console.log(sessionUser);
			toast.success($i18n.t(`You're now logged in.`));
			if (sessionUser.token) {
				localStorage.token = sessionUser.token;
			}
			$socket.emit('user-join', { auth: { token: sessionUser.token } });
			await user.set(sessionUser);
			await config.set(await getBackendConfig());

			const redirectPath = querystringValue('redirect') || '/';
			goto(redirectPath);
		}
	};

	const signInHandler = async () => {
		const sessionUser = await userSignIn(email, password).catch((error) => {
			toast.error(`${error}`);
			return null;
		});

		await setSessionUser(sessionUser);
	};

	const signUpHandler = async () => {
		const sessionUser = await userSignUp(name, email, password, generateInitialsImage(name)).catch(
			(error) => {
				toast.error(`${error}`);
				return null;
			}
		);

		await setSessionUser(sessionUser);
	};

	const ldapSignInHandler = async () => {
		const sessionUser = await ldapUserSignIn(ldapUsername, password).catch((error) => {
			toast.error(`${error}`);
			return null;
		});
		await setSessionUser(sessionUser);
	};

	const submitHandler = async () => {
		if (mode === 'ldap') {
			await ldapSignInHandler();
		} else if (mode === 'signin') {
			await signInHandler();
		} else {
			await signUpHandler();
		}
	};

	const checkOauthCallback = async () => {
		if (!$page.url.hash) {
			return;
		}
		const hash = $page.url.hash.substring(1);
		if (!hash) {
			return;
		}
		const params = new URLSearchParams(hash);
		const token = params.get('token');
		if (!token) {
			return;
		}
		const sessionUser = await getSessionUser(token).catch((error) => {
			toast.error(`${error}`);
			return null;
		});
		if (!sessionUser) {
			return;
		}
		localStorage.token = token;
		await setSessionUser(sessionUser);
	};

	let onboarding = false;

	async function setLogoImage() {
		await tick();
		const logo = document.getElementById('logo');

		if (logo) {
			const isDarkMode = document.documentElement.classList.contains('dark');

			if (isDarkMode) {
				const darkImage = new Image();
				darkImage.src = `${WEBUI_BASE_URL}/static/favicon-dark.png`;

				darkImage.onload = () => {
					logo.src = `${WEBUI_BASE_URL}/static/favicon-dark.png`;
					logo.style.filter = ''; // Ensure no inversion is applied if favicon-dark.png exists
				};

				darkImage.onerror = () => {
					logo.style.filter = 'invert(1)'; // Invert image if favicon-dark.png is missing
				};
			}
		}
	}

	onMount(async () => {
		if ($user !== undefined) {
			const redirectPath = querystringValue('redirect') || '/';
			goto(redirectPath);
		}
		await checkOauthCallback();

		loaded = true;
		setLogoImage();

		if (($config?.features.auth_trusted_header ?? false) || $config?.features.auth === false) {
			await signInHandler();
		} else {
			onboarding = $config?.onboarding ?? false;
		}
	});
</script>

<svelte:head>
	<title>
		{`${$WEBUI_NAME}`}
	</title>
</svelte:head>

<OnBoarding
	bind:show={onboarding}
	getStartedHandler={() => {
		onboarding = false;
		mode = $config?.features.enable_ldap ? 'ldap' : 'signup';
	}}
/>

<div class="w-full min-h-screen bg-black text-white relative overflow-x-hidden">
	<!-- Navigation -->
	<nav class="fixed top-0 left-0 right-0 z-50 bg-black/80 backdrop-blur-md border-b border-orange-500/20">
		<div class="max-w-7xl mx-auto px-6 py-4">
			<div class="flex items-center justify-between">
				<div class="flex items-center space-x-3">
					<div class="relative">
						<div class="absolute inset-0 bg-gradient-to-r from-orange-500 to-orange-600 rounded-full blur-sm opacity-75"></div>
						<img
							id="logo"
							crossorigin="anonymous"
							src="{WEBUI_BASE_URL}/static/favicon.png"
							class="relative w-8 h-8 rounded-full"
							alt="SneakyHub AI"
						/>
					</div>
					<div class="text-white font-bold text-xl tracking-wide">
						<span class="bg-gradient-to-r from-orange-400 to-orange-500 bg-clip-text text-transparent">SneakyHub</span>
						<span class="text-orange-100 ml-1">AI</span>
					</div>
				</div>
				<div class="flex items-center space-x-6">
					<a href="#features" class="text-orange-200 hover:text-orange-400 transition-colors">Features</a>
					<a href="#use-cases" class="text-orange-200 hover:text-orange-400 transition-colors">Use Cases</a>
					<a href="#technical" class="text-orange-200 hover:text-orange-400 transition-colors">Technical</a>
					<button
						class="px-4 py-2 bg-gradient-to-r from-orange-600 to-orange-500 hover:from-orange-700 hover:to-orange-600 rounded-lg font-medium transition-all duration-200 transform hover:scale-105"
						on:click={() => showLogin = true}
					>
						Get Started
					</button>
				</div>
			</div>
		</div>
	</nav>

	<!-- Background Elements -->
	<div class="fixed inset-0 bg-gradient-to-br from-black via-gray-900 to-black">
		<div class="absolute inset-0">
			<div class="absolute top-1/4 left-1/4 w-64 h-64 bg-orange-500/10 rounded-full blur-3xl animate-pulse"></div>
			<div class="absolute bottom-1/4 right-1/4 w-96 h-96 bg-orange-600/8 rounded-full blur-3xl animate-pulse delay-1000"></div>
			<div class="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-80 h-80 bg-orange-400/8 rounded-full blur-3xl animate-pulse delay-500"></div>
		</div>
		<div class="absolute inset-0 bg-[linear-gradient(rgba(249,115,22,0.03)_1px,transparent_1px),linear-gradient(90deg,rgba(249,115,22,0.03)_1px,transparent_1px)] bg-[size:50px_50px]"></div>
	</div>

	{#if loaded}
		<!-- Main Content Container -->
		<div class="relative z-10 pt-20">
			{#if ($config?.features.auth_trusted_header ?? false) || $config?.features.auth === false}
				<!-- Auto-signin Loading -->
				<div class="min-h-screen flex items-center justify-center">
					<div class="text-center">
						<div class="flex items-center justify-center gap-3 text-xl sm:text-2xl font-semibold text-white mb-4">
							<div>{$i18n.t('Signing in to SneakyHub AI')}</div>
							<div><Spinner className="size-5" /></div>
						</div>
					</div>
				</div>
			{:else}
				<!-- Landing Page Content -->
				<div class="min-h-screen">
					<!-- Hero Section -->
					<section class="relative min-h-screen flex items-center justify-center px-6">
						<div class="max-w-6xl mx-auto text-center">
							<div class="mb-8">
								<h1 class="text-5xl md:text-7xl font-bold mb-6">
									<span class="bg-gradient-to-r from-orange-400 to-orange-500 bg-clip-text text-transparent">SneakyHub</span>
									<span class="text-white ml-2">AI</span>
								</h1>
								<p class="text-xl md:text-2xl text-orange-200 mb-6">The Ultimate AI Assistant for Developers</p>
								<p class="text-lg text-orange-100/80 max-w-3xl mx-auto leading-relaxed mb-8">
									Supercharge your development workflow with an AI assistant that understands code, debugging, configurations, and development best practices. Built by developers, for developers.
								</p>
								<div class="flex flex-col sm:flex-row gap-4 justify-center">
									<button
										class="px-8 py-4 bg-gradient-to-r from-orange-600 to-orange-500 hover:from-orange-700 hover:to-orange-600 rounded-xl font-semibold text-lg transition-all duration-200 transform hover:scale-105"
										on:click={() => showLogin = true}
									>
										Start Coding with AI
									</button>
									<button
										class="px-8 py-4 bg-black/40 border border-orange-500/40 hover:border-orange-400/60 rounded-xl font-semibold text-lg transition-all duration-200 transform hover:scale-105"
										on:click={() => document.getElementById('features').scrollIntoView({ behavior: 'smooth' })}
									>
										Learn More
									</button>
								</div>
							</div>
						</div>
					</section>

					<!-- Features Section -->
					<section id="features" class="py-20 px-6">
						<div class="max-w-6xl mx-auto">
							<div class="text-center mb-16">
								<h2 class="text-4xl md:text-5xl font-bold mb-6 text-white">
									Powerful Features for <span class="text-orange-400">Developers</span>
								</h2>
								<p class="text-xl text-orange-200 max-w-3xl mx-auto">
									Everything you need to accelerate your development process, from code generation to debugging and beyond.
								</p>
							</div>

							<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
								<!-- Code Generation -->
								<div class="bg-black/30 backdrop-blur-sm border border-orange-500/20 rounded-xl p-8 hover:border-orange-500/40 transition-all duration-300 hover:transform hover:scale-105">
									<div class="text-orange-400 mb-6">
										<svg class="w-12 h-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" />
										</svg>
									</div>
									<h3 class="text-white font-bold text-xl mb-4">Code Generation</h3>
									<p class="text-orange-200/80 leading-relaxed">Generate clean, efficient code in any programming language. From simple functions to complex algorithms, get production-ready code instantly.</p>
								</div>

								<!-- Debugging Assistant -->
								<div class="bg-black/30 backdrop-blur-sm border border-orange-500/20 rounded-xl p-8 hover:border-orange-500/40 transition-all duration-300 hover:transform hover:scale-105">
									<div class="text-orange-400 mb-6">
										<svg class="w-12 h-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
										</svg>
									</div>
									<h3 class="text-white font-bold text-xl mb-4">Smart Debugging</h3>
									<p class="text-orange-200/80 leading-relaxed">Identify bugs quickly, understand error messages, and get step-by-step solutions. Debug faster with intelligent analysis.</p>
								</div>

								<!-- Configuration Management -->
								<div class="bg-black/30 backdrop-blur-sm border border-orange-500/20 rounded-xl p-8 hover:border-orange-500/40 transition-all duration-300 hover:transform hover:scale-105">
									<div class="text-orange-400 mb-6">
										<svg class="w-12 h-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4" />
										</svg>
									</div>
									<h3 class="text-white font-bold text-xl mb-4">Config Creation</h3>
									<p class="text-orange-200/80 leading-relaxed">Create perfect configurations for servers, databases, CI/CD pipelines, and development tools. Optimize performance and security.</p>
								</div>

								<!-- Code Review -->
								<div class="bg-black/30 backdrop-blur-sm border border-orange-500/20 rounded-xl p-8 hover:border-orange-500/40 transition-all duration-300 hover:transform hover:scale-105">
									<div class="text-orange-400 mb-6">
										<svg class="w-12 h-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" />
										</svg>
									</div>
									<h3 class="text-white font-bold text-xl mb-4">Code Review</h3>
									<p class="text-orange-200/80 leading-relaxed">Get detailed code reviews with suggestions for improvements, security checks, and best practices. Maintain high code quality.</p>
								</div>

								<!-- Architecture Planning -->
								<div class="bg-black/30 backdrop-blur-sm border border-orange-500/20 rounded-xl p-8 hover:border-orange-500/40 transition-all duration-300 hover:transform hover:scale-105">
									<div class="text-orange-400 mb-6">
										<svg class="w-12 h-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
										</svg>
									</div>
									<h3 class="text-white font-bold text-xl mb-4">Architecture Planning</h3>
									<p class="text-orange-200/80 leading-relaxed">Design scalable system architectures, choose the right technologies, and plan your development roadmap with expert guidance.</p>
								</div>

								<!-- Documentation -->
								<div class="bg-black/30 backdrop-blur-sm border border-orange-500/20 rounded-xl p-8 hover:border-orange-500/40 transition-all duration-300 hover:transform hover:scale-105">
									<div class="text-orange-400 mb-6">
										<svg class="w-12 h-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
										</svg>
									</div>
									<h3 class="text-white font-bold text-xl mb-4">Smart Documentation</h3>
									<p class="text-orange-200/80 leading-relaxed">Generate comprehensive documentation, API guides, and code comments. Keep your projects well-documented effortlessly.</p>
								</div>
							</div>
						</div>
					</section>

					<!-- Use Cases Section -->
					<section id="use-cases" class="py-20 px-6 bg-black/20">
						<div class="max-w-6xl mx-auto">
							<div class="text-center mb-16">
								<h2 class="text-4xl md:text-5xl font-bold mb-6 text-white">
									Built for <span class="text-orange-400">Every</span> Developer
								</h2>
								<p class="text-xl text-orange-200 max-w-3xl mx-auto">
									Whether you're a solo developer, part of a team, or managing enterprise projects, SneakyHub AI adapts to your workflow.
								</p>
							</div>

							<div class="grid grid-cols-1 md:grid-cols-2 gap-12">
								<!-- Frontend Developers -->
								<div class="bg-black/40 backdrop-blur-sm border border-orange-500/20 rounded-xl p-8">
									<div class="flex items-center mb-6">
										<div class="text-orange-400 mr-4">
											<svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
												<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" />
											</svg>
										</div>
										<h3 class="text-white font-bold text-xl">Frontend Developers</h3>
									</div>
									<ul class="space-y-3 text-orange-200/80">
										<li class="flex items-start">
											<span class="text-orange-400 mr-2">•</span>
											React, Vue, Angular component generation
										</li>
										<li class="flex items-start">
											<span class="text-orange-400 mr-2">•</span>
											CSS/SCSS styling and responsive design
										</li>
										<li class="flex items-start">
											<span class="text-orange-400 mr-2">•</span>
											JavaScript/TypeScript debugging
										</li>
										<li class="flex items-start">
											<span class="text-orange-400 mr-2">•</span>
											Performance optimization suggestions
										</li>
										<li class="flex items-start">
											<span class="text-orange-400 mr-2">•</span>
											Cross-browser compatibility fixes
										</li>
									</ul>
								</div>

								<!-- Backend Developers -->
								<div class="bg-black/40 backdrop-blur-sm border border-orange-500/20 rounded-xl p-8">
									<div class="flex items-center mb-6">
										<div class="text-orange-400 mr-4">
											<svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
												<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2m-2-4h.01M17 16h.01" />
											</svg>
										</div>
										<h3 class="text-white font-bold text-xl">Backend Developers</h3>
									</div>
									<ul class="space-y-3 text-orange-200/80">
										<li class="flex items-start">
											<span class="text-orange-400 mr-2">•</span>
											API design and REST/GraphQL endpoints
										</li>
										<li class="flex items-start">
											<span class="text-orange-400 mr-2">•</span>
											Database schema design and optimization
										</li>
										<li class="flex items-start">
											<span class="text-orange-400 mr-2">•</span>
											Server configuration and deployment
										</li>
										<li class="flex items-start">
											<span class="text-orange-400 mr-2">•</span>
											Security best practices and authentication
										</li>
										<li class="flex items-start">
											<span class="text-orange-400 mr-2">•</span>
											Microservices architecture planning
										</li>
									</ul>
								</div>

								<!-- DevOps Engineers -->
								<div class="bg-black/40 backdrop-blur-sm border border-orange-500/20 rounded-xl p-8">
									<div class="flex items-center mb-6">
										<div class="text-orange-400 mr-4">
											<svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
												<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
												<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
											</svg>
										</div>
										<h3 class="text-white font-bold text-xl">DevOps Engineers</h3>
									</div>
									<ul class="space-y-3 text-orange-200/80">
										<li class="flex items-start">
											<span class="text-orange-400 mr-2">•</span>
											CI/CD pipeline configuration
										</li>
										<li class="flex items-start">
											<span class="text-orange-400 mr-2">•</span>
											Docker and Kubernetes deployment
										</li>
										<li class="flex items-start">
											<span class="text-orange-400 mr-2">•</span>
											Infrastructure as Code (Terraform, Ansible)
										</li>
										<li class="flex items-start">
											<span class="text-orange-400 mr-2">•</span>
											Monitoring and logging setup
										</li>
										<li class="flex items-start">
											<span class="text-orange-400 mr-2">•</span>
											Cloud platform optimization (AWS, GCP, Azure)
										</li>
									</ul>
								</div>

								<!-- Full-Stack Developers -->
								<div class="bg-black/40 backdrop-blur-sm border border-orange-500/20 rounded-xl p-8">
									<div class="flex items-center mb-6">
										<div class="text-orange-400 mr-4">
											<svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
												<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9" />
											</svg>
										</div>
										<h3 class="text-white font-bold text-xl">Full-Stack Developers</h3>
									</div>
									<ul class="space-y-3 text-orange-200/80">
										<li class="flex items-start">
											<span class="text-orange-400 mr-2">•</span>
											End-to-end application development
										</li>
										<li class="flex items-start">
											<span class="text-orange-400 mr-2">•</span>
											Technology stack recommendations
										</li>
										<li class="flex items-start">
											<span class="text-orange-400 mr-2">•</span>
											Integration between frontend and backend
										</li>
										<li class="flex items-start">
											<span class="text-orange-400 mr-2">•</span>
											Database design and API development
										</li>
										<li class="flex items-start">
											<span class="text-orange-400 mr-2">•</span>
											Project architecture and scalability planning
										</li>
									</ul>
								</div>
							</div>
						</div>
					</section>

					<!-- Technical Specifications -->
					<section id="technical" class="py-20 px-6">
						<div class="max-w-6xl mx-auto">
							<div class="text-center mb-16">
								<h2 class="text-4xl md:text-5xl font-bold mb-6 text-white">
									Technical <span class="text-orange-400">Specifications</span>
								</h2>
								<p class="text-xl text-orange-200 max-w-3xl mx-auto">
									Built with cutting-edge technology and designed for enterprise-grade performance and security.
								</p>
							</div>

							<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
								<!-- Self-Hosted -->
								<div class="bg-black/30 backdrop-blur-sm border border-orange-500/20 rounded-xl p-8 text-center">
									<div class="text-orange-400 mb-6">
										<svg class="w-12 h-12 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
										</svg>
									</div>
									<h3 class="text-white font-bold text-xl mb-4">Self-Hosted</h3>
									<p class="text-orange-200/80">Your data stays on your infrastructure. Complete control over security and privacy.</p>
								</div>

								<!-- Multi-Language -->
								<div class="bg-black/30 backdrop-blur-sm border border-orange-500/20 rounded-xl p-8 text-center">
									<div class="text-orange-400 mb-6">
										<svg class="w-12 h-12 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 10.77 8.07 15.61 3 18.129" />
										</svg>
									</div>
									<h3 class="text-white font-bold text-xl mb-4">Multi-Language</h3>
									<p class="text-orange-200/80">Supports 50+ programming languages with deep understanding of syntax and best practices.</p>
								</div>

								<!-- Fast Performance -->
								<div class="bg-black/30 backdrop-blur-sm border border-orange-500/20 rounded-xl p-8 text-center">
									<div class="text-orange-400 mb-6">
										<svg class="w-12 h-12 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
										</svg>
									</div>
									<h3 class="text-white font-bold text-xl mb-4">Lightning Fast</h3>
									<p class="text-orange-200/80">Optimized for speed with local processing and efficient model management.</p>
								</div>

								<!-- Docker Ready -->
								<div class="bg-black/30 backdrop-blur-sm border border-orange-500/20 rounded-xl p-8 text-center">
									<div class="text-orange-400 mb-6">
										<svg class="w-12 h-12 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
										</svg>
									</div>
									<h3 class="text-white font-bold text-xl mb-4">Docker Ready</h3>
									<p class="text-orange-200/80">Easy deployment with Docker containers. Scale horizontally with Kubernetes.</p>
								</div>

								<!-- Open Source -->
								<div class="bg-black/30 backdrop-blur-sm border border-orange-500/20 rounded-xl p-8 text-center">
									<div class="text-orange-400 mb-6">
										<svg class="w-12 h-12 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
										</svg>
									</div>
									<h3 class="text-white font-bold text-xl mb-4">Open Source</h3>
									<p class="text-orange-200/80">Built on open-source technologies. Transparent, customizable, and community-driven.</p>
								</div>

								<!-- Enterprise Ready -->
								<div class="bg-black/30 backdrop-blur-sm border border-orange-500/20 rounded-xl p-8 text-center">
									<div class="text-orange-400 mb-6">
										<svg class="w-12 h-12 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
										</svg>
									</div>
									<h3 class="text-white font-bold text-xl mb-4">Enterprise Ready</h3>
									<p class="text-orange-200/80">RBAC, SSO integration, audit logs, and compliance features for enterprise environments.</p>
								</div>
							</div>
						</div>
					</section>

					<!-- CTA Section -->
					<section class="py-20 px-6 bg-gradient-to-r from-orange-600/20 to-orange-500/20">
						<div class="max-w-4xl mx-auto text-center">
							<h2 class="text-4xl md:text-5xl font-bold mb-6 text-white">
								Ready to <span class="text-orange-400">Transform</span> Your Development?
							</h2>
							<p class="text-xl text-orange-200 mb-8 max-w-2xl mx-auto">
								Join thousands of developers who are already using SneakyHub AI to write better code faster.
							</p>
							<div class="flex flex-col sm:flex-row gap-4 justify-center">
								<button
									class="px-8 py-4 bg-gradient-to-r from-orange-600 to-orange-500 hover:from-orange-700 hover:to-orange-600 rounded-xl font-semibold text-lg transition-all duration-200 transform hover:scale-105"
									on:click={() => showLogin = true}
								>
									Get Started Now
								</button>
								<button
									class="px-8 py-4 bg-black/40 border border-orange-500/40 hover:border-orange-400/60 rounded-xl font-semibold text-lg transition-all duration-200 transform hover:scale-105"
									on:click={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
								>
									Back to Top
								</button>
							</div>
						</div>
					</section>
				</div>
			{/if}
		</div>

		<!-- Login Modal -->
		{#if showLogin}
			<div class="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
				<div class="bg-black/90 border border-orange-500/30 rounded-2xl p-8 max-w-md w-full max-h-[90vh] overflow-y-auto">
					<div class="flex justify-between items-center mb-6">
						<h2 class="text-2xl font-bold text-white">Welcome to SneakyHub AI</h2>
						<button
							class="text-orange-400 hover:text-orange-300 transition-colors"
							on:click={() => showLogin = false}
						>
							<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
							</svg>
						</button>
					</div>
					
					<div class="text-center mb-6">
						<p class="text-orange-200 mb-4">
							{#if $config?.onboarding ?? false}
								🔒 Your data stays secure on your locally hosted server
							{:else}
								{mode === 'signin' ? 'Access your developer AI workspace' : 'Create your developer AI workspace'}
							{/if}
						</p>
					</div>

					{#if $config?.features.enable_login_form || $config?.features.enable_ldap}
						<form
							class="flex flex-col justify-center"
							on:submit={(e) => {
										e.preventDefault();
										submitHandler();
									}}
								>
									<div class="mb-6 text-center">
										<div class="text-2xl font-medium text-white mb-2">
											{#if $config?.onboarding ?? false}
												{$i18n.t(`Get started with SneakyHub AI`)}
											{:else if mode === 'ldap'}
												{$i18n.t(`Sign in with LDAP`)}
											{:else if mode === 'signin'}
												{$i18n.t(`Welcome back`)}
											{:else}
												{$i18n.t(`Join SneakyHub AI`)}
											{/if}
										</div>

										{#if $config?.onboarding ?? false}
											<div class="text-sm text-orange-200">
												🔒 Your data stays secure on your locally hosted server
											</div>
										{:else}
											<div class="text-sm text-orange-200">
												{mode === 'signin' ? 'Access your developer AI workspace' : 'Create your developer AI workspace'}
											</div>
										{/if}
									</div>

								{#if $config?.features.enable_login_form || $config?.features.enable_ldap}
									<div class="flex flex-col mt-4 space-y-4">
										{#if mode === 'signup'}
											<div>
												<label for="name" class="text-sm font-medium text-orange-200 mb-2 block"
													>{$i18n.t('Name')}</label
												>
												<input
													bind:value={name}
													type="text"
													id="name"
													class="w-full px-4 py-3 bg-black/20 border border-orange-500/30 rounded-xl text-white placeholder-orange-300/50 focus:border-orange-400 focus:outline-none transition-all duration-200"
													autocomplete="name"
													placeholder={$i18n.t('Enter Your Full Name')}
													required
												/>
											</div>
										{/if}

										{#if mode === 'ldap'}
											<div>
												<label for="username" class="text-sm font-medium text-orange-200 mb-2 block"
													>{$i18n.t('Username')}</label
												>
												<input
													bind:value={ldapUsername}
													type="text"
													class="w-full px-4 py-3 bg-black/20 border border-orange-500/30 rounded-xl text-white placeholder-orange-300/50 focus:border-orange-400 focus:outline-none transition-all duration-200"
													autocomplete="username"
													name="username"
													id="username"
													placeholder={$i18n.t('Enter Your Username')}
													required
												/>
											</div>
										{:else}
											<div>
												<label for="email" class="text-sm font-medium text-orange-200 mb-2 block"
													>{$i18n.t('Email')}</label
												>
												<input
													bind:value={email}
													type="email"
													id="email"
													class="w-full px-4 py-3 bg-black/20 border border-orange-500/30 rounded-xl text-white placeholder-orange-300/50 focus:border-orange-400 focus:outline-none transition-all duration-200"
													autocomplete="email"
													name="email"
													placeholder={$i18n.t('Enter Your Email')}
													required
												/>
											</div>
										{/if}

										<div>
											<label for="password" class="text-sm font-medium text-orange-200 mb-2 block"
												>{$i18n.t('Password')}</label
											>
											<input
												bind:value={password}
												type="password"
												id="password"
												class="w-full px-4 py-3 bg-black/20 border border-orange-500/30 rounded-xl text-white placeholder-orange-300/50 focus:border-orange-400 focus:outline-none transition-all duration-200"
												placeholder={$i18n.t('Enter Your Password')}
												autocomplete={mode === 'signup' ? 'new-password' : 'current-password'}
												name="password"
												required
											/>
										</div>
									</div>
								{/if}
								<div class="mt-8">
									{#if $config?.features.enable_login_form || $config?.features.enable_ldap}
										{#if mode === 'ldap'}
											<button
												class="w-full py-4 bg-gradient-to-r from-orange-600 to-orange-500 hover:from-orange-700 hover:to-orange-600 text-white font-semibold rounded-xl transition-all duration-200 transform hover:scale-[1.02] focus:outline-none focus:ring-2 focus:ring-orange-500 focus:ring-offset-2 focus:ring-offset-transparent"
												type="submit"
											>
												{$i18n.t('Authenticate')}
											</button>
										{:else}
											<button
												class="w-full py-4 bg-gradient-to-r from-orange-600 to-orange-500 hover:from-orange-700 hover:to-orange-600 text-white font-semibold rounded-xl transition-all duration-200 transform hover:scale-[1.02] focus:outline-none focus:ring-2 focus:ring-orange-500 focus:ring-offset-2 focus:ring-offset-transparent"
												type="submit"
											>
												{mode === 'signin'
													? $i18n.t('Sign in')
													: ($config?.onboarding ?? false)
														? $i18n.t('Create Admin Account')
														: $i18n.t('Create Account')}
											</button>

											{#if $config?.features.enable_signup && !($config?.onboarding ?? false)}
												<div class="mt-6 text-sm text-center">
													<span class="text-orange-200">
														{mode === 'signin'
															? $i18n.t("Don't have an account?")
															: $i18n.t('Already have an account?')}
													</span>

													<button
														class="ml-2 font-medium text-orange-400 hover:text-orange-300 underline transition-colors duration-200"
														type="button"
														on:click={() => {
															if (mode === 'signin') {
																mode = 'signup';
															} else {
																mode = 'signin';
															}
														}}
													>
														{mode === 'signin' ? $i18n.t('Sign up') : $i18n.t('Sign in')}
													</button>
												</div>
											{/if}
										{/if}
									{/if}
								</div>
								</form>
							</div>

							{#if Object.keys($config?.oauth?.providers ?? {}).length > 0}
								<div class="inline-flex items-center justify-center w-full mt-6">
									<hr class="w-32 h-px my-4 border-0 bg-orange-500/20" />
									{#if $config?.features.enable_login_form || $config?.features.enable_ldap}
										<span
											class="px-3 text-sm font-medium text-orange-200 bg-transparent"
											>{$i18n.t('or')}</span
										>
									{/if}

									<hr class="w-32 h-px my-4 border-0 bg-orange-500/20" />
								</div>
								<div class="flex flex-col space-y-3">
									{#if $config?.oauth?.providers?.google}
										<button
											class="flex justify-center items-center bg-black/20 border border-orange-500/30 hover:border-purple-400/50 text-white hover:bg-black/30 transition-all duration-200 w-full rounded-xl font-medium text-sm py-3"
											on:click={() => {
												window.location.href = `${WEBUI_BASE_URL}/oauth/google/login`;
											}}
										>
											<svg
												xmlns="http://www.w3.org/2000/svg"
												viewBox="0 0 48 48"
												class="size-6 mr-3"
											>
												<path
													fill="#EA4335"
													d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"
												/><path
													fill="#4285F4"
													d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"
												/><path
													fill="#FBBC05"
													d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"
												/><path
													fill="#34A853"
													d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"
												/><path fill="none" d="M0 0h48v48H0z" />
											</svg>
											<span>{$i18n.t('Continue with {{provider}}', { provider: 'Google' })}</span>
										</button>
									{/if}
									{#if $config?.oauth?.providers?.microsoft}
										<button
											class="flex justify-center items-center bg-black/20 border border-orange-500/30 hover:border-purple-400/50 text-white hover:bg-black/30 transition-all duration-200 w-full rounded-xl font-medium text-sm py-3"
											on:click={() => {
												window.location.href = `${WEBUI_BASE_URL}/oauth/microsoft/login`;
											}}
										>
											<svg
												xmlns="http://www.w3.org/2000/svg"
												viewBox="0 0 21 21"
												class="size-6 mr-3"
											>
												<rect x="1" y="1" width="9" height="9" fill="#f25022" /><rect
													x="1"
													y="11"
													width="9"
													height="9"
													fill="#00a4ef"
												/><rect x="11" y="1" width="9" height="9" fill="#7fba00" /><rect
													x="11"
													y="11"
													width="9"
													height="9"
													fill="#ffb900"
												/>
											</svg>
											<span>{$i18n.t('Continue with {{provider}}', { provider: 'Microsoft' })}</span
											>
										</button>
									{/if}
									{#if $config?.oauth?.providers?.github}
										<button
											class="flex justify-center items-center bg-black/20 border border-orange-500/30 hover:border-purple-400/50 text-white hover:bg-black/30 transition-all duration-200 w-full rounded-xl font-medium text-sm py-3"
											on:click={() => {
												window.location.href = `${WEBUI_BASE_URL}/oauth/github/login`;
											}}
										>
											<svg
												xmlns="http://www.w3.org/2000/svg"
												viewBox="0 0 24 24"
												class="size-6 mr-3"
											>
												<path
													fill="currentColor"
													d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.92 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57C20.565 21.795 24 17.31 24 12c0-6.63-5.37-12-12-12z"
												/>
											</svg>
											<span>{$i18n.t('Continue with {{provider}}', { provider: 'GitHub' })}</span>
										</button>
									{/if}
									{#if $config?.oauth?.providers?.oidc}
										<button
											class="flex justify-center items-center bg-black/20 border border-orange-500/30 hover:border-purple-400/50 text-white hover:bg-black/30 transition-all duration-200 w-full rounded-xl font-medium text-sm py-3"
											on:click={() => {
												window.location.href = `${WEBUI_BASE_URL}/oauth/oidc/login`;
											}}
										>
											<svg
												xmlns="http://www.w3.org/2000/svg"
												fill="none"
												viewBox="0 0 24 24"
												stroke-width="1.5"
												stroke="currentColor"
												class="size-6 mr-3"
											>
												<path
													stroke-linecap="round"
													stroke-linejoin="round"
													d="M15.75 5.25a3 3 0 0 1 3 3m3 0a6 6 0 0 1-7.029 5.912c-.563-.097-1.159.026-1.563.43L10.5 17.25H8.25v2.25H6v2.25H2.25v-2.818c0-.597.237-1.17.659-1.591l6.499-6.499c.404-.404.527-1 .43-1.563A6 6 0 1 1 21.75 8.25Z"
												/>
											</svg>

											<span
												>{$i18n.t('Continue with {{provider}}', {
													provider: $config?.oauth?.providers?.oidc ?? 'SSO'
												})}</span
											>
										</button>
									{/if}
								</div>
							{/if}

							{#if $config?.features.enable_ldap && $config?.features.enable_login_form}
								<div class="mt-4">
									<button
										class="flex justify-center items-center text-sm w-full text-center text-orange-400 hover:text-orange-300 underline transition-colors duration-200"
										type="button"
										on:click={() => {
											if (mode === 'ldap')
												mode = ($config?.onboarding ?? false) ? 'signup' : 'signin';
											else mode = 'ldap';
										}}
									>
										<span
											>{mode === 'ldap'
												? $i18n.t('Continue with Email')
												: $i18n.t('Continue with LDAP')}</span
										>
									</button>
								</div>
							{/if}
						</div>
						{#if $config?.metadata?.login_footer}
							<div class="max-w-3xl mx-auto">
								<div class="mt-4 text-xs text-orange-300/70 marked text-center">
									{@html DOMPurify.sanitize(marked($config?.metadata?.login_footer))}
								</div>
							</div>
						{/if}
					{/if}
				</div>
			</div>
		{/if}
	{/if}
</div>
