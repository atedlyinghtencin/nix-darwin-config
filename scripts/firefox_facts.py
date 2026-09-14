#!/usr/bin/env python3
"""Gather Firefox add-ons and settings for declaring in this repo.

Run in macOS Terminal (NOT in the devcontainer):  ./scripts/firefox_facts.py
Read-only. Writes into ./mac-facts/:
  firefox-addons.txt    user-installed extensions (id, name, source, on/off)
  firefox-prefs.txt     every about:config value you changed, grouped by
                        whether the Preferences policy can set it
  firefox-policies.txt  policies already in effect (defaults + policies.json)
  firefox.nix           merge into modules/darwin/firefox.nix, then prune
Only prefs.js, user.js, extensions.json and profiles.ini are read from the
profile. Sessions, history, cookies and logins are never touched.
"""
import argparse
import configparser
import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
POLICY_SOURCES = (
    ("defaults read org.mozilla.firefox (user)", ["defaults", "read", "org.mozilla.firefox"]),
    ("defaults read /Library/Preferences/org.mozilla.firefox (system)",
     ["defaults", "read", "/Library/Preferences/org.mozilla.firefox"]),
    ("/Applications/Firefox.app/Contents/Resources/distribution/policies.json",
     ["cat", "/Applications/Firefox.app/Contents/Resources/distribution/policies.json"]),
)

# Prefixes/names the Firefox `Preferences` policy accepts, copied from
# browser/components/enterprisepolicies/Policies.sys.mjs (2026-09).
ALLOWED_PREFIXES = (
    "accessibility.", "alerts.", "app.update.", "browser.", "datareporting.policy.",
    "devtools.", "dom.", "extensions.", "general.autoScroll", "general.smoothScroll",
    "geo.", "gfx.", "identity.fxaccounts.toolbar.", "intl.", "keyword.enabled",
    "layers.", "layout.", "mathml.disabled", "media.", "network.", "pdfjs.",
    "places.", "pref.", "print.", "privacy.baselineFingerprintingProtection",
    "privacy.fingerprintingProtection", "privacy.globalprivacycontrol.enabled",
    "privacy.userContext.enabled", "privacy.userContext.ui.enabled", "sidebar.",
    "signon.", "spellchecker.", "svg.context-properties.content.enabled",
    "svg.disabled", "toolkit.legacyUserProfileCustomizations.stylesheets", "ui.",
    "webgl.disabled", "webgl.force-enabled", "widget.", "xpinstall.enabled",
    "xpinstall.whitelist.required",
)
ALLOWED_SECURITY = frozenset({
    "security.block_fileuri_script_with_wrong_mime", "security.csp.reporting.enabled",
    "security.default_personal_cert", "security.disable_button.openCertManager",
    "security.disable_button.openDeviceManager",
    "security.insecure_connection_text.enabled",
    "security.insecure_connection_text.pbmode.enabled",
    "security.mixed_content.block_active_content",
    "security.mixed_content.block_display_content",
    "security.mixed_content.upgrade_display_content", "security.osclientcerts.autoload",
    "security.OCSP.enabled", "security.OCSP.require",
    "security.pki.certificate_transparency.disable_for_hosts",
    "security.pki.certificate_transparency.disable_for_spki_hashes",
    "security.pki.certificate_transparency.mode", "security.ssl.enable_ocsp_stapling",
    "security.ssl.errorReporting.enabled", "security.ssl.require_safe_negotiation",
    "security.storage.encryption.sqlite.enabled", "security.tls.enable_0rtt_data",
    "security.tls.hello_downgrade_check", "security.tls.version.enable-deprecated",
    "security.warn_submit_secure_to_insecure",
    "security.webauthn.always_allow_direct_attestation",
})
BLOCKED = frozenset({
    "app.update.channel", "app.update.lastUpdateTime", "app.update.migrated",
    "browser.vpn_promo.disallowed_regions",
})

