{ lib, ... }:
{
  # Firefox writes a compressed JSON snapshot of all bookmarks into
  # <profile>/bookmarkbackups once a day (during idle time, or at shutdown if
  # it has not happened yet) and keeps the newest browser.bookmarks.max_backups
  # (15). Point that directory at Proton Drive so the snapshots leave the
  # machine. One-way: restore by hand in Firefox (Bookmarks → Manage Bookmarks
  # → Import and Backup → Restore), see docs/RUNBOOK.md. Nothing else in the
  # profile is touched; history, logins and tabs stay local.
  #
  # Proton Drive's File Provider folder is named after the account, so it is
  # found by pattern instead of being declared here. Skipped, with a message,
  # until both Firefox and Proton Drive have been launched once.
  home.activation.firefoxBookmarkBackups = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    firefox_root="$HOME/Library/Application Support/Firefox"
    ini="$firefox_root/profiles.ini"
    drive="$(/bin/ls -d "$HOME/Library/CloudStorage/ProtonDrive-"* 2>/dev/null | head -n 1 || true)"

    if [ ! -f "$ini" ]; then
      echo "firefox-backups: Firefox has not been launched yet; skipping" >&2
    elif [ -z "$drive" ]; then
      echo "firefox-backups: no ProtonDrive-* folder in ~/Library/CloudStorage; skipping" >&2
    else
      # Default profile, resolved like Firefox does: the [Install*] section
      # wins, otherwise the [Profile*] section with Default=1.
      profile="$(/usr/bin/awk -F= '
        function flush() { if (sect == "profile" && def == "1") fb = (rel == "0" ? "" : root "/") path }
        /^\[/ { flush(); sect = ($0 ~ /^\[Install/) ? "install" : ($0 ~ /^\[Profile/) ? "profile" : ""; path = ""; rel = "1"; def = "0"; next }
        sect == "install" && $1 == "Default" { inst = root "/" $2 }
        sect == "profile" && $1 == "Path" { path = $2 }
        sect == "profile" && $1 == "IsRelative" { rel = $2 }
        sect == "profile" && $1 == "Default" { def = $2 }
        END { flush(); print (inst != "" ? inst : fb) }
      ' root="$firefox_root" "$ini")"
      backups="$profile/bookmarkbackups"
      target="$drive/Firefox/bookmarkbackups"

      if [ ! -d "$profile" ]; then
        echo "firefox-backups: profile directory not found: $profile; skipping" >&2
      elif [ "$(readlink "$backups" 2>/dev/null)" = "$target" ]; then
        : # already linked
      elif [ -d "$backups" ] && [ ! -L "$backups" ] && /usr/bin/pgrep -x firefox >/dev/null; then
        # Moving the directory out from under a running Firefox could lose a
        # snapshot in flight; the first link is made with Firefox closed.
        echo "firefox-backups: quit Firefox and run drs again to move bookmark backups to Proton Drive" >&2
      else
        echo "firefox-backups: sending bookmark backups to $target"
        run mkdir -p "$target"
        if [ -d "$backups" ] && [ ! -L "$backups" ]; then
          # Keep snapshots made before the link existed; never overwrite a
          # copy that is already in Proton Drive.
          run cp -pn "$backups"/*.jsonlz4 "$target"/ 2>/dev/null || true
          run rm -rf "$backups"
        elif [ -L "$backups" ]; then
          run rm -f "$backups"
        fi
        run ln -s "$target" "$backups"
      fi
    fi
  '';
}
