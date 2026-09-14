#!/usr/bin/env python3
"""Unit tests for firefox_facts.py. Run: python3 -m unittest discover -s scripts"""
import json
import tempfile
import unittest
from pathlib import Path

import firefox_facts as ff

PREFS_JSON = '''// Mozilla User Preferences
user_pref("browser.startup.page", 3);
user_pref("browser.tabs.warnOnClose", false);
user_pref("browser.download.dir", "/Users/me/Downloads");
user_pref("app.normandy.user_id", "abc-123");
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("app.update.channel", "release");
user_pref("general.autoScroll", true);
user_pref("layout.css.devPixelsPerPx", "1.25");
'''

USER_JS = '''user_pref("browser.startup.page", 1);
user_pref("privacy.resistFingerprinting", true);
'''


def addon(**kw):
    base = {
        "id": "uBlock0@raymondhill.net",
        "version": "1.62.0",
        "type": "extension",
        "location": "app-profile",
        "active": True,
        "userDisabled": False,
        "sourceURI": "https://addons.mozilla.org/firefox/downloads/file/1/ublock.xpi",
        "defaultLocale": {"name": "uBlock Origin"},
    }
    return {**base, **kw}


def parsed(*raw):
    """Raw extensions.json records -> what the renderers consume."""
    return ff.parse_addons(json.dumps({"addons": list(raw)}))


class ParsePrefs(unittest.TestCase):
    def test_parses_every_value_type(self):
        prefs = ff.parse_prefs(PREFS_JSON)
        self.assertEqual(prefs["browser.startup.page"], 3)
        self.assertIs(prefs["browser.tabs.warnOnClose"], False)
        self.assertEqual(prefs["browser.download.dir"], "/Users/me/Downloads")
        self.assertEqual(prefs["layout.css.devPixelsPerPx"], "1.25")

    def test_user_js_overrides_prefs_json(self):
        merged = ff.merge_prefs(ff.parse_prefs(PREFS_JSON), ff.parse_prefs(USER_JS))
        self.assertEqual(merged["browser.startup.page"], 1)
        self.assertIs(merged["privacy.resistFingerprinting"], True)


class ClassifyPrefs(unittest.TestCase):
    def test_noise_detection(self):
        self.assertTrue(ff.is_noise("app.normandy.user_id"))
        self.assertTrue(ff.is_noise("browser.safebrowsing.provider.mozilla.lastupdatetime"))
        self.assertFalse(ff.is_noise("browser.startup.page"))
        self.assertFalse(ff.is_noise("browser.newtabpage.activity-stream.discoverystream.enabled"))
        self.assertFalse(ff.is_noise("browser.topsites.contile.enabled"))
        self.assertTrue(ff.is_noise("browser.topsites.contile.cachedTiles"))
        # leaves seen on a real profile that must stay out of firefox.nix
        for name in ("browser.aboutwelcome.didSeeFinalScreen", "browser.topsites.contile.lastFetch",
                     "extensions.webextensions.ExtensionStorageIDB.migrated.uBlock0@raymondhill.net",
                     "browser.newtabpage.activity-stream.discoverystream.placements.spocs",
                     "browser.ipProtection.locationListCache", "browser.uiCustomization.state",
                     "devtools.toolbox.selectedTool", "signon.rustMirror.migrationNeeded",
                     "nimbus.profileId", "termsofuse.acceptedVersion", "app.update.download.attempts",
                     "identity.fxaccounts.account.device.name"):
            self.assertTrue(ff.is_noise(name), name)
        # real settings that must survive
        for name in ("browser.urlbar.suggest.searches", "browser.search.suggest.enabled",
                     "network.trr.mode", "signon.rememberSignons", "browser.ml.chat.enabled",
                     "browser.tabs.groups.smart.enabled", "extensions.formautofill.creditCards.enabled",
                     "browser.translations.alwaysTranslateLanguages", "privacy.globalprivacycontrol.enabled",
                     "browser.ipProtection.enabled", "findbar.highlightAll", "browser.contentblocking.category"):
            self.assertFalse(ff.is_noise(name), name)

    def test_policy_allow_list(self):
        self.assertEqual(ff.policy_status("browser.startup.page"), "allowed")
        self.assertEqual(ff.policy_status("general.autoScroll"), "allowed")
        self.assertEqual(ff.policy_status("security.OCSP.enabled"), "allowed")
        self.assertEqual(ff.policy_status("app.update.channel"), "blocked")
        self.assertEqual(ff.policy_status("privacy.resistFingerprinting"), "not-allowed")
        self.assertEqual(ff.policy_status("datareporting.healthreport.uploadEnabled"), "not-allowed")


