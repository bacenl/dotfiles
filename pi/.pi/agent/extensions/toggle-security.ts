/**
 * toggle-security
 *
 * Adds /toggle-security to temporarily switch Pi between the normal personal
 * settings profile and a generated security-off settings profile that omits
 * pi-secured-setup. The command reloads Pi so the package list takes effect.
 */

import { existsSync, lstatSync, mkdirSync, readFileSync, realpathSync, renameSync, symlinkSync, unlinkSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type Settings = {
	packages?: Array<string | { source?: string; [key: string]: unknown }>;
	[key: string]: unknown;
};

const home = process.env.HOME ?? "";
const agentDir = join(home, ".pi", "agent");
const settingsPath = join(agentDir, "settings.json");
const enabledSettingsPath = join(home, "dotfiles", "pi-personal", ".pi", "agent", "settings.json");
const disabledSettingsPath = join(agentDir, "settings.security-off.json");

function packageSource(pkg: string | { source?: string }): string | undefined {
	return typeof pkg === "string" ? pkg : pkg.source;
}

function isSecurityPackage(pkg: string | { source?: string }): boolean {
	const source = packageSource(pkg) ?? "";
	return /^git:github\.com\/mwolff44\/pi-secured-setup(?:@.*)?$/.test(source)
		|| /^https:\/\/github\.com\/mwolff44\/pi-secured-setup(?:\.git)?(?:#.*)?$/.test(source);
}

function readSettings(path: string): Settings {
	return JSON.parse(readFileSync(path, "utf8")) as Settings;
}

function currentSecurityEnabled(): boolean {
	try {
		const settings = readSettings(settingsPath);
		return (settings.packages ?? []).some(isSecurityPackage);
	} catch {
		return false;
	}
}

function currentTarget(): string | null {
	try {
		return realpathSync(settingsPath);
	} catch {
		return null;
	}
}

function replaceSettingsSymlink(target: string): string | null {
	mkdirSync(dirname(settingsPath), { recursive: true });

	let backup: string | null = null;
	if (existsSync(settingsPath)) {
		const stat = lstatSync(settingsPath);
		if (stat.isSymbolicLink()) {
			unlinkSync(settingsPath);
		} else {
			backup = `${settingsPath}.security-toggle-backup-${Date.now()}`;
			renameSync(settingsPath, backup);
		}
	}

	symlinkSync(target, settingsPath);
	return backup;
}

function writeDisabledSettings(): void {
	const basePath = existsSync(enabledSettingsPath) ? enabledSettingsPath : settingsPath;
	const settings = readSettings(basePath);
	settings.packages = (settings.packages ?? []).filter((pkg) => !isSecurityPackage(pkg));
	writeFileSync(disabledSettingsPath, `${JSON.stringify(settings, null, 2)}\n`, "utf8");
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("toggle-security", {
		description: "Toggle pi-secured-setup on/off by switching settings profiles and reloading Pi",
		handler: async (args, ctx) => {
			const action = args.trim().toLowerCase();
			const enabled = currentSecurityEnabled();

			if (action === "status") {
				const target = currentTarget();
				ctx.ui.notify(
					`pi-secured-setup is ${enabled ? "ON" : "OFF"}${target ? `\nsettings: ${target}` : ""}`,
					enabled ? "info" : "warning",
				);
				return;
			}

			const wantsOn = ["on", "enable", "enabled"].includes(action);
			const wantsOff = ["off", "disable", "disabled"].includes(action);
			if (action && !wantsOn && !wantsOff) {
				ctx.ui.notify("Usage: /toggle-security [on|off|status]", "warning");
				return;
			}

			if (wantsOn || (!action && !enabled)) {
				if (!existsSync(enabledSettingsPath)) {
					ctx.ui.notify(`Cannot enable security: missing ${enabledSettingsPath}`, "error");
					return;
				}
				const backup = replaceSettingsSymlink(enabledSettingsPath);
				ctx.ui.notify(
					`pi-secured-setup enabled. Reloading Pi...${backup ? `\nBacked up old settings to ${backup}` : ""}`,
					"info",
				);
				await ctx.reload();
				return;
			}

			if (wantsOff || (!action && enabled)) {
				writeDisabledSettings();
				const backup = replaceSettingsSymlink(disabledSettingsPath);
				ctx.ui.notify(
					`pi-secured-setup disabled. Reloading Pi...${backup ? `\nBacked up old settings to ${backup}` : ""}`,
					"warning",
				);
				await ctx.reload();
				return;
			}

			ctx.ui.notify(`pi-secured-setup is already ${enabled ? "ON" : "OFF"}.`, enabled ? "info" : "warning");
		},
	});
}