# Prefs Firefox writes for itself (timestamps, counters, ids, migration marks).
# They still appear in firefox-prefs.txt under "noise"; they never reach Nix.
NOISE = re.compile(r"""
    # bookkeeping leaves: timestamps, counters, ids, one-time flags, UI state
    (last(Update|update|Run|Check|Success|Version|AppVersion|AppBuildId|PlatformVersion
         |ColdStartupCheck|DailyNotification|Maintenance|MigrateDatabase|Dir|Active|Fetch
         |Epoch|Date|Submission|Sync|UrlbarSearchSeconds)
     |lastupdatetime|nextupdatetime|last_check|migrationVersion|migration\.version|impressionId
     |previousBuildID|previous_version|sessionCount|startup_count|schema-version
     |databaseSchema|storageVersion|prefs-schema-version|tempDirSuffix|userAgentID
     |user_id|cachedClientID|cachedProfileGroupID|cachedUsage|dataSubmissionPolicy
     |first_run|firstRun|first-seen|firstContentShown|everOpened|didSee\w*|hasMigrated\w*
     |was_ever_enabled|has-used|hasUsed|has_used|dismissed|migrated|migrationNeeded|restoreDone
     |seen$|shown$|Shown$|Count$|count$|attempts$|version$|buildID$|mstone$|region$|scenario$
     |nimbus$|onboardingTimes$|placeholderName|totalSearches|timesShown\w*|Checkpoint$
     |[sS]tate$|Cache$|cachedTiles|cacheValidFor|columnsData|visibleColumns|panes-search-height
     |mostRecentDateSetAsDefault|couldRestoreSession|typeWasRegistered
     |restore_default_bookmarks|installedDistroAddon|pendingOperations|webextensions\.uuids
     |ExtensionStorageIDB|systemAddonSet|persistedActions|upgradeBackup|homepage_override
     |addedImportButton|defaultLocation|cleanup\w*$|perform_injections|enable_picture_in_picture_overrides
     |mostRecentTargetLanguages|pollLiveMs|\.badge\.|trainhop|termsofuse|preonboarding
     |aboutwelcome|engagement|crashReports|serpEvent|activity-stream\.telemetry)
  | ^(app\.normandy|app\.shield|app\.update\.(background|download|elevate|lockedOut)
      |browser\.laterrun|browser\.migration|browser\.region|browser\.rights
      |browser\.safebrowsing\.provider|browser\.pagethumbnails|browser\.contextual-services
      |browser\.newtabpage\.activity-stream\.asrouter
      |browser\.newtabpage\.activity-stream\.discoverystream\.(?!enabled$)
      |browser\.newtabpage\.activity-stream\.newtabWallpapers\.\S*migrated
      |browser\.messaging-system|browser\.ping-centre|browser\.proton\.toolbar
      |browser\.firefox-view|browser\.protections_panel|browser\.contentblocking\.(cfr|report)
      |browser\.shell\.didSkip|browser\.search\.region|browser\.ipProtection\.(added|\w*Cache)
      |browser\.urlbar\.(tipShownCount|quicksuggest\.(migrationVersion|scenario)|recentsearches|quickactions)
      |browser\.cache\.disk\.(capacity|amount_written|smart_size)
      |services\.(sync|settings)|toolkit\.telemetry|toolkit\.startup|toolkit\.profiles
      |extensions\.(blocklist|getAddons\.cache|remoteSettings|ui\.|quarantinedDomains\.list
                    |colorway|signatureCheckpoint)
      |devtools\.(netmonitor\.(msg|panes)|performance\.recording|toolsidebar|selfxss
                  |toolbox\.(footer|host|previousHost|selectedTool))
      |sidebar\.(backupState|notification|old-sidebar)|signon\.(rustMirror|storage\.rust)
      |identity\.fxaccounts\.account\.
      |security\.remote_settings|media\.gmp|media\.videocontrols|gecko\.handlerService|idle\.
      |distribution\.|doh-rollout|storage\.vacuum|network\.cookie\.(CHIPS|validation)
      |font\.internaluseonly|privacy\.purge_trackers|privacy\.sanitize\.pending
      |datareporting\.(policy\.data|dau)|captchadetection|nimbus|messaging-system-action
      |trailhead|screenshots\.browser\.component\.last|pdfjs\.enabledCache)
""", re.VERBOSE)

# Prefs the Preferences policy refuses but that have a dedicated policy instead.
POLICY_FOR = {
    "datareporting.healthreport.uploadEnabled": "use DisableTelemetry",
    "toolkit.telemetry.enabled": "use DisableTelemetry",
    "privacy.trackingprotection.enabled": "use EnableTrackingProtection",
    "privacy.sanitize.sanitizeOnShutdown": "use SanitizeOnShutdown",
    "identity.fxaccounts.enabled": "use DisableFirefoxAccounts",
    "privacy.donottrackheader.enabled": "no policy either; Firefox dropped DNT in 2025",
}

