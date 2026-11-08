import '../../models/analysis.dart';

/// Works out *what kind of deal* a document is, *who* it's written for and
/// which language it's in, so results can lead with what people in that
/// situation care about. The fairness score itself uses the same criteria
/// for every document; this only changes what we highlight.
class ContextProfiler {
  // ---------------------------------------------------------------- language

  static const _stop = <String, List<String>>{
    'en': ['the', 'and', 'you', 'your', 'of', 'to', 'is', 'that', 'we', 'with', 'for', 'this'],
    'fr': ['le', 'la', 'les', 'et', 'vous', 'votre', 'des', 'du', 'est', 'que', 'nous', 'pour', 'une', 'aux'],
    'es': ['el', 'la', 'los', 'las', 'y', 'usted', 'su', 'de', 'que', 'es', 'para', 'por', 'una', 'nosotros'],
    'de': ['der', 'die', 'das', 'und', 'sie', 'ihr', 'ist', 'nicht', 'mit', 'für', 'wir', 'eine', 'den', 'zu'],
    'pt': ['o', 'os', 'as', 'e', 'você', 'seu', 'sua', 'de', 'que', 'é', 'para', 'uma', 'nós', 'não'],
    'it': ['il', 'lo', 'gli', 'e', 'voi', 'tuo', 'di', 'che', 'è', 'per', 'una', 'noi', 'non', 'della'],
  };

  static const languageNames = {
    'en': 'English',
    'fr': 'French',
    'es': 'Spanish',
    'de': 'German',
    'pt': 'Portuguese',
    'it': 'Italian',
  };

