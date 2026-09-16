{ lib, ... }:
{
  # A Terminal.app profile with "JetBrainsMono Nerd Font", so the prompt's
  # Nerd Font glyphs (starship, eza icons) render instead of boxes. Terminal
  # keeps the font as an NSKeyedArchiver blob inside each profile, not as a
  # plain defaults key, so the profile ships as a .terminal file (an XML
  # plist of one profile) and is added to Terminal's "Window Settings"
  # dictionary with `defaults write -dict-add`, only while it is missing.
  # Not by opening the file: `open` imports it under the file's name (the
  # Nix store path gave "<hash>-nix-darwin") and opens a window every time.
  # Terminal reads the dictionary at launch, so the profile and the default
  # below appear after the next relaunch (quit with Cmd-Q, not just close).
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
  # after the profile itself: nix-darwin's userDefaults step runs before
  # home-manager, and a default naming a profile that does not exist yet
  # makes Terminal fall back to some other profile.
  home.activation.terminalProfile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    profile=${./terminal/nix-darwin.terminal}
    if ! /usr/bin/defaults read com.apple.Terminal "Window Settings" 2>/dev/null | grep -qE '^ *"?nix-darwin"? = '; then
      echo "terminal: adding the nix-darwin profile (quit and reopen Terminal to see it)"
      # the file's top-level <dict>...</dict>, which defaults parses as a plist value
      profile_xml="$(sed -n '/^<dict>/,/^<\/dict>/p' "$profile")"
      run /usr/bin/defaults write com.apple.Terminal "Window Settings" -dict-add nix-darwin "$profile_xml" \
        || echo "terminal: could not add the profile" >&2
    fi
    for key in "Default Window Settings" "Startup Window Settings"; do
      if [ "$(/usr/bin/defaults read com.apple.Terminal "$key" 2>/dev/null)" != nix-darwin ]; then
        echo "terminal: $key = nix-darwin"
        run /usr/bin/defaults write com.apple.Terminal "$key" -string nix-darwin
      fi
    done
  '';
}
