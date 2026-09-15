{ lib, ... }:
{
  # Firefox reads the org.mozilla.firefox defaults domain as enterprise policy,
  # so the Homebrew cask stays as is and this block is applied on next launch.
  # Regenerate the raw list with ./scripts/firefox_facts.py (macOS Terminal);
  # captured 2026-09-12 and pruned by hand (1Password added 2026-09-15):
  #   - uMatrix left out: unmaintained since 2021, uBlock Origin covers it
  #   - the two datareporting.*.uploadEnabled prefs became DisableTelemetry
  #   - findbar.highlightAll, print_printer, privacy.clearHistory.*,
  #     privacy.sanitize.timeSpan, privacy.history.custom: the Preferences
  #     policy refuses these names and no dedicated policy exists
  #   - browser.ipProtection.enabled was captured as true (Mozilla rollout, not
  #     a choice) and pins a VPN button to the toolbar; declared false + locked
  #   - privacy.clearOnShutdown_v2.formdata is set but sanitizeOnShutdown is
  #     off, so it does nothing today; add SanitizeOnShutdown if you turn it on
  # Policy reference: https://mozilla.github.io/policy-templates/
  system.defaults.CustomUserPreferences."org.mozilla.firefox" = {
    EnterprisePoliciesEnabled = true;

    DisableTelemetry = true;

    # normal_installed: auto-installed on first launch; the user can disable
    # it but not remove it. Switch to force_installed to also lock enabling.
    # default_area = "menupanel" keeps the button under the extensions
    # (puzzle-piece) button instead of pinning it to the toolbar. It is the
    # placement for a button that has never been placed, so it applies to a
    # fresh profile; a profile that already pinned the button keeps that.
    ExtensionSettings = {
      "{d634138d-c276-4fc8-924b-40a0ea21d284}" = {  # 1Password (added 2026-09-15, not from the capture)
        installation_mode = "normal_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/onepassword-password-manager/latest.xpi";
        default_area = "menupanel";
      };
      "78272b6fa58f4a1abaac99321d503a20@proton.me" = {  # Proton Pass: Free Password Manager 1.38.0
        installation_mode = "normal_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/78272b6fa58f4a1abaac99321d503a20@proton.me/latest.xpi";
        default_area = "menupanel";
      };
      "extension@one-tab.com" = {  # OneTab 2.19
        installation_mode = "normal_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/extension@one-tab.com/latest.xpi";
        default_area = "menupanel";
      };
      "uBlock0@raymondhill.net" = {  # uBlock Origin 1.74.0
        installation_mode = "normal_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/uBlock0@raymondhill.net/latest.xpi";
        default_area = "menupanel";
      };
    };

    # Managed storage for add-ons (Firefox "3rdparty" policy). uBlock Origin
    # replaces its "My filters" pane with toOverwrite.filters at every launch,
    # so the pane is effectively read-only: edit ublock-filters.txt instead.
    # Keys: https://github.com/gorhill/uBlock/wiki/Deploying-uBlock-Origin:-configuration
    "3rdparty".Extensions."uBlock0@raymondhill.net".toOverwrite.filters =
      lib.splitString "\n" (lib.removeSuffix "\n" (builtins.readFile ./ublock-filters.txt));

    # Status = "user" re-applies the value at every start; "locked" also
    # greys it out in about:config and Settings.
    Preferences = {
      "accessibility.typeaheadfind.flashBar" = { Value = 0; Status = "user"; };
      "browser.ai.control.linkPreviewKeyPoints" = { Value = "blocked"; Status = "user"; };
      "browser.ai.control.pdfjsAltText" = { Value = "blocked"; Status = "user"; };
      "browser.ai.control.sidebarChatbot" = { Value = "blocked"; Status = "user"; };
      "browser.ai.control.smartTabGroups" = { Value = "blocked"; Status = "user"; };
      "browser.contentblocking.category" = { Value = "standard"; Status = "user"; };
      "browser.formfill.enable" = { Value = false; Status = "user"; };
      "browser.ipProtection.enabled" = { Value = false; Status = "locked"; }; # built-in VPN + its toolbar button
      "browser.ml.chat.enabled" = { Value = false; Status = "user"; };
      "browser.ml.chat.page" = { Value = false; Status = "user"; };
      "browser.ml.linkPreview.enabled" = { Value = false; Status = "user"; };
      "browser.newtabpage.activity-stream.widgets.sportsWidget.enabled" = { Value = false; Status = "user"; };
      "browser.search.suggest.enabled" = { Value = false; Status = "user"; };
      "browser.tabs.groups.smart.enabled" = { Value = false; Status = "user"; };
      "browser.tabs.groups.smart.userEnabled" = { Value = false; Status = "user"; };
      "browser.theme.toolbar-theme" = { Value = 0; Status = "user"; };
      "browser.translations.alwaysTranslateLanguages" = { Value = "ja"; Status = "user"; };
      "browser.urlbar.suggest.bookmark" = { Value = false; Status = "user"; };
      "browser.urlbar.suggest.engines" = { Value = false; Status = "user"; };
      "browser.urlbar.suggest.history" = { Value = false; Status = "user"; };
      "browser.urlbar.suggest.openpage" = { Value = false; Status = "user"; };
      "browser.urlbar.suggest.quicksuggest.all" = { Value = false; Status = "user"; };
      "browser.urlbar.suggest.quicksuggest.nonsponsored" = { Value = false; Status = "user"; };
      "browser.urlbar.suggest.quicksuggest.sponsored" = { Value = false; Status = "user"; };
      "browser.urlbar.suggest.recentsearches" = { Value = false; Status = "user"; };
      "browser.urlbar.suggest.searches" = { Value = false; Status = "user"; };
      "browser.urlbar.suggest.topsites" = { Value = false; Status = "user"; };
      "devtools.netmonitor.persistlog" = { Value = true; Status = "user"; };
      "dom.forms.autocomplete.formautofill" = { Value = true; Status = "user"; };
      "extensions.activeThemeID" = { Value = "default-theme@mozilla.org"; Status = "user"; };
      "extensions.formautofill.addresses.enabled" = { Value = false; Status = "user"; };
      "extensions.formautofill.creditCards.enabled" = { Value = false; Status = "user"; };
      "identity.fxaccounts.toolbar.enabled" = { Value = false; Status = "locked"; }; # Mozilla-account toolbar button
      "network.dns.disablePrefetch" = { Value = true; Status = "user"; };
      "network.http.speculative-parallel-limit" = { Value = 0; Status = "user"; };
      "network.prefetch-next" = { Value = false; Status = "user"; };
      "network.trr.mode" = { Value = 5; Status = "user"; };
      "pdfjs.enableAltText" = { Value = false; Status = "user"; };
      "pdfjs.enableAltTextForEnglish" = { Value = true; Status = "user"; };
      "privacy.globalprivacycontrol.enabled" = { Value = true; Status = "user"; };
      "sidebar.visibility" = { Value = "hide-on-close"; Status = "user"; };
      "signon.management.page.breach-alerts.enabled" = { Value = false; Status = "user"; };
      "signon.rememberSignons" = { Value = false; Status = "user"; };
    };
  };
}
