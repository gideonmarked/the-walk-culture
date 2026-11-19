/// Public web pages the app links to. Google Play requires the privacy policy
/// to be reachable from inside the app, and the account-deletion page to be
/// entered in Play Console; both are hosted on GitHub Pages from `docs/`.
library;

const String kSiteBase = 'https://gideonmarked.github.io/the-walk-culture';

const String kPrivacyPolicyUrl = '$kSiteBase/privacy.html';
const String kTermsUrl = '$kSiteBase/terms.html';
const String kDeleteAccountUrl = '$kSiteBase/delete-account.html';

/// Where players manage (and cancel) subscriptions on each store.
const String kPlaySubscriptionsUrl =
    'https://play.google.com/store/account/subscriptions';
const String kAppStoreSubscriptionsUrl =
    'https://apps.apple.com/account/subscriptions';
