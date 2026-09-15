{ lib, ... }:
{
  # A Terminal.app profile with "JetBrainsMono Nerd Font", so the prompt's
  # Nerd Font glyphs (starship, eza icons) render instead of boxes. Terminal
  # keeps the font as an NSKeyedArchiver blob inside each profile, not as a
  # plain defaults key, so the profile ships as a .terminal file and is
  # imported by opening it. That registers the profile and opens one window
  # with it, which only happens while the profile is missing.
  #
  # terminal/nix-darwin.terminal is the "Clear Dark" profile exported from
  # the Mac on 2026-09-16 (colours, blur, spacing, 120 x 30), renamed so it
  # never collides with the profile Terminal ships under that name, with the
  # font archive changed from SF Mono 12 pt to JetBrainsMonoNF-Regular 12 pt.
  # Everything else in the profile is exactly the export. To change it,
  # export again from Terminal > Settings > Profiles > gear > Export and
  # redo those two edits (scripts: plistlib handles both).
  #
  # The two default-profile keys are plain strings. They are written here
  # rather than through system.defaults.CustomUserPreferences so they land
  # after the import: nix-darwin's userDefaults step runs before
  # home-manager, and a default naming a profile Terminal has not seen yet
  # falls back to Basic. Already-open windows keep their old profile.
  home.activation.terminalProfile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    profile=${./terminal/nix-darwin.terminal}
    if ! /usr/bin/defaults read com.apple.Terminal "Window Settings" 2>/dev/null | grep -qE '^ *"?nix-darwin"? = '; then
      echo "terminal: importing the nix-darwin profile (opens one Terminal window)"
      run /usr/bin/open "$profile" || echo "terminal: could not open $profile" >&2
    fi
    for key in "Default Window Settings" "Startup Window Settings"; do
      if [ "$(/usr/bin/defaults read com.apple.Terminal "$key" 2>/dev/null)" != nix-darwin ]; then
        echo "terminal: $key = nix-darwin"
        run /usr/bin/defaults write com.apple.Terminal "$key" -string nix-darwin
      fi
    done
  '';
}