  /// Best guess at the document's language from very common words.
  static String detectLanguage(String text) {
    final sample = text.length > 20000 ? text.substring(0, 20000) : text;
    final words = sample
        .toLowerCase()
        .split(RegExp(r"[^a-zà-ÿœæ']+"))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length < 30) return 'en';
    final counts = <String, int>{};
    for (final e in _stop.entries) {
      final set = e.value.toSet();
      counts[e.key] = words.where(set.contains).length;
    }
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final en = counts['en'] ?? 0;
    // Only call it non-English when clearly so.
    if (best.key != 'en' && best.value > en * 1.6 && best.value > words.length * 0.04) return best.key;
    return 'en';
  }

  // ---------------------------------------------------------------- deal type

  static final _types = <_DealType>[
    _DealType('rideshare', 'a ride or delivery app',
        ['ride', 'rider', 'driver', 'trip', 'pickup', 'drop-off', 'courier', 'delivery person', 'fare']),
    _DealType('shopping', 'an online shop',
        ['order', 'shipping', 'return', 'refund', 'purchase', 'cart', 'product', 'delivery', 'warranty', 'checkout']),
    _DealType('subscription', 'a subscription service',
        ['subscription', 'membership', 'billing period', 'auto-renew', 'renewal', 'cancel your', 'monthly', 'free trial', 'streaming']),
    _DealType('social', 'a social or content app',
        ['post', 'content you', 'user content', 'profile', 'followers', 'community guidelines', 'upload', 'share content']),
    _DealType('lodging', 'a home or travel booking service',
        ['host', 'guest', 'booking', 'reservation', 'listing', 'check-in', 'accommodation', 'stay']),
    _DealType('rental', 'a lease or rental agreement',
        ['tenant', 'landlord', 'lease', 'premises', 'rent', 'security deposit', 'lessee', 'lessor']),
    _DealType('insurance', 'an insurance policy',
        ['policy', 'premium', 'claim', 'coverage', 'insured', 'deductible', 'insurer', 'beneficiary']),
    _DealType('finance', 'a banking or payments service',
        ['account', 'interest', 'credit', 'loan', 'payment', 'transaction', 'card', 'overdraft', 'apr']),
    _DealType('gym', 'a gym or club membership',
        ['gym', 'club', 'fitness', 'class', 'facility', 'locker', 'personal trainer']),
    _DealType('software', 'an app or software service',
        ['software', 'license', 'service', 'api', 'account', 'cloud', 'subscription', 'seat']),
    _DealType('phone', 'a phone or internet plan',
        ['data', 'plan', 'carrier', 'device', 'roaming', 'network', 'minutes', 'unlock']),
  ];

  static String detectType(String text, String title, String? url) {
    final t = text.length > 60000 ? text.substring(0, 60000).toLowerCase() : text.toLowerCase();
    final head = '${title.toLowerCase()} ${(url ?? '').toLowerCase()}';
    String best = 'general';
    double bestScore = 0;
    for (final d in _types) {
      var s = 0.0;
      for (final k in d.keywords) {
        s += RegExp('\\b${RegExp.escape(k)}', caseSensitive: false).allMatches(t).length.clamp(0, 30);
        if (head.contains(k)) s += 25;
      }
      if (s > bestScore) {
        bestScore = s;
        best = d.id;
      }
    }
    return bestScore < 8 ? 'general' : best;
  }

  static String describeType(String id) =>
      _types.where((d) => d.id == id).map((d) => d.label).firstOrNull ?? 'an agreement';

  /// Plain-English line about how the deal type changed the check.
  static String weightingNote(String id) => switch (id) {
        'shopping' => 'We checked it as an online shop, so returns, refunds and fees count for more.',
        'subscription' => 'We checked it as a subscription, so renewals, cancelling and price changes count for more.',
        'rideshare' => 'We checked it as a ride or delivery app, so fees, safety and who’s responsible count for more.',
        'social' => 'We checked it as a social app, so your posts, your data and AI training count for more.',
        'lodging' => 'We checked it as a booking service, so cancellations and fees count for more.',
        'rental' => 'We checked it as a rental, so deposits, penalties and rent changes count for more.',
        'insurance' => 'We checked it as insurance, so exclusions, claims and cancelling count for more.',
        'finance' => 'We checked it as a bank or payments service, so fees and rates count for more.',
        'gym' => 'We checked it as a gym membership, so lock-ins and cancelling count for more.',
        'software' => 'We checked it as an app or software, so your data and liability count for more.',
        'phone' => 'We checked it as a phone plan, so contract length and exit fees count for more.',
        _ => 'We used our standard checklist for this one.',
      };

  static String typeTitle(String id) => switch (id) {
        'rideshare' => 'a ride or delivery app',
        'shopping' => 'an online shop',
        'subscription' => 'a subscription',
        'social' => 'a social app',
        'lodging' => 'a booking service',
        'rental' => 'a rental',
        'insurance' => 'insurance',
        'finance' => 'a bank or payments app',
        'gym' => 'a gym membership',
        'software' => 'an app or software',
        'phone' => 'a phone plan',
        _ => 'this kind of deal',
      };

  // ---------------------------------------------------------------- industry

  /// The industry on top of the deal type: a beauty shop and an electronics
  /// shop are both "shops", but people care about different things.
  static const _industries = <(String, String, List<String>)>[
    ('beauty', 'beauty and skincare', ['skincare', 'cosmetic', 'makeup', 'beauty', 'fragrance', 'serum', 'shade', 'patch test', 'skin type', 'hair care', 'nail']),
    ('food', 'food and grocery', ['restaurant', 'meal', 'grocery', 'food', 'menu', 'allergen', 'recipe', 'dish', 'kitchen']),
    ('gaming', 'games', ['game', 'gaming', 'player', 'in-game', 'virtual currency', 'virtual item', 'loot', 'gems', 'coins', 'esports']),
    ('dating', 'dating', ['dating', 'match', 'matches', 'swipe', 'date', 'romance', 'singles']),
    ('health', 'health and wellness', ['health', 'medical', 'wellness', 'therapy', 'symptom', 'prescription', 'clinician', 'workout', 'nutrition', 'mental health']),
    ('travel', 'travel', ['flight', 'airline', 'baggage', 'itinerary', 'boarding', 'hotel', 'fare class', 'passport']),
    ('education', 'learning and courses', ['course', 'student', 'tuition', 'lesson', 'certificate', 'enrollment', 'instructor', 'curriculum']),
    ('crypto', 'crypto and investing', ['crypto', 'bitcoin', 'wallet', 'token', 'blockchain', 'trading', 'investment', 'securities', 'staking']),
    ('kids', 'kids and family', ['child', 'children', 'parent', 'parental consent', 'under 13', 'minor', 'kids']),
    ('auto', 'cars and vehicle rental', ['vehicle', 'car rental', 'mileage', 'fuel', 'toll', 'collision damage', 'renter']),
    ('electronics', 'electronics and gadgets', ['device', 'battery', 'firmware', 'electronics', 'warranty repair', 'gadget', 'charger']),
    ('fashion', 'clothing and fashion', ['clothing', 'apparel', 'size guide', 'fit', 'garment', 'fashion', 'shoes']),
  ];

  static String detectIndustry(String text, String title, String? url) {
    final t = text.length > 60000 ? text.substring(0, 60000).toLowerCase() : text.toLowerCase();
    final head = '${title.toLowerCase()} ${(url ?? '').toLowerCase()}';
    String best = 'general';
    var bestScore = 0;
    for (final ind in _industries) {
      var sc = 0;
      for (final k in ind.$3) {
        sc += RegExp('\\b${RegExp.escape(k)}').allMatches(t).length.clamp(0, 25).toInt();
        if (head.contains(k)) sc += 30;
      }
      if (sc > bestScore) {
        bestScore = sc;
        best = ind.$1;
      }
    }
    return bestScore < 10 ? 'general' : best;
  }

  static String industryLabel(String id) =>
      _industries.where((i) => i.$1 == id).map((i) => i.$2).firstOrNull ?? '';

  /// What the industry adds to the check, in plain words.
  static String industryNote(String id) => switch (id) {
        'beauty' => 'Because it’s beauty, we also look at reactions and allergies, returns on opened products, auto-ship refills and use of your photos or reviews.',
        'food' => 'Because it’s food, we also look at allergies, missing or wrong orders, extra delivery and service fees, and tipping.',
        'gaming' => 'Because it’s games, we also look at virtual money, loot boxes, bans and whether you really own what you buy.',
        'dating' => 'Because it’s dating, we also look at safety checks, use of your photos, and bans without refunds.',
        'health' => 'Because it’s health, we also look at your health data, “not medical advice” disclaimers and injury waivers.',
        'travel' => 'Because it’s travel, we also look at change fees, overbooking, lost baggage limits and non-refundable fares.',
        'education' => 'Because it’s learning, we also look at refunds after you start, recordings and whether certificates count.',
        'crypto' => 'Because it’s crypto or investing, we also look at losses, frozen accounts and whether your money is protected.',
        'kids' => 'Because it involves kids, we also look at children’s data and parental consent.',
        'auto' => 'Because it’s vehicles, we also look at damage charges, mileage limits, tolls and admin fees.',
        'electronics' => 'Because it’s electronics, we also look at warranties, repairs and software updates.',
        'fashion' => 'Because it’s fashion, we also look at sizing, returns of worn items and final sales.',
        _ => '',
      };

  // ---------------------------------------------------------------- audience

  static const _roles = <(String, String, List<String>)>[
    ('riders', 'people booking rides or deliveries', ['rider', 'riders', 'passenger', 'passengers']),
    ('drivers', 'drivers and couriers', ['driver', 'drivers', 'courier', 'couriers', 'driver partner', 'delivery person']),
    ('buyers', 'shoppers buying things', ['buyer', 'buyers', 'customer', 'customers', 'shopper', 'purchaser']),
    ('sellers', 'sellers and merchants', ['seller', 'sellers', 'merchant', 'merchants', 'vendor', 'vendors', 'restaurant partner']),
    ('guests', 'guests booking stays', ['guest', 'guests', 'traveler', 'travellers', 'travelers']),
    ('hosts', 'hosts listing places', ['host', 'hosts']),
    ('tenants', 'the tenant renting', ['tenant', 'tenants', 'lessee']),
    ('landlords', 'the landlord', ['landlord', 'landlords', 'lessor']),
    ('policyholders', 'the policyholder', ['policyholder', 'insured', 'named insured']),
    ('members', 'members', ['member', 'members', 'subscriber', 'subscribers']),
    ('businesses', 'business customers', ['business customer', 'enterprise', 'organization', 'administrator']),
    ('users', 'everyday users', ['user', 'users', 'you']),
  ];

  /// "Riders (people booking rides or deliveries)" style answer plus the
  /// other side we found mentioned, if any.
  static (String, String?) detectAudience(String text, String title, String? url) {
    final t = text.length > 60000 ? text.substring(0, 60000).toLowerCase() : text.toLowerCase();
    final head = '${title.toLowerCase()} ${(url ?? '').toLowerCase()}';
    final scores = <String, int>{};
    for (final r in _roles) {
      if (r.$1 == 'users') continue;
      var s = 0;
      for (final w in r.$3) {
        s += RegExp('\\b${RegExp.escape(w)}\\b').allMatches(t).length;
        if (head.contains(w)) s += 40;
      }
      scores[r.$1] = s;
    }
    final ranked = scores.entries.where((e) => e.value >= 4).toList()..sort((a, b) => b.value.compareTo(a.value));
    if (ranked.isEmpty) return ('everyday users of the service', null);
    final top = _roles.firstWhere((r) => r.$1 == ranked.first.key);
    final other = ranked.length > 1 && ranked[1].value > ranked.first.value * 0.25
        ? _roles.firstWhere((r) => r.$1 == ranked[1].key).$2
        : null;
    return (top.$2, other);
  }

  // ---------------------------------------------------------------- focus

  static final _focus = <String, List<_FocusRule>>{
    'shopping': [
      _FocusRule('Returns', 'How long you have to send things back', [r'return(s|ed)? (policy|window|within|period)', r'within \d+ days? (of|after) (delivery|receipt|purchase)', r'\breturn\b.{0,40}\bdays?\b']),
      _FocusRule('Refunds', 'Whether you get your money back, and how', [r'refund', r'money back', r'store credit']),
      _FocusRule('Shipping & delivery', 'Who pays and what if it never arrives', [r'shipping', r'delivery (time|date|fee|charges?)', r'lost (in transit|package)']),
      _FocusRule('Warranty', 'What happens if it breaks', [r'warrant(y|ies)', r'guarantee', r'defect']),
      _FocusRule('Price & promos', 'Pricing errors, coupons and changes', [r'pric(e|ing) error', r'promo(tion|tional)? code', r'coupon', r'change (our |the )?prices?']),
    ],
    'subscription': [
      _FocusRule('Cancelling', 'How easy it is to stop', [r'cancel', r'terminate your (subscription|membership)']),
      _FocusRule('Auto-renewal', 'Whether it keeps charging you', [r'auto(matic(ally)?)?[- ]?renew', r'recurring']),
      _FocusRule('Free trials', 'When the trial turns paid', [r'free trial', r'trial period']),
      _FocusRule('Price changes', 'Whether they can raise the price', [r'(change|increase|adjust).{0,30}(price|fee)', r'price (change|increase)']),
      _FocusRule('Refunds', 'Money back if you leave mid-cycle', [r'refund', r'pro-?rat']),
    ],
    'rideshare': [
      _FocusRule('Fares & surge', 'How prices are set and when they jump', [r'fare', r'surge', r'dynamic pric', r'price estimate']),
      _FocusRule('Cancellation fees', 'What it costs to cancel a trip', [r'cancel(lation)? fee', r'no-?show']),
      _FocusRule('Safety', 'What they do about safety and incidents', [r'safety', r'emergency', r'incident', r'background check']),
      _FocusRule('Damage & cleaning', 'Fees if something gets damaged', [r'damage', r'cleaning fee', r'vomit']),
      _FocusRule('Who is responsible', 'Whether they say drivers are independent', [r'independent (contractor|third[- ]party)', r'not a (transportation|delivery) (provider|carrier)']),
    ],
    'social': [
      _FocusRule('Your content', 'What they can do with what you post', [r'licen[cs]e', r'content you (post|upload|submit)', r'user content']),
      _FocusRule('Your data', 'What they collect and share', [r'personal (data|information)', r'share.{0,30}(third|partner)', r'advertis']),
      _FocusRule('AI training', 'Whether your posts train their AI', [r'machine learning', r'artificial intelligence', r'\bAI\b', r'train(ing)? (our|models)']),
      _FocusRule('Account bans', 'When they can suspend you', [r'suspend', r'terminate your account', r'disable']),
      _FocusRule('Age rules', 'Minimum age to use it', [r'\b1[3-8]\b.{0,20}(years|older)', r'minimum age']),
    ],
    'lodging': [
      _FocusRule('Cancellation policy', 'What you get back if plans change', [r'cancel', r'non-?refundable']),
      _FocusRule('Fees', 'Service, cleaning and other fees', [r'service fee', r'cleaning fee', r'\bfees?\b']),
      _FocusRule('Damage', 'What you owe if something breaks', [r'damage', r'security deposit']),
      _FocusRule('Refunds', 'When you can get money back', [r'refund']),
    ],
    'rental': [
      _FocusRule('Deposit', 'When you get your deposit back', [r'security deposit', r'\bdeposit\b']),
      _FocusRule('Rent increases', 'Whether rent can go up mid-lease', [r'rent (increase|adjust)', r'increase.{0,20}rent']),
      _FocusRule('Repairs', 'Who fixes what', [r'repair', r'maintenance']),
      _FocusRule('Ending early', 'Penalties for leaving early', [r'early termination', r'break (the|this) lease', r'terminate.{0,30}lease']),
      _FocusRule('Entry', 'When the landlord can come in', [r'\benter\b', r'\bentry\b', r'access to the premises']),
    ],
    'insurance': [
      _FocusRule('What’s covered', 'The main coverage', [r'cover(age|ed|s)']),
      _FocusRule('Exclusions', 'What they won’t pay for', [r'exclu(de|sion)', r'not covered']),
      _FocusRule('Deductible', 'What you pay first', [r'deductible', r'excess']),
      _FocusRule('Claims', 'How and when to claim', [r'claim']),
      _FocusRule('Cancelling', 'Refunds if you cancel', [r'cancel']),
    ],
    'finance': [
      _FocusRule('Fees', 'Monthly, overdraft and other fees', [r'\bfees?\b', r'overdraft']),
      _FocusRule('Interest', 'Rates and how they change', [r'interest', r'\bapr\b', r'rate']),
      _FocusRule('Disputes & fraud', 'What happens with unauthorized charges', [r'unauthori[sz]ed', r'fraud', r'dispute']),
      _FocusRule('Closing your account', 'When they (or you) can close it', [r'close (your|the) account', r'terminate']),
    ],
    'gym': [
      _FocusRule('Cancelling', 'Notice and how to cancel', [r'cancel', r'notice']),
      _FocusRule('Minimum term', 'How long you’re locked in', [r'minimum (term|period|commitment)', r'\b\d+ months?\b']),
      _FocusRule('Fees', 'Joining, annual and freeze fees', [r'(joining|enrol?lment|annual|freeze) fee', r'\bfees?\b']),
      _FocusRule('Injury & liability', 'Who’s responsible if you get hurt', [r'injur', r'liabilit', r'waive']),
    ],
    'software': [
      _FocusRule('Your data', 'What they collect and keep', [r'personal (data|information)', r'retain', r'delete']),
      _FocusRule('Price changes', 'Whether they can raise the price', [r'(change|increase).{0,30}(price|fee)']),
      _FocusRule('Uptime & liability', 'What if it breaks or loses your work', [r'as is', r'liabilit', r'uptime', r'availability']),
      _FocusRule('Cancelling', 'How to stop and export your stuff', [r'cancel', r'terminate', r'export']),
    ],
    'phone': [
      _FocusRule('Contract length', 'How long you’re committed', [r'\b\d+[- ]month', r'term']),
      _FocusRule('Early exit fees', 'Cost to leave early', [r'early (termination|cancellation)', r'device balance']),
      _FocusRule('Data & throttling', 'Speed limits after a cap', [r'throttl', r'reduced speed', r'data (cap|limit)']),
      _FocusRule('Price changes', 'Whether the bill can go up', [r'(change|increase).{0,30}(price|rate|fee)']),
    ],
  };

  static final _generalFocus = <_FocusRule>[
    _FocusRule('Cancelling', 'How you get out', [r'cancel', r'terminate']),
    _FocusRule('Refunds', 'Money back', [r'refund']),
    _FocusRule('Your data', 'What they collect and share', [r'personal (data|information)', r'share.{0,30}third']),
    _FocusRule('Disputes', 'How disagreements get settled', [r'arbitrat', r'court', r'dispute']),
  ];

  static List<FocusItem> focusFor(String type, String text) {
    final rules = _focus[type] ?? _generalFocus;
    final sentences = text
        .replaceAll('\r', '')
        .split(RegExp(r'(?<=[.!?;])\s+|\n+'))
        .map((s) => s.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((s) => s.length > 20)
        .toList();
    return [
      for (final r in rules) _match(r, sentences),
    ];
  }

  static FocusItem _match(_FocusRule r, List<String> sentences) {
    final pats = r.patterns.map((p) => RegExp(p, caseSensitive: false)).toList();
    for (final s in sentences) {
      if (pats.any((p) => p.hasMatch(s))) {
        final ex = s.length > 220 ? '${s.substring(0, 217)}…' : s;
        return FocusItem(label: r.label, why: r.why, found: true, excerpt: ex);
      }
    }
    return FocusItem(label: r.label, why: r.why, found: false);
  }

  // ---------------------------------------------------------------- all together

  static DocProfile profile(ContractInput input) {
    final type = detectType(input.text, input.title, input.ref);
    final (aud, other) = detectAudience(input.text, input.title, input.ref);
    final fromWeb = input.kind == SourceKind.link || input.kind == SourceKind.library;
    final site = fromWeb ? input.title.split(' · ').first.trim() : 'the company';
    String cap(String x) => x.isEmpty ? x : x[0].toUpperCase() + x.substring(1);
    final who = site == 'the company' ? 'These are the rules for $aud.' : 'These are $site’s rules for $aud.';
    final summary = other == null ? who : '$who ${cap(other)} are mentioned too.';
    return DocProfile(
      language: detectLanguage(input.text),
      industry: detectIndustry(input.text, input.title, input.ref),
      dealType: type,
      audience: aud,
      otherParty: other,
      summary: summary,
      focus: focusFor(type, input.text),
    );
  }
}

