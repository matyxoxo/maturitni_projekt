// Kurátorovaná mapa: náš cvik v DB -> cvik na Strength Levelu.
//
// Pravidla, podle kterých je seznam sestavený:
//  * Mapuje se jen cvik, který v našem katalogu opravdu existuje
//    (`supabase/seed.sql`, type `weight_reps`).
//  * Musí jít o stejný pohyb a stejné náčiní. Podobný název nestačí –
//    `Barbell Hack Squat` není `Sled Hack Squat` a `Dumbbell Deadlift`
//    není `Deadlift`.
//  * Vybírá se konkrétní varianta, ne obecný název. Když Strength Level
//    rozlišuje `Dumbbell Curl` a `Seated Dumbbell Curl`, náš sedící cvik
//    jde na sedící standard.
//  * `perHand: true` = Strength Level bere u jednoruček váhu jedné činky
//    (jejich FAQ to říká výslovně), což je i to, co uživatel zapisuje.
//  * Cviky bez jednoznačné předlohy se vůbec nemapují. Radši míň cviků
//    než špatný standard.
//
// Tuhle mapu používá `tool/generate_rank_standards.dart`. Každá změna se
// musí ověřit proti stránce cviku na Strength Levelu, ne jen podle názvu.

class RankMapping {
  const RankMapping(
    this.ourName,
    this.slug, {
    this.perHand = false,
    this.aliases = const [],
  });

  /// Přesný název v `exercises.exercise_name`.
  final String ourName;

  /// Slug stránky na Strength Levelu.
  final String slug;

  /// Váha se zapisuje za jednu činku.
  final bool perHand;

  /// Další názvy, které mají spadnout na stejný standard.
  final List<String> aliases;
}

