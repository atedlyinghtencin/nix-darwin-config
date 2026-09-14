{ lib, ... }:
{
  # Wallpaper: built-in colour "Black" with the Gradient toggle, on all
  # displays and Spaces. Since Sonoma this choice is not a `defaults` key or
  # an image file; it lives in the per-user wallpaper store, so the store file
  # captured from the Mac (scripts/collect-mac-facts.sh) is installed as-is.
  # The captured file is portable: "linked" type, no display or Space IDs.
  home.activation.wallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    store="$HOME/Library/Application Support/com.apple.wallpaper/Store"
    declared=${./wallpaper/Index.plist}

    # Compare the choice itself, not the whole file: WallpaperAgent rewrites
    # its LastUse timestamps, so a byte comparison would restart it on every
    # rebuild. A per-display or per-Space setup has no Linked key at all,
    # which reads as "differs" and gets replaced too.
    keypath=AllSpacesAndDisplays.Linked.Content
    current="$(/usr/bin/plutil -extract "$keypath" xml1 -o - "$store/Index.plist" 2>/dev/null || true)"
    if ! wanted="$(/usr/bin/plutil -extract "$keypath" xml1 -o - "$declared" 2>&1)"; then
      echo "wallpaper: declared Index.plist has no $keypath (re-capture with all Spaces linked): $wanted" >&2
      exit 1
    fi

    if [ "$current" != "$wanted" ]; then
      echo "setting wallpaper: Black, gradient, all Spaces"
      run mkdir -p "$store"
      run cp -f "$declared" "$store/Index.plist"
      run chmod 644 "$store/Index.plist" # store files are read-only; the agent must be able to write
      run /usr/bin/killall WallpaperAgent 2>/dev/null || true
    fi
  '';
}
