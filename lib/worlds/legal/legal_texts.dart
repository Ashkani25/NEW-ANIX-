/// In-app Privacy Policy and Terms of Use (P0 #6), Persian and English.
///
/// Generic text for a game + social app; the owner should review it (and add a public URL for the store listing).
/// Bump [legalVersion] whenever the text changes materially: sign-up records acceptance of this version.
const String legalVersion = '2026-11-25';

class LegalSection {
  const LegalSection(this.title, this.body);
  final String title;
  final String body;
}

const List<LegalSection> privacyFa = <LegalSection>[
  LegalSection('خلاصه',
      'آنیکس یک برنامه‌ی بازی و شبکه‌ی اجتماعی است. ما فقط داده‌هایی را جمع می‌کنیم که برای ساخت حساب، اجرای بازی‌های آنلاین، چت و تماس، خرید درون‌برنامه‌ای و امنیت لازم است. داده‌های تو را نمی‌فروشیم و برای تبلیغات هدفمند استفاده نمی‌کنیم.'),
  LegalSection('چه داده‌هایی جمع می‌شود',
      '• حساب: نام کاربری، رمز عبور (به شکل رمزنگاری‌شده)، ایمیل در صورت وارد کردن (فقط برای بازیابی).\n'
          '• پروفایل: نام نمایشی، تصویر، بیوگرافی و تنظیمات حریم خصوصی.\n'
          '• بازی: سابقه‌ی مسابقه‌ها، امتیاز و رتبه، تورنمنت‌ها، سکه و جم، آیتم‌ها و دستاوردها.\n'
          '• اجتماعی: دنبال‌کردن‌ها، پست‌ها و استوری‌ها، نظرها و لایک‌ها، پیام‌های چت و فایل‌هایی که می‌فرستی (عکس، صدا، فایل)، گروه‌ها و کامیونیتی‌ها، گزارش‌ها و کاربران مسدودشده.\n'
          '• صدا و تصویر: تماس و اتاق صوتی به‌صورت زنده از سرور انتقال صدا عبور می‌کند و ما آن را ضبط یا ذخیره نمی‌کنیم.\n'
          '• خرید: شناسه‌ی سفارش و محصول خریداری‌شده از کافه‌بازار برای تحویل سکه/جم. اطلاعات کارت بانکی را هرگز دریافت نمی‌کنیم.\n'
          '• فنی: نسخه‌ی برنامه، سیستم‌عامل و گزارش خطا/کرش برای رفع اشکال؛ زمان آخرین حضور آنلاین.\n'
          '• دستیار اوراکل: پیام‌هایی که به دستیار هوش مصنوعی می‌دهی برای ساخت پاسخ به ارائه‌دهنده‌ی هوش مصنوعی فرستاده می‌شود.'),
  LegalSection('چرا استفاده می‌کنیم',
      'برای ورود و نگه‌داری حساب، اجرای مسابقه‌ها و رتبه‌بندی، نمایش پروفایل و چت به کسانی که اجازه داده‌ای، تحویل خریدها، جلوگیری از تقلب و سوءاستفاده، رسیدگی به گزارش‌ها و رفع خطاها.'),
  LegalSection('چه کسانی می‌بینند',
      'نام کاربری، تصویر و آمار بازی برای بازیکنان دیگر نمایش داده می‌شود. پست‌ها طبق تنظیم حریم خصوصی حسابت دیده می‌شوند و پیام‌های چت فقط برای اعضای همان گفتگو. مدیران برای رسیدگی به گزارش‌ها و تخلف‌ها به محتوای گزارش‌شده دسترسی دارند. داده‌ها روی سرورهای Supabase (اتحادیه‌ی اروپا)، صدا از طریق LiveKit و پرداخت از طریق کافه‌بازار پردازش می‌شود.'),
  LegalSection('نگه‌داری و حذف',
      'داده‌ها تا زمانی که حسابت فعال است نگه‌داری می‌شوند. هر وقت بخواهی از «تنظیمات ← حساب و داده ← حذف همیشگی حساب کاربری» حسابت را حذف کن: پروفایل، کیف پول، پست‌ها، دنبال‌کننده‌ها، سابقه‌ی بازی و فایل‌هایت پاک می‌شوند و پیام‌هایی که در گفتگوی دیگران فرستاده‌ای بدون نام باقی می‌مانند. سوابق مالی ضروری (مثل دفتر تورنمنت) فقط با شناسه‌ی بی‌نام نگه داشته می‌شوند. گزارش‌های خطا پس از ۳۰ روز پاک می‌شوند.'),
  LegalSection('امنیت',
      'ارتباط با سرور رمزنگاری‌شده است، رمزها هش می‌شوند و دسترسی به داده‌ها با قوانین سطح ردیف کنترل می‌شود. هیچ سیستمی کاملاً بی‌خطر نیست؛ رمز قوی انتخاب کن و آن را به کسی نده.'),
  LegalSection('کودکان',
      'آنیکس برای افراد کمتر از ۱۳ سال نیست. اگر کمتر از ۱۸ سال داری، با اجازه‌ی پدر یا مادرت استفاده کن. اگر فکر می‌کنی کودکی بدون اجازه حساب ساخته، گزارش بده تا حذف شود.'),
  LegalSection('تغییرات و تماس',
      'اگر این سیاست تغییر مهمی کند، در برنامه اطلاع می‌دهیم. برای پرسش یا درخواست درباره‌ی داده‌هایت از نشانی تماس صفحه‌ی برنامه در فروشگاه یا گزارش داخل برنامه استفاده کن.'),
];

