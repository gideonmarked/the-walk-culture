/// Daily Bible verse + its reward roll.
///
/// Verses are bundled and public-domain (King James Version), so the feature
/// works offline with no API key and no licensing risk. To serve live verses
/// from YouVersion later, fetch them through a backend proxy (a Supabase Edge
/// Function that holds the developer token as a secret) and drop the result in
/// place of [verseForToday] — never bake the token into the app.
library;

import '../models/shop_item.dart' show Rarity;

/// The bundled text's version. KJV is public domain (free to embed). Switch to
/// 'ESV' only when verses come LIVE from a licensed API — ESV text may not be
/// bundled, and its licence requires showing this attribution with the verse.
const String kBibleVersion = 'KJV';

class Verse {
  const Verse(this.reference, this.text);
  final String reference;
  final String text;
}

/// Well-known KJV verses (public domain). One is shown per day, chosen by the
/// day of the year so everyone sees the same "verse of the day".
const List<Verse> kVerses = [
  Verse('John 3:16',
      'For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.'),
  Verse('Philippians 4:13',
      'I can do all things through Christ which strengtheneth me.'),
  Verse('Proverbs 3:5',
      'Trust in the LORD with all thine heart; and lean not unto thine own understanding.'),
  Verse('Psalm 23:1', 'The LORD is my shepherd; I shall not want.'),
  Verse('Isaiah 40:31',
      'But they that wait upon the LORD shall renew their strength; they shall mount up with wings as eagles; they shall run, and not be weary; and they shall walk, and not faint.'),
  Verse('Romans 8:28',
      'And we know that all things work together for good to them that love God, to them who are the called according to his purpose.'),
  Verse('Joshua 1:9',
      'Be strong and of a good courage; be not afraid, neither be thou dismayed: for the LORD thy God is with thee whithersoever thou goest.'),
  Verse('Matthew 6:33',
      'But seek ye first the kingdom of God, and his righteousness; and all these things shall be added unto you.'),
  Verse('Psalm 46:1',
      'God is our refuge and strength, a very present help in trouble.'),
  Verse('Jeremiah 29:11',
      'For I know the thoughts that I think toward you, saith the LORD, thoughts of peace, and not of evil, to give you an expected end.'),
  Verse('1 Corinthians 13:4',
      'Charity suffereth long, and is kind; charity envieth not; charity vaunteth not itself, is not puffed up.'),
  Verse('Galatians 5:22',
      'But the fruit of the Spirit is love, joy, peace, longsuffering, gentleness, goodness, faith.'),
  Verse('Psalm 118:24',
      'This is the day which the LORD hath made; we will rejoice and be glad in it.'),
  Verse('Proverbs 16:3',
      'Commit thy works unto the LORD, and thy thoughts shall be established.'),
  Verse('2 Timothy 1:7',
      'For God hath not given us the spirit of fear; but of power, and of love, and of a sound mind.'),
  Verse('Psalm 27:1',
      'The LORD is my light and my salvation; whom shall I fear? the LORD is the strength of my life; of whom shall I be afraid?'),
  Verse('Matthew 11:28',
      'Come unto me, all ye that labour and are heavy laden, and I will give you rest.'),
  Verse('Romans 12:2',
      'And be not conformed to this world: but be ye transformed by the renewing of your mind.'),
  Verse('Hebrews 11:1',
      'Now faith is the substance of things hoped for, the evidence of things not seen.'),
  Verse('Psalm 37:4',
      'Delight thyself also in the LORD; and he shall give thee the desires of thine heart.'),
  Verse('Isaiah 41:10',
      'Fear thou not; for I am with thee: be not dismayed; for I am thy God: I will strengthen thee; yea, I will help thee.'),
  Verse('1 Peter 5:7', 'Casting all your care upon him; for he careth for you.'),
  Verse('Ephesians 2:8',
      'For by grace are ye saved through faith; and that not of yourselves: it is the gift of God.'),
  Verse('Colossians 3:23',
      'And whatsoever ye do, do it heartily, as to the Lord, and not unto men.'),
  Verse('Psalm 119:105',
      'Thy word is a lamp unto my feet, and a light unto my path.'),
  Verse('James 1:5',
      'If any of you lack wisdom, let him ask of God, that giveth to all men liberally, and upbraideth not; and it shall be given him.'),
  Verse('Micah 6:8',
      'He hath shewed thee, O man, what is good; and what doth the LORD require of thee, but to do justly, and to love mercy, and to walk humbly with thy God?'),
  Verse('Deuteronomy 31:6',
      'Be strong and of a good courage, fear not, nor be afraid of them: for the LORD thy God, he it is that doth go with thee; he will not fail thee, nor forsake thee.'),
  Verse('Psalm 34:8',
      'O taste and see that the LORD is good: blessed is the man that trusteth in him.'),
  Verse('Lamentations 3:22',
      'It is of the LORD’s mercies that we are not consumed, because his compassions fail not.'),
];

/// How long the reader must spend before the reward unlocks.
const Duration kBibleReadDuration = Duration(seconds: 60);

/// Today's verse — stable for the whole day, same for everyone.
Verse verseForToday([DateTime? now]) {
  final d = now ?? DateTime.now();
  final dayOfYear =
      d.difference(DateTime(d.year)).inDays; // 0-based day index
  return kVerses[dayOfYear % kVerses.length];
}

/// Drop odds for the read-reward, in percent (must sum to 100). Generous on
/// common, with a small chance at something rare — a gentle daily nudge, not a
/// power source.
const Map<Rarity, double> kBibleRewardOdds = {
  Rarity.common: 68.0,
  Rarity.uncommon: 22.0,
  Rarity.rare: 7.0,
  Rarity.epic: 2.5,
  Rarity.legendary: 0.5,
};
