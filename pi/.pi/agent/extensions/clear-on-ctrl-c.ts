/**
 * clear-on-ctrl-c
 *
 * Ctrl+C clears the input box when it has text.
 * When the box is already empty, Ctrl+C falls through to pi's default
 * behavior (abort running agent, copy selection, etc.).
 */

import { CustomEditor, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { matchesKey } from "@earendil-works/pi-tui";

class ClearOnCtrlCEditor extends CustomEditor {
	handleInput(data: string): void {
		if (matchesKey(data, "ctrl+c") && this.getText().length > 0) {
			this.setText("");
			return;
		}
		super.handleInput(data);
	}
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_event, ctx) => {
		ctx.ui.setEditorComponent((tui, theme, kb) => new ClearOnCtrlCEditor(tui, theme, kb));
	});
}
