{ pkgs, lib, ... }:
{
  # nix-darwin has no option for the default browser. `defaultbrowser`
  # (nixpkgs, kerma/defaultbrowser) lists the registered HTTP handlers with
  # the current one marked "* " and sets a new one through LaunchServices.
  # macOS then shows a one-time "Do you want to change your default web
  # browser" dialog that cannot be suppressed without MDM; the change only
  # applies once it is accepted, so an ignored dialog means this runs again
  # on the next rebuild.
  #
  # Firefox comes from the Homebrew cask. nix-darwin's homebrew step runs
  # before postActivation, where home-manager lives, so on a fresh machine
  # the app exists by the time this runs. LaunchServices may still not list
  # it as a handler until its first launch; that case is reported and the
  # next drs finishes the job.
  home.packages = [ pkgs.defaultbrowser ];

  home.activation.defaultBrowser = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    defaultbrowser=${lib.getExe pkgs.defaultbrowser}
    handlers="$("$defaultbrowser" 2>/dev/null || true)"
    if [ ! -d /Applications/Firefox.app ]; then
      echo "default-browser: Firefox is not installed yet; skipping" >&2
    elif printf '%s\n' "$handlers" | grep -q '^\* firefox$'; then
      : # already the default
    elif ! printf '%s\n' "$handlers" | grep -q '^ *firefox$'; then
      echo "default-browser: LaunchServices does not list Firefox yet; launch it once and run drs again" >&2
    else
      echo "default-browser: making Firefox the default browser (accept the macOS dialog)"
      run "$defaultbrowser" firefox || echo "default-browser: defaultbrowser failed; continuing" >&2
    fi
  '';
}