const List<RankMapping> rankMappings = [
  // ============================================================
  //  CHEST
  // ============================================================
  RankMapping('Barbell Bench Press', 'bench-press'),
  RankMapping(
    'Smith Bench Press',
    'smith-machine-bench-press',
    aliases: ['Smith Machine Bench Press'],
  ),
  RankMapping('Barbell Incline Bench Press', 'incline-bench-press'),
  RankMapping('Barbell Decline Bench Press', 'decline-bench-press'),
  RankMapping('Barbell Close-grip Bench Press', 'close-grip-bench-press'),
  RankMapping(
    'Barbell Incline Close Grip Bench Press',
    'close-grip-incline-bench-press',
  ),
  RankMapping('Barbell Wide Bench Press', 'wide-grip-bench-press'),
  RankMapping('Dumbbell Bench Press', 'dumbbell-bench-press', perHand: true),
  RankMapping(
    'Dumbbell Incline Bench Press',
    'incline-dumbbell-bench-press',
    perHand: true,
  ),
  RankMapping(
    'Dumbbell Decline Bench Press',
    'decline-dumbbell-bench-press',
    perHand: true,
  ),
  RankMapping(
    'Dumbbell Close Grip Press',
    'close-grip-dumbbell-bench-press',
    perHand: true,
  ),
  RankMapping('Dumbbell Fly', 'dumbbell-fly', perHand: true),
  RankMapping('Dumbbell Incline Fly', 'incline-dumbbell-fly', perHand: true),
  RankMapping('Dumbbell Decline Fly', 'decline-dumbbell-fly', perHand: true),
  RankMapping(
    'Dumbbell Pullover',
    'dumbbell-pullover',
    perHand: true,
    aliases: ['Dumbbell Straight Arm Pullover'],
  ),
  RankMapping('Lever Chest Press', 'chest-press'),
  RankMapping('Lever Seated Fly', 'machine-chest-fly'),
  RankMapping('Barbell Bent Arm Pullover', 'bent-arm-barbell-pullover'),
  RankMapping('Cable Standing Fly', 'cable-fly', aliases: ['Cable Middle Fly']),

  // ============================================================
  //  BACK
  // ============================================================
  RankMapping('Barbell Bent Over Row', 'bent-over-row'),
  RankMapping(
    'Barbell Reverse Grip Bent Over Row',
    'yates-row',
    aliases: ['Yates Row'],
  ),
  RankMapping('Barbell Pendlay Row', 'pendlay-row'),
  RankMapping('Barbell Shrug', 'barbell-shrug'),
  RankMapping('Barbell Pullover', 'barbell-pullover'),
  RankMapping('Lever T Bar Row', 't-bar-row'),
  RankMapping('Lever Seated Row', 'machine-row'),
  RankMapping('Lever Shrug', 'machine-shrug'),
  RankMapping('Lever Back Extension', 'machine-back-extension'),
  RankMapping(
    'Cable Bar Lateral Pulldown',
    'lat-pulldown',
    aliases: ['Lat Pulldown', 'Cable Pulldown'],
  ),
  RankMapping(
    'Cable Seated Row',
    'seated-cable-row',
    aliases: ['Seated Cable Row'],
  ),
  RankMapping('Cable Shrug', 'cable-shrug'),
  RankMapping('Cable Straight Arm Pulldown', 'straight-arm-pulldown'),
  RankMapping('Cable Underhand Pulldown', 'reverse-grip-lat-pulldown'),
  RankMapping('Cable Cross-over Revers Fly', 'cable-reverse-fly'),
  RankMapping('Cable One Arm Pulldown', 'one-arm-lat-pulldown'),
  RankMapping('Cable Lateral Pulldown with V-bar', 'close-grip-lat-pulldown'),
  RankMapping(
    'Dumbbell Bent Over Row',
    'bent-over-dumbbell-row',
    perHand: true,
  ),
  RankMapping('Dumbbell One Arm Bent-over Row', 'dumbbell-row', perHand: true),
  RankMapping('Dumbbell Shrug', 'dumbbell-shrug', perHand: true),
  RankMapping(
    'Dumbbell Incline Row',
    'chest-supported-dumbbell-row',
    perHand: true,
  ),
  RankMapping('Smith Shrug', 'smith-machine-shrug'),
  RankMapping('Trap Bar Deadlift', 'hex-bar-deadlift'),

  // ============================================================
  //  LEGS – quadriceps / hamstrings / glutes
  // ============================================================
  RankMapping(
    'Barbell Full Squat',
    'squat',
    aliases: ['Barbell Squat', 'Back Squat'],
  ),
  RankMapping(
    'Barbell Front Squat',
    'front-squat',
    aliases: ['Barbell Clean-grip Front Squat'],
  ),
  RankMapping('Barbell Overhead Squat', 'overhead-squat'),
  RankMapping('Barbell Zercher Squat', 'zercher-squat'),
  RankMapping('Barbell Jefferson Squat', 'jefferson-squat'),
  RankMapping('Barbell Hack Squat', 'barbell-hack-squat'),
  RankMapping('Sled Hack Squat', 'hack-squat', aliases: ['Hack Squat']),
  RankMapping('Smith Squat', 'smith-machine-squat'),
  RankMapping('Barbell Single Leg Split Squat', 'split-squat'),
  RankMapping(
    'Dumbbell Single Leg Split Squat',
    'dumbbell-split-squat',
    perHand: true,
  ),
  RankMapping('Dumbbell Goblet Squat', 'goblet-squat', perHand: true),
  RankMapping('Dumbbell Squat', 'dumbbell-squat', perHand: true),
  RankMapping('Barbell Lunge', 'barbell-lunge'),
  RankMapping('Barbell Rear Lunge', 'barbell-reverse-lunge'),
  RankMapping('Dumbbell Lunge', 'dumbbell-lunge', perHand: true),
  RankMapping(
    'Sled 45° Leg Press',
    'sled-leg-press',
    aliases: [
      'Leg Press',
      'Sled 45?° Leg Press',
      'Sled Leg Press',
      'Lever Leg Press',
    ],
  ),
  RankMapping('Lever Horizontal One Leg Press', 'single-leg-press'),
  RankMapping(
    'Lever Leg Extension',
    'leg-extension',
    aliases: ['Leg Extension'],
  ),
  RankMapping(
    'Lever Lying Leg Curl',
    'lying-leg-curl',
    aliases: ['Lying Leg Curl'],
  ),
  RankMapping('Lever Seated Leg Curl', 'seated-leg-curl'),
  RankMapping('Barbell Deadlift', 'deadlift'),
  RankMapping('Dumbbell Deadlift', 'dumbbell-deadlift', perHand: true),
  RankMapping('Barbell Romanian Deadlift', 'romanian-deadlift'),
  RankMapping('Barbell Straight Leg Deadlift', 'stiff-leg-deadlift'),
  RankMapping('Barbell Single Leg Deadlift', 'single-leg-deadlift'),
  RankMapping(
    'Dumbbell Single Leg Deadlift',
    'single-leg-dumbbell-deadlift',
    perHand: true,
  ),
  RankMapping(
    'Dumbbell Romanian Deadlift',
    'dumbbell-romanian-deadlift',
    perHand: true,
  ),
  RankMapping('Barbell Sumo Deadlift', 'sumo-deadlift'),
  RankMapping('Power Clean', 'power-clean'),
  RankMapping('Snatch Pull', 'snatch-pull'),
  RankMapping('Dumbbell One Arm Snatch', 'dumbbell-snatch', perHand: true),
  RankMapping('Barbell Clean and Press', 'clean-and-press'),
  RankMapping('Barbell Rack Pull', 'rack-pull'),
  RankMapping('Barbell Glute Bridge', 'barbell-glute-bridge'),
  RankMapping('Barbell Thruster', 'thruster'),
  RankMapping('Barbell Good Morning', 'good-morning'),
  RankMapping('Lever Seated Hip Abduction', 'hip-abduction'),
  RankMapping('Lever Seated Hip Adduction', 'hip-adduction'),
  RankMapping('Cable Pull Through (with Rope)', 'cable-pull-through'),
  RankMapping('Cable Kickback', 'cable-kickback'),

  // ============================================================
  //  LEGS – calves
  // ============================================================
  RankMapping('Barbell Standing Calf Raise', 'barbell-calf-raise'),
  RankMapping(
    'Dumbbell Standing Calf Raise',
    'dumbbell-calf-raise',
    perHand: true,
  ),
  RankMapping('Lever Standing Calf Raise', 'machine-calf-raise'),
  RankMapping('Lever Seated Calf Raise', 'seated-calf-raise'),
  RankMapping('Sled Calf Press on Leg Press', 'sled-press-calf-raise'),

  // ============================================================
  //  SHOULDERS
  // ============================================================
  RankMapping(
    'Barbell Seated Overhead Press',
    'seated-shoulder-press',
    aliases: ['Overhead Press', 'Barbell Shoulder Press'],
  ),
  RankMapping('Standing Behind Neck Press', 'behind-the-neck-press'),
  RankMapping('Barbell Front Raise', 'barbell-front-raise'),
  RankMapping('Barbell Upright Row', 'upright-row'),
  RankMapping('Cable Upright Row', 'cable-upright-row'),
  RankMapping('Cable Lateral Raise', 'cable-lateral-raise'),
  RankMapping(
    'Cable Standing Shoulder External Rotation',
    'cable-external-rotation',
  ),
  RankMapping(
    'Dumbbell Upright Shoulder External Rotation',
    'dumbbell-external-rotation',
    perHand: true,
  ),
  RankMapping('Lever Shoulder Press', 'machine-shoulder-press'),
  RankMapping('Lever Lateral Raise', 'machine-lateral-raise'),
  RankMapping(
    'Lever Seated Reverse Fly',
    'machine-reverse-fly',
    aliases: ['Lever Seated Reverse Fly (parallel Grip)'],
  ),
  RankMapping(
    'Dumbbell Lateral Raise',
    'dumbbell-lateral-raise',
    perHand: true,
  ),
  RankMapping(
    'Dumbbell Seated Shoulder Press',
    'seated-dumbbell-shoulder-press',
    perHand: true,
  ),
  RankMapping(
    'Dumbbell Standing Overhead Press',
    'dumbbell-shoulder-press',
    perHand: true,
  ),
  RankMapping('Dumbbell Arnold Press', 'arnold-press', perHand: true),
  RankMapping('Dumbbell Front Raise', 'dumbbell-front-raise', perHand: true),
  RankMapping('Dumbbell Push Press', 'dumbbell-push-press', perHand: true),
  RankMapping('Dumbbell Upright Row', 'dumbbell-upright-row', perHand: true),
  RankMapping(
    'Dumbbell Incline Y-raise',
    'dumbbell-incline-y-raise',
    perHand: true,
  ),
  RankMapping('Dumbbell Reverse Fly', 'dumbbell-reverse-fly', perHand: true),

  // ============================================================
  //  ARMS – biceps
  // ============================================================
  RankMapping('Barbell Curl', 'barbell-curl'),
  RankMapping('Barbell Preacher Curl', 'preacher-curl'),
  RankMapping('Barbell Reverse Curl', 'reverse-barbell-curl'),
  RankMapping('Ez Barbell Curl', 'ez-bar-curl'),
  RankMapping('Ez Barbell Spider Curl', 'spider-curl'),
  RankMapping('Cable Curl', 'cable-bicep-curl'),
  RankMapping('Cable One Arm Curl', 'one-arm-cable-bicep-curl'),
  RankMapping('Cable Overhead Curl', 'overhead-cable-curl'),
  RankMapping('Cable Lying Bicep Curl', 'lying-cable-curl'),
  RankMapping('Cable Hammer Curl (with Rope)', 'cable-hammer-curl'),
  RankMapping('Cable Two Arm Curl on Incline Bench', 'incline-cable-curl'),
  RankMapping('Dumbbell Biceps Curl', 'dumbbell-curl', perHand: true),
  RankMapping(
    'Dumbbell Preacher Curl',
    'one-arm-dumbbell-preacher-curl',
    perHand: true,
    aliases: [
      'One Arm Dumbbell Preacher Curl',
      'Dumbbell One Arm Preacher Curl',
    ],
  ),
  RankMapping(
    'Dumbbell Seated Bicep Curl',
    'seated-dumbbell-curl',
    perHand: true,
  ),
  RankMapping(
    'Dumbbell Incline Curl',
    'incline-dumbbell-curl',
    perHand: true,
    aliases: ['Dumbbell Incline Biceps Curl', 'Incline Curl'],
  ),
  RankMapping('Dumbbell Hammer Curl', 'hammer-curl', perHand: true),
  RankMapping(
    'Dumbbell Incline Hammer Curl',
    'incline-hammer-curl',
    perHand: true,
  ),
  RankMapping(
    'Dumbbell Standing Reverse Curl',
    'dumbbell-reverse-curl',
    perHand: true,
  ),
  RankMapping(
    'Dumbbell Concentration Curl',
    'dumbbell-concentration-curl',
    perHand: true,
  ),
  RankMapping('Dumbbell Zottman Curl', 'zottman-curl', perHand: true),
  RankMapping('Lever Bicep Curl', 'machine-bicep-curl'),

  // ============================================================
  //  ARMS – triceps
  // ============================================================
  RankMapping(
    'Cable Pushdown',
    'tricep-pushdown',
    aliases: ['Tricep Pushdown', 'Triceps Pushdown'],
  ),
  RankMapping('Cable Pushdown (with Rope Attachment)', 'tricep-rope-pushdown'),
  RankMapping('Cable Reverse-grip Pushdown', 'reverse-grip-tricep-pushdown'),
  RankMapping(
    'Cable Overhead Triceps Extension (rope Attachment)',
    'cable-overhead-tricep-extension',
  ),
  RankMapping(
    'Lever Seated Dip',
    'seated-dip-machine',
    aliases: ['Seated Dip Machine', 'Seated Dip'],
  ),
  RankMapping('Lever Triceps Extension', 'machine-tricep-extension'),
  RankMapping('Barbell Lying Triceps Extension', 'lying-tricep-extension'),
  RankMapping(
    'Barbell Standing Overhead Triceps Extension',
    'tricep-extension',
  ),
  RankMapping('Barbell Jm Bench Press', 'jm-press'),
  RankMapping(
    'Dumbbell Lying Triceps Extension',
    'lying-dumbbell-tricep-extension',
    perHand: true,
  ),
  RankMapping(
    'Dumbbell One Arm Triceps Extension (on Bench)',
    'dumbbell-tricep-extension',
    perHand: true,
  ),
  RankMapping(
    'Dumbbell Seated Triceps Extension',
    'seated-dumbbell-tricep-extension',
    perHand: true,
  ),
  RankMapping('Dumbbell Kickback', 'dumbbell-tricep-kickback', perHand: true),
  RankMapping('Dumbbell Tate Press', 'tate-press', perHand: true),

  // ============================================================
  //  FOREARMS
  // ============================================================
  RankMapping('Barbell Wrist Curl', 'wrist-curl'),
  RankMapping('Barbell Reverse Wrist Curl', 'reverse-wrist-curl'),
  RankMapping(
    'Dumbbell Over Bench Wrist Curl',
    'dumbbell-wrist-curl',
    perHand: true,
  ),
  RankMapping(
    'Dumbbell Reverse Wrist Curl',
    'dumbbell-reverse-wrist-curl',
    perHand: true,
  ),

  // ============================================================
  //  CORE
  // ============================================================
  RankMapping(
    'Cable Kneeling Crunch',
    'cable-crunch',
    aliases: ['Cable Crunch'],
  ),
  RankMapping(
    'Cable Standing Crunch',
    'standing-cable-crunch',
    aliases: ['Cable Standing Crunch (with Rope Attachment)'],
  ),
  RankMapping(
    'Lever Seated Crunch',
    'machine-seated-crunch',
    aliases: ['Machine Seated Crunch', 'Seated Crunch Machine'],
  ),
  RankMapping('Dumbbell Side Bend', 'dumbbell-side-bend', perHand: true),
];