AMO_LATEST = "https://addons.mozilla.org/firefox/downloads/latest/{id}/latest.xpi"
PREF_LINE = re.compile(r'^\s*user_pref\("((?:[^"\\]|\\.)*)",\s*(.*?)\);\s*(?://.*)?$', re.M)


# ---------------------------------------------------------------- parsing

def parse_prefs(text):
    """user_pref("name", value); lines -> {name: value}. Values are JSON."""
    prefs = {}
    for name, raw in PREF_LINE.findall(text):
        try:
            prefs[name] = json.loads(raw)
        except json.JSONDecodeError:
            prefs[name] = raw  # leave anything odd as the literal text
    return prefs


def merge_prefs(prefs_json, user_js):
    """user.js is applied on top of prefs.js at every Firefox start."""
    return {**prefs_json, **user_js}


def parse_addons(text):
    """extensions.json -> user-installed extensions only (no themes/builtins)."""
    try:
        addons = json.loads(text).get("addons", [])
    except (json.JSONDecodeError, AttributeError) as e:
        raise SystemExit(f"extensions.json is not valid JSON: {e}")
    keep = [a for a in addons if isinstance(a, dict) and a.get("id")
            and a.get("type") == "extension" and a.get("location") == "app-profile"
            and not a["id"].endswith(("@mozilla.org", "@mozilla.com"))]
    return [{
        "id": a["id"],
        "name": (a.get("defaultLocale") or {}).get("name") or a["id"],
        "version": a.get("version", "?"),
        "sourceURI": a.get("sourceURI") or "",
        "enabled": bool(a.get("active")) and not a.get("userDisabled"),
    } for a in sorted(keep, key=lambda a: a["id"].lower())]


def default_profile(root):
    """Resolve the default profile dir from profiles.ini (Install section wins)."""
    ini = configparser.ConfigParser(strict=False, interpolation=None)
    try:
        ini.read(root / "profiles.ini")
    except configparser.Error as e:
        raise SystemExit(f"profiles.ini is unreadable: {e}")
    for s in ini.sections():
        if s.startswith("Install") and ini[s].get("Default"):
            return root / ini[s]["Default"]
    profiles = [ini[s] for s in ini.sections() if s.startswith("Profile")]
    chosen = next((p for p in profiles if p.get("Default") == "1"), profiles[0] if profiles else None)
    if chosen is None:
        raise SystemExit(f"no profiles listed in {root / 'profiles.ini'}")
    path = Path(chosen["Path"])
    return root / path if chosen.get("IsRelative", "1") == "1" else path


# ---------------------------------------------------------------- classify

def is_noise(name):
    return bool(NOISE.search(name))


def policy_status(name):
    """'allowed' | 'blocked' | 'not-allowed' for the Preferences policy."""
    if name in BLOCKED:
        return "blocked"
    if name in ALLOWED_SECURITY or name.startswith(ALLOWED_PREFIXES):
        return "allowed"
    return "not-allowed"


# ---------------------------------------------------------------- rendering

def nix_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    s = str(v).replace("\\", "\\\\").replace('"', '\\"').replace("${", "\\${")
    return f'"{s}"'


def _addon_lines(a):
    from_amo = "addons.mozilla.org" in a["sourceURI"]
    url = AMO_LATEST.format(id=a["id"]) if from_amo else a["sourceURI"]
    note = "" if from_amo else "  # not from addons.mozilla.org: pinned to the file you installed"
    lines = [
        f'"{a["id"]}" = {{  # {a["name"]} {a["version"]}',
        '  installation_mode = "normal_installed";',
        f'  install_url = {nix_value(url)};{note}',
        "};",
    ]
    if not a["enabled"]:
        lines[0] += "  (disabled in Firefox; enable by uncommenting)"
        lines = ["# " + l for l in lines]
    return lines


def render_addons(addons):
    out = []
    for a in addons:
        if not a["sourceURI"]:
            out.append(f'# "{a["id"]}" = ...;  # {a["name"]}: no install source recorded, add install_url by hand')
            continue
        out.extend(_addon_lines(a))
    return "\n".join(out)


def render_prefs(prefs):
    out = []
    for name in sorted(prefs):
        if is_noise(name):
            continue
        status = policy_status(name)
        line = f'"{name}" = {{ Value = {nix_value(prefs[name])}; Status = "user"; }};'
        if status != "allowed":
            hint = POLICY_FOR.get(name)
            line = f"# {line}  # {status} by the Preferences policy" + (f"; {hint}" if hint else "")
        out.append(line)
    return "\n".join(out)


