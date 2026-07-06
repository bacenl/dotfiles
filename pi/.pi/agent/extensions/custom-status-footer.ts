/**
 * Custom Status Footer Extension
 *
 * Two-line footer showing:
 * Line 1: Model name, context tokens, context used %, input/output tokens, block time, cost
 * Line 2: Git branch, diff stats (+/-), cwd
 */

import { readFileSync } from "node:fs";
import { join } from "node:path";
import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";

export default function (pi: ExtensionAPI) {
	let activeTui: { requestRender(): void } | null = null;

	pi.on("turn_end", () => {
		activeTui?.requestRender();
	});

	pi.on("model_select", () => {
		activeTui?.requestRender();
	});

	pi.on("session_shutdown", () => {
		activeTui = null;
	});

	pi.on("session_start", (_event, ctx) => {
		ctx.ui.setFooter((tui, theme, footerData) => {
			activeTui = tui;
			let diffStat = { added: 0, removed: 0 };

			const refreshDiffStat = async () => {
				try {
					const result = await pi.exec("git", ["diff", "--numstat"], { cwd: ctx.cwd, timeout: 3000 });
					if (result.code === 0 && result.stdout.trim()) {
						let added = 0;
						let removed = 0;
						for (const line of result.stdout.trim().split("\n")) {
							const parts = line.split("\t");
							if (parts.length >= 2) {
								const a = parseInt(parts[0], 10);
								const r = parseInt(parts[1], 10);
								if (!isNaN(a)) added += a;
								if (!isNaN(r)) removed += r;
							}
						}
						diffStat = { added, removed };
					} else {
						diffStat = { added: 0, removed: 0 };
					}
				} catch {
					diffStat = { added: 0, removed: 0 };
				}
				tui.requestRender();
			};

			// Initial refresh
			void refreshDiffStat();

			// Periodic refresh for diff stats
			const interval = setInterval(() => {
				void refreshDiffStat();
			}, 15000);

			const unsub = footerData.onBranchChange(() => {
				void refreshDiffStat();
				tui.requestRender();
			});

			return {
				dispose() {
					clearInterval(interval);
					unsub();
					activeTui = null;
				},
				invalidate() {},
				render(width: number): string[] {
					// --- Compute token stats ---
					let input = 0;
					let output = 0;
					let cost = 0;
					for (const e of ctx.sessionManager.getBranch()) {
						if (e.type === "message" && e.message.role === "assistant") {
							const m = e.message as AssistantMessage;
							input += m.usage.input;
							output += m.usage.output;
							cost += m.usage.cost.total;
						}
					}

					// --- Context usage ---
					const usage = ctx.getContextUsage();
					const ctxTokens = usage?.tokens ?? 0;
					const ctxPercent = usage?.percent ?? 0;

					// --- Model name ---
					const modelName = ctx.model?.name ?? ctx.model?.id ?? "no model";

					// --- Block time (from codex status cache) ---
					const blockStr = getBlockTime();

					// --- Format line 1 ---
					const fmt = (n: number) => (n < 1000 ? `${n}` : `${(n / 1000).toFixed(1)}k`);
					const line1Parts = [
						theme.fg("muted", `Model: ${theme.bold(modelName)}`),
						theme.fg("dim", `Ctx: ${fmt(ctxTokens)}`),
						theme.fg("dim", `Used: ${ctxPercent.toFixed(1)}%`),
						theme.fg("dim", `In: ${fmt(input)}`),
						theme.fg("dim", `Out: ${fmt(output)}`),
						blockStr ? theme.fg("dim", `Block: ${blockStr}`) : null,
						theme.fg("dim", `Cost: $${cost.toFixed(4)}`),
					].filter(Boolean);
					const line1 = line1Parts.join("  ");

					// --- Format line 2 ---
					const branch = footerData.getGitBranch();
					const cwdDisplay = formatCwd(ctx.cwd);

					const line2Parts = [
						branch ? theme.fg("accent", `   ⎇ ${branch}`) : null,
						theme.fg("dim", `(+${diffStat.added},-${diffStat.removed})`),
						theme.fg("dim", `cwd: ${cwdDisplay}`),
					].filter(Boolean);
					const line2 = line2Parts.join("  ");

					return [
						truncateToWidth(line1, width),
						truncateToWidth(line2, width),
					];
				},
			};
		});
	});
}

function formatCwd(cwd: string): string {
	const home = process.env.HOME;
	if (home && cwd.startsWith(home)) {
		return `~${cwd.slice(home.length)}`;
	}
	return cwd;
}

function getBlockTime(): string | null {
	// Try to read from pi-codex-status cache
	try {
		const home = process.env.HOME ?? "";
		const cachePath = join(home, ".cache/pi-codex-status/usage.json");
		const data = JSON.parse(readFileSync(cachePath, "utf8"));

		// Look for the primary 5h limit reset time
		const resetAt = data?.defaultLimit?.primary?.resetAt
			?? data?.primaryResetAt
			?? data?.resetAt;

		if (resetAt) {
			const resetTime = typeof resetAt === "number" ? resetAt * 1000 : new Date(resetAt).getTime();
			const now = Date.now();
			const remaining = resetTime - now;
			if (remaining > 0) {
				return formatDuration(remaining);
			}
		}
	} catch {
		// Cache doesn't exist or is unreadable
	}
	return null;
}

function formatDuration(ms: number): string {
	const totalSeconds = Math.floor(ms / 1000);
	const hours = Math.floor(totalSeconds / 3600);
	const minutes = Math.floor((totalSeconds % 3600) / 60);
	if (hours > 0) {
		return `${hours}hr ${minutes}m`;
	}
	return `${minutes}m`;
}