const List<LegalSection> privacyEn = <LegalSection>[
  LegalSection('Summary',
      'ANIX is a gaming and social app. We only collect what is needed to run your account, online games, chat and calls, in-app purchases and safety features. We do not sell your data or use it for targeted advertising.'),
  LegalSection('What we collect',
      '• Account: username, password (stored hashed), and your email if you add one (used only for recovery).\n'
          '• Profile: display name, avatar, bio and privacy settings.\n'
          '• Games: match history, scores and ratings, tournaments, coins and gems, items and achievements.\n'
          '• Social: follows, posts and stories, comments and likes, chat messages and the files you send (photos, voice, files), groups and communities, reports and blocked users.\n'
          '• Voice and video: calls and voice rooms are relayed live through a media server; we do not record or store them.\n'
          '• Purchases: the Cafe Bazaar order token and product, to deliver coins/gems. We never receive your card details.\n'
          '• Technical: app version, operating system and error/crash reports to fix bugs; your last-online time.\n'
          '• ORACLE assistant: messages you send to the AI assistant are sent to an AI provider to generate replies.'),
  LegalSection('Why we use it',
      'To sign you in and keep your account, run matches and rankings, show your profile and chats to the people you allow, deliver purchases, prevent cheating and abuse, handle reports and fix errors.'),
  LegalSection('Who can see it',
      'Your username, avatar and game stats are visible to other players. Posts follow your account privacy setting, and chat messages are visible only to the members of that chat. Moderators can see reported content to handle reports. Data is processed by Supabase (EU servers), voice by LiveKit and payments by Cafe Bazaar.'),
  LegalSection('Retention and deletion',
      'We keep your data while your account exists. You can delete your account at any time in Settings → Account & data → Delete account permanently: your profile, wallet, posts, followers, match history and files are erased, and messages you sent in other people\'s chats stay without your name. Records needed for accounting (such as the tournament ledger) are kept only under an anonymous id. Error reports are deleted after 30 days.'),
  LegalSection('Security',
      'Traffic is encrypted, passwords are hashed, and data access is enforced with row-level security rules. No system is perfectly secure; use a strong password and never share it.'),
  LegalSection('Children',
      'ANIX is not for children under 13. If you are under 18, use it with a parent\'s permission. If you believe a child created an account without permission, report it and we will remove it.'),
  LegalSection('Changes and contact',
      'We will announce material changes in the app. For questions or data requests, use the contact address on the app\'s store page or the in-app report.'),
];