def _indent(block, n):
    pad = " " * n
    return "\n".join(pad + l if l else l for l in block.splitlines())


def render_nix(addons, prefs):
    return (
        '"org.mozilla.firefox" = {\n'
        "  EnterprisePoliciesEnabled = true;\n"
        "  # normal_installed: auto-installed, you can still disable/remove it.\n"
        "  # force_installed: same, but locked.\n"
        "  ExtensionSettings = {\n"
        f"{_indent(render_addons(addons), 4)}\n"
        "  };\n"
        '  # Status = "user" re-applies the value at every start; "locked" also greys it out.\n'
        "  Preferences = {\n"
        f"{_indent(render_prefs(prefs), 4)}\n"
        "  };\n"
        "};\n"
    )


def render_addons_txt(profile, addons):
    rows = [f"profile: {profile}", f"user-installed extensions: {len(addons)}", ""]
    rows += [f'{"on " if a["enabled"] else "OFF"}  {a["id"]:<45} {a["name"]} {a["version"]}\n'
             f'     {a["sourceURI"] or "(no source recorded)"}' for a in addons]
    return "\n".join(rows) + "\n"


def render_prefs_txt(profile, prefs):
    groups = {"allowed": [], "not-allowed": [], "blocked": [], "noise": []}
    for name in sorted(prefs):
        groups["noise" if is_noise(name) else policy_status(name)].append(name)
    out = [f"profile: {profile}", f"modified prefs: {len(prefs)}", ""]
    titles = {
        "allowed": "### settable via the Preferences policy (in firefox.nix)",
        "not-allowed": "### changed by you, but the policy refuses these names (commented in firefox.nix)",
        "blocked": "### explicitly blocked by Firefox",
        "noise": "### Firefox-managed state (timestamps, ids, counters); not worth declaring",
    }
    for key, names in groups.items():
        out += [titles[key]] + [f"{n} = {json.dumps(prefs[n])}" for n in names] + [""]
    return "\n".join(out)


# ---------------------------------------------------------------- main

def _read(path):
    return path.read_text(encoding="utf-8") if path.exists() else ""


def collect_policies(sources=POLICY_SOURCES):
    """What Firefox is already being told by defaults/policies.json, if anything."""
    chunks = []
    for title, cmd in sources:
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            body = (r.stdout + r.stderr).strip() or f"(exit {r.returncode}, no output)"
        except (OSError, subprocess.TimeoutExpired) as e:
            body = f"(could not run {cmd[0]}: {e})"
        chunks.append(f"### {title}\n{body}\n")
    return "\n".join(chunks)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=REPO / "mac-facts", help="report directory (default: ./mac-facts)")
    ap.add_argument("--profile", help="profile dir (default: from profiles.ini)")
    ap.add_argument("--root", default=Path.home() / "Library/Application Support/Firefox")
    args = ap.parse_args(argv)

    root = Path(args.root)
    if not (root / "profiles.ini").exists() and not args.profile:
        sys.exit(f"Firefox has never been run here: {root / 'profiles.ini'} missing")
    profile = Path(args.profile) if args.profile else default_profile(root)
    if not profile.is_dir():
        sys.exit(f"profile directory not found: {profile}")

    prefs = merge_prefs(parse_prefs(_read(profile / "prefs.js")), parse_prefs(_read(profile / "user.js")))
    addons = parse_addons(_read(profile / "extensions.json") or "{}")

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    (out / "firefox-addons.txt").write_text(render_addons_txt(profile, addons))
    (out / "firefox-prefs.txt").write_text(render_prefs_txt(profile, prefs))
    (out / "firefox.nix").write_text(render_nix(addons, prefs))
    (out / "firefox-policies.txt").write_text(collect_policies())
    declared = sum(1 for n in prefs if not is_noise(n) and policy_status(n) == "allowed")
    print(f"profile {profile}\n{len(addons)} extensions, {len(prefs)} modified prefs ({declared} declarable)")
    print(f"wrote {out}/firefox-{{addons,prefs,policies}}.txt and {out}/firefox.nix")
    print("review firefox-prefs.txt, merge firefox.nix into modules/darwin/firefox.nix, run drs")


if __name__ == "__main__":
    main()