class ParseAddons(unittest.TestCase):
    def test_keeps_only_user_installed_extensions(self):
        data = {"addons": [
            addon(),
            addon(id="theme@mozilla.org", type="theme"),
            addon(id="builtin@mozilla.org", location="app-system-defaults"),
            addon(id="newtab@mozilla.org"),  # system add-on that Firefox parks in the profile
        ]}
        got = ff.parse_addons(json.dumps(data))
        self.assertEqual([a["id"] for a in got], ["uBlock0@raymondhill.net"])
        self.assertEqual(got[0]["name"], "uBlock Origin")

    def test_malformed_json_exits_cleanly(self):
        with self.assertRaises(SystemExit):
            ff.parse_addons("{not json")

    def test_record_without_id_is_skipped(self):
        data = {"addons": [addon(), {"type": "extension", "location": "app-profile"}]}
        self.assertEqual(len(ff.parse_addons(json.dumps(data))), 1)


class RenderNix(unittest.TestCase):
    def test_string_escaping(self):
        self.assertEqual(ff.nix_value('a"b\\c${d}'), r'"a\"b\\c\${d}"')
        self.assertEqual(ff.nix_value(True), "true")
        self.assertEqual(ff.nix_value(7), "7")

    def test_addons_use_guid_latest_url(self):
        out = ff.render_addons(parsed(addon()))
        self.assertIn('"uBlock0@raymondhill.net" = {', out)
        self.assertIn("# uBlock Origin 1.62.0", out)
        self.assertIn('installation_mode = "normal_installed";', out)
        self.assertIn(
            'install_url = "https://addons.mozilla.org/firefox/downloads/latest/uBlock0@raymondhill.net/latest.xpi";',
            out,
        )

    def test_disabled_addon_is_commented_out(self):
        out = ff.render_addons(parsed(addon(userDisabled=True)))
        body = [l for l in out.splitlines() if "install_url" in l][0]
        self.assertTrue(body.lstrip().startswith("#"))
        self.assertIn("disabled", out)

    def test_non_amo_source_is_pinned(self):
        out = ff.render_addons(parsed(addon(sourceURI="https://example.com/x.xpi")))
        self.assertIn('install_url = "https://example.com/x.xpi";', out)
        self.assertIn("not from addons.mozilla.org", out)

    def test_prefs_block_marks_disallowed_and_drops_noise(self):
        prefs = ff.parse_prefs(PREFS_JSON)
        out = ff.render_prefs(prefs)
        self.assertIn('"browser.startup.page" = { Value = 3; Status = "user"; };', out)
        self.assertIn('# "app.update.channel"', out)
        self.assertIn('# "datareporting.healthreport.uploadEnabled"', out)
        self.assertNotIn("app.normandy.user_id", out)

    def test_refused_pref_names_its_dedicated_policy(self):
        out = ff.render_prefs({"datareporting.healthreport.uploadEnabled": False})
        self.assertIn("use DisableTelemetry", out)

    def test_full_block_is_one_domain(self):
        out = ff.render_nix(parsed(addon()), ff.parse_prefs(PREFS_JSON))
        self.assertTrue(out.startswith('"org.mozilla.firefox" = {'))
        self.assertIn("EnterprisePoliciesEnabled = true;", out)
        self.assertIn("ExtensionSettings = {", out)
        self.assertIn("Preferences = {", out)


class FindProfile(unittest.TestCase):
    def test_install_section_wins_over_default_flag(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "profiles.ini").write_text(
                "[Install1234]\nDefault=Profiles/b.default-release\nLocked=1\n\n"
                "[Profile0]\nName=old\nIsRelative=1\nPath=Profiles/a.default\nDefault=1\n\n"
                "[Profile1]\nName=new\nIsRelative=1\nPath=Profiles/b.default-release\n"
            )
            self.assertEqual(ff.default_profile(root), root / "Profiles/b.default-release")

    def test_garbage_profiles_ini_exits_cleanly(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "profiles.ini").write_text("this is not an ini file\n")
            with self.assertRaises(SystemExit):
                ff.default_profile(Path(d))

    def test_falls_back_to_default_flag(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "profiles.ini").write_text(
                "[Profile0]\nName=x\nIsRelative=1\nPath=Profiles/a\n\n"
                "[Profile1]\nName=y\nIsRelative=0\nPath=/abs/b\nDefault=1\n"
            )
            self.assertEqual(ff.default_profile(root), Path("/abs/b"))


class CollectPolicies(unittest.TestCase):
    def test_captures_output_and_survives_missing_commands(self):
        out = ff.collect_policies((
            ("echo works", ["echo", "hello"]),
            ("missing tool", ["definitely-not-a-command-xyz"]),
        ))
        self.assertIn("### echo works\nhello", out)
        self.assertIn("### missing tool\n(could not run", out)


if __name__ == "__main__":
    unittest.main()