const List<LegalSection> termsFa = <LegalSection>[
  LegalSection('پذیرش',
      'با ساختن حساب یا استفاده از آنیکس این شرایط و سیاست حریم خصوصی را می‌پذیری. باید دست‌کم ۱۳ سال داشته باشی و اگر کمتر از ۱۸ سال داری، با اجازه‌ی والدینت استفاده کنی.'),
  LegalSection('حساب کاربری',
      'مسئول امنیت حساب و رمزت هستی. هر نفر یک حساب شخصی دارد؛ خرید و فروش یا واگذاری حساب مجاز نیست. نام کاربری نباید توهین‌آمیز باشد یا خودت را به جای مدیران یا تیم آنیکس جا بزنی.'),
  LegalSection('رفتار در برنامه',
      'ممنوع است: توهین، آزار و تهدید، محتوای جنسی یا خشونت‌آمیز، نفرت‌پراکنی، اسپم و تبلیغ، انتشار اطلاعات شخصی دیگران، جعل هویت، تقلب، استفاده از باگ یا ابزار غیرمجاز، و هر کار غیرقانونی. فیلتر کلمات ممکن است متن نامناسب را رد یا پوشانده کند.'),
  LegalSection('نظارت',
      'می‌توانی کاربر، پیام، پروفایل یا کامیونیتی را گزارش یا مسدود کنی. مدیران ممکن است محتوا را حذف کنند، یا حساب را محدود، بی‌صدا یا مسدود کنند. حساب مسدود نمی‌تواند بازی، چت یا خرید کند.'),
  LegalSection('سکه، جم و خرید',
      'سکه، جم و آیتم‌ها اعتبار مجازی داخل بازی‌اند، ارزش پولی ندارند، قابل تبدیل به پول یا انتقال خارج از برنامه نیستند و جز در مواردی که قانون یا کافه‌بازار الزام کند، برگشت داده نمی‌شوند. سوءاستفاده یا بازپرداخت متقلبانه ممکن است به کسر موجودی یا مسدودی منجر شود.'),
  LegalSection('محتوای تو',
      'مالکیت محتوایی که منتشر می‌کنی با خودت است؛ با انتشار آن به آنیکس اجازه می‌دهی آن را برای اجرای سرویس ذخیره و به افرادی که تعیین کرده‌ای نمایش دهد. فقط محتوایی بفرست که حق انتشارش را داری.'),
  LegalSection('دسترسی به سرویس',
      'سرویس ممکن است برای به‌روزرسانی یا نگه‌داری موقتاً در دسترس نباشد و برای ادامه‌ی استفاده نصب نسخه‌ی تازه لازم شود. بازی‌ها، قیمت‌ها و ویژگی‌ها ممکن است تغییر کنند.'),
  LegalSection('مسئولیت',
      'آنیکس «همان‌طور که هست» ارائه می‌شود. تا جایی که قانون اجازه می‌دهد، مسئول خسارت غیرمستقیم یا از دست رفتن داده‌ی ناشی از قطعی اینترنت، رفتار کاربران دیگر یا خطای دستگاه نیستیم.'),
  LegalSection('پایان استفاده',
      'هر زمان می‌توانی حسابت را از تنظیمات حذف کنی. در صورت نقض این شرایط ممکن است حساب محدود یا بسته شود. تغییرات مهم این شرایط در برنامه اعلام می‌شود.'),
];

const List<LegalSection> termsEn = <LegalSection>[
  LegalSection('Acceptance',
      'By creating an account or using ANIX you accept these Terms and the Privacy Policy. You must be at least 13, and if you are under 18 you need a parent\'s permission.'),
  LegalSection('Your account',
      'You are responsible for keeping your account and password safe. Accounts are personal; selling, buying or transferring them is not allowed. Usernames must not be offensive or impersonate moderators or the ANIX team.'),
  LegalSection('Conduct',
      'Not allowed: insults, harassment and threats, sexual or violent content, hate speech, spam and advertising, sharing other people\'s personal information, impersonation, cheating, exploiting bugs or using unauthorised tools, and anything illegal. The word filter may reject or mask inappropriate text.'),
  LegalSection('Moderation',
      'You can report or block users, messages, profiles and communities. Moderators may remove content, and restrict, mute or ban accounts. A banned account cannot play, chat or buy.'),
  LegalSection('Coins, gems and purchases',
      'Coins, gems and items are virtual in-game credit with no monetary value; they cannot be exchanged for money or moved outside the app, and are not refundable except where the law or Cafe Bazaar requires it. Abuse or fraudulent refunds may lead to balance deductions or a ban.'),
  LegalSection('Your content',
      'You own what you post; by posting it you allow ANIX to store it and show it to the people you chose, to run the service. Only post content you have the right to share.'),
  LegalSection('Service availability',
      'The service may be unavailable for updates or maintenance, and a new version may be required to keep using it. Games, prices and features may change.'),
  LegalSection('Liability',
      'ANIX is provided "as is". To the extent the law allows, we are not liable for indirect damage or data loss caused by network outages, other users\' behaviour or device errors.'),
  LegalSection('Ending use',
      'You can delete your account from Settings at any time. Accounts that break these Terms may be restricted or closed. Material changes to these Terms will be announced in the app.'),
];
