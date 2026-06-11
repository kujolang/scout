#!/usr/bin/env bash

is_valid_kujo_runtime() {
	local bin_path="$1"
	"$bin_path" run --help >/dev/null 2>&1
}

resolve_kujo_bin() {
	local repo_root="${1:-$(pwd)}"
	local candidate=""

	if [[ -n "${KUJO_BIN:-}" ]]; then
		if [[ "$KUJO_BIN" == */* ]]; then
			if [[ ! -x "$KUJO_BIN" ]]; then
				echo "KUJO_BIN points to a non-executable path: $KUJO_BIN" >&2
				exit 1
			fi
			candidate="$KUJO_BIN"
		else
			if ! command -v "$KUJO_BIN" >/dev/null 2>&1; then
				echo "KUJO_BIN command not found: $KUJO_BIN" >&2
				exit 1
			fi
			candidate="$(command -v "$KUJO_BIN")"
		fi

		if ! is_valid_kujo_runtime "$candidate"; then
			echo "KUJO_BIN does not support the Kujo script runtime ('kujo run'): $candidate" >&2
			exit 1
		fi

		KUJO_BIN="$candidate"
		export KUJO_BIN
		return
	fi

	local sibling_debug_bin="$repo_root/../kujo/target/debug/kujo"
	if [[ -x "$sibling_debug_bin" ]] && is_valid_kujo_runtime "$sibling_debug_bin"; then
		KUJO_BIN="$sibling_debug_bin"
		export KUJO_BIN
		return
	fi

	if command -v kujo >/dev/null 2>&1; then
		candidate="$(command -v kujo)"
		if is_valid_kujo_runtime "$candidate"; then
			KUJO_BIN="$candidate"
			export KUJO_BIN
			return
		fi
	fi

	echo "Unable to locate a compatible Kujo runtime. Set KUJO_BIN to a binary that supports 'kujo run'." >&2
	exit 1
}
