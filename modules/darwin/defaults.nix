{ vars, lib, ... }:
let
  # Pinned Dock apps, in order, as captured from the Mac. Also used below to
  # decide whether the Dock needs a second restart on a fresh machine.
  dockApps = [
    "/System/Applications/Apps.app"
    "/System/Applications/Photos.app"
    "/System/Applications/Messages.app"
    "/System/Applications/Calendar.app"
    "/System/Applications/Contacts.app"
    "/System/Applications/Reminders.app"
    "/System/Applications/Notes.app"
    "/System/Applications/iPhone Mirroring.app"
    "/System/Applications/App Store.app"
    "/System/Applications/News.app"
    "/Applications/Firefox.app"
    "/System/Applications/System Settings.app"
    "/Applications/Discord.app"
    "/Applications/Visual Studio Code.app"
  ];
in
{
  # Captured from `defaults read` on 2026-08-20 so the first rebuild changes
  # nothing you didn't already have. Flip values here to change the machine.
  # Option list: https://nix-darwin.github.io/nix-darwin/manual/
  system.defaults = {
    dock = {
      autohide = false;
      tilesize = 59;
      show-recents = true;
      mru-spaces = true;
      wvous-br-corner = 14; # bottom-right hot corner: Quick Note

      # Recents (the section after the divider) stay dynamic because
      # show-recents is on.
      persistent-apps = dockApps;
      persistent-others = [
        {
          folder = {
            path = "/Users/${vars.username}/Downloads";
            arrangement = "date-added";
            displayas = "stack";
            showas = "fan";
          };
        }
      ];
    };

    finder = {
      AppleShowAllFiles = true;
      FXPreferredViewStyle = "Nlsv"; # list view
      # Home, not Recents: the folder default view (list) only applies when a
      # folder opens in a fresh window, and a window keeps its current view
      # as you navigate. Recents is a search, not a folder, so it ignored the
      # default and every path opened from it inherited icon view.
      NewWindowTarget = "Home";
      ShowStatusBar = false;
      ShowPathbar = false;
      _FXShowPosixPathInTitle = true; # full path in the window title, not just the folder name
      ShowExternalHardDrivesOnDesktop = true;
      ShowHardDrivesOnDesktop = false;
      ShowRemovableMediaOnDesktop = true;
      FXRemoveOldTrashItems = true; # empty trash after 30 days
      FXEnableExtensionChangeWarning = false; # no "are you sure" on rename
    };

    NSGlobalDomain = {
      # Finder > Settings > Advanced > "Show all filename extensions". This
      # is a global key: Finder, and the Open and Save panels of every app,
      # read it from NSGlobalDomain. nix-darwin also offers it under
      # finder.*, but that writes com.apple.finder, which the fresh machine
      # ignored (extensions stayed hidden). Finder is restarted in
      # postActivation below, so it picks the value up on the same rebuild.
      AppleShowAllExtensions = true;
      AppleInterfaceStyle = "Dark";
      AppleInterfaceStyleSwitchesAutomatically = false;
      # Icon & widget style and folder colour are left at their defaults
      # (keys absent), so they are deliberately not declared here.
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      "com.apple.swipescrolldirection" = false; # natural scrolling OFF
      "com.apple.trackpad.forceClick" = true;
      "com.apple.springing.enabled" = true;
      "com.apple.springing.delay" = 0.5;
    };

    trackpad = {
      Clicking = false; # tap to click OFF
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = false;
    };

    screencapture = {
      show-thumbnail = true;
      # Absolute on purpose: nix-darwin writes the string verbatim. The folder
      # is created by modules/home/default.nix.
      location = "/Users/${vars.username}/Pictures/Screenshots";
      type = "png";
      disable-shadow = true; # no drop shadow on window captures
    };

    # Require the password immediately when the screen locks or the saver stops.
    screensaver = {
      askForPassword = true;
      askForPasswordDelay = 0;
    };

    loginwindow.GuestEnabled = false;

    # "Displays have separate Spaces" OFF: the Dock and menu bar stay on the
    # main display instead of following the pointer to whichever monitor it
    # touches the bottom of. nix-darwin's naming is inverted relative to
    # System Settings: true means one Space spans all displays. Written on
    # every rebuild, but macOS only reads it at login, so a logout is needed
    # once (README, manual steps).
    spaces.spans-displays = true;

    CustomUserPreferences = {
      "com.apple.AdLib".allowApplePersonalizedAdvertising = false;
      # Recents (a saved search) keeps its own view style; nix-darwin has no
      # option for it. Undocumented key, found next to its *Version marker in
      # the captured defaults and verified on macOS 26.
      "com.apple.finder".SearchRecentsSavedViewStyle = "Nlsv";
    };
  };

  # nix-darwin writes the Dock and restarts it in its userDefaults step, which
  # runs BEFORE the homebrew step installs casks. On a fresh machine the apps
  # pinned above don't exist yet at that restart, so the Dock shows "?" tiles
  # until its next restart. All activation fragments run in one shell, so a
  # variable set here is still visible in postActivation below.
  system.activationScripts.preActivation.text = ''
    dockRestartAfterHomebrew=
    for app in ${lib.escapeShellArgs dockApps}; do
      if [ ! -e "$app" ]; then
        dockRestartAfterHomebrew=1
        break
      fi
    done
  '';

  system.activationScripts.postActivation.text = ''
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

    # nix-darwin restarts the Dock after writing defaults but never Finder,
    # which only reads com.apple.finder at launch. Without this, a running
    # Finder keeps its old view style and title until the next login.
    # Costs any open Finder windows on each rebuild.
    #
    # A per-folder view saved in /Applications/.DS_Store beats
    # finder.FXPreferredViewStyle (a fresh macOS 26 has no such file). Drop
    # it so the folder always follows the declared default; a hand-changed
    # view is reset on the next rebuild. Only this folder is touched.
    rm -f /Applications/.DS_Store
    killall -qu ${lib.escapeShellArg vars.username} Finder || true

    if [ -n "$dockRestartAfterHomebrew" ]; then
      echo >&2 "restarting Dock again: pinned apps were installed after its first restart"
      killall -qu ${lib.escapeShellArg vars.username} Dock || true
    fi
  '';
}