class DocProfile {
  final String language;
  final String industry;
  final String dealType;
  final String audience;
  final String? otherParty;
  final String summary;
  final List<FocusItem> focus;
  const DocProfile({
    required this.language,
    this.industry = 'general',
    required this.dealType,
    required this.audience,
    required this.summary,
    required this.focus,
    this.otherParty,
  });
}

class _DealType {
  final String id;
  final String label;
  final List<String> keywords;
  const _DealType(this.id, this.label, this.keywords);
}

class _FocusRule {
  final String label;
  final String why;
  final List<String> patterns;
  const _FocusRule(this.label, this.why, this.patterns);
}

/// Thrown when a document isn't in a language the current engine can read.
class UnsupportedLanguageException implements Exception {
  final String language;
  final bool needsDownload;
  UnsupportedLanguageException(this.language, {this.needsDownload = false});
  @override
  String toString() => needsDownload
      ? 'This looks like $language. We translate it on your phone, but the $language language pack hasn’t '
          'downloaded yet. Connect to the internet once and try again. After that it works offline.'
      : 'This looks like $language, which we can’t read yet. Rather than guess, we didn’t score it. '
          'Look for an English, French, Spanish, German, Portuguese or Italian version of the page.';
}

/// Thrown when what we were given doesn't look like terms at all (a photo of
/// a home screen, a menu, a few words). We show an empty state instead of
/// inventing a score.
class NotTermsException implements Exception {
  @override
  String toString() => 'We couldn’t find any terms or conditions in this, so there’s nothing to score. '
      'Try a clearer photo of the page, or the full text.';
}

/// Rough check that a text reads like an agreement or policy.
bool looksLikeTerms(String text) {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  if (words < 30) return false;
  final markers = RegExp(
    r'\b(terms|conditions|agree(?:ment|s|d)?|policy|privacy|liab(?:le|ility)|shall|warrant(?:y|ies)|licen[cs]e|'
    r'governed|jurisdiction|arbitration|refunds?|cancel(?:lation)?|subscription|fees?|charges?|personal (?:data|information)|'
    r'third part(?:y|ies)|terminat(?:e|ion)|rights?|obligations?|indemnif|consent|you (?:may|must|agree)|we (?:may|will))\b',
    caseSensitive: false,
  );
  final hits = markers.allMatches(text).map((m) => m.group(0)!.toLowerCase()).toList();
  final distinct = hits.toSet().length;
  return distinct >= 3 && hits.length * 100 / words >= 1.0;
}
