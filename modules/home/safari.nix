{ lib, ... }:
{
  # Safari must not offer to save or fill passwords, addresses and cards;
  # 1Password does that. The keys live in the com.apple.Safari domain, but
  # Safari is sandboxed, so its preferences are in
  # ~/Library/Containers/com.apple.Safari/Data/Library/Preferences.
  # `defaults` follows the domain into the container (macOS 10.15+), which is
  # what nix-darwin's CustomUserPreferences would run too. The catch is TCC:
  # that container is only readable and writable by a process whose
  # responsible app has Full Disk Access, and nix-darwin's activation runs
  # with `set -e`, so a missing grant would abort every rebuild. This step
  # does the same writes itself, only when the terminal has Full Disk Access
  # and only for keys that differ; otherwise it warns, opens the Privacy
  # pane, and moves on. Quit Safari before a rebuild that changes these.
  # Verify with `defaults read com.apple.Safari AutoFillPasswords` (0).
  home.activation.safariAutoFill = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # ~/Library/Safari is TCC-protected: listing it succeeds only with Full
    # Disk Access, fails with "Operation not permitted" without it, and is
    # simply missing until Safari has been launched once.
    if err="$(/bin/ls "$HOME/Library/Safari" 2>&1 >/dev/null)"; then
      for key in AutoFillPasswords AutoFillFromAddressBook AutoFillCreditCardData; do
        if [ "$(/usr/bin/defaults read com.apple.Safari "$key" 2>/dev/null)" != 0 ]; then
          echo "safari: $key = false"
          run /usr/bin/defaults write com.apple.Safari "$key" -bool false
        fi
      done
    elif [ "''${err#*Operation not permitted}" != "$err" ]; then
      echo "safari: this terminal has no Full Disk Access, so Safari's AutoFill settings were not written" >&2
      echo "safari: System Settings > Privacy & Security > Full Disk Access: add the terminal app, open a new window, run drs again" >&2
      /usr/bin/open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" || true
    else
      echo "safari: ~/Library/Safari does not exist yet (launch Safari once); skipping" >&2
    fi
  '';
}
