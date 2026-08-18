// Seed script: Inserts 7 days of random puff events, sessions, and an
// addiction score for raj@gmail.com via the Supabase REST API.
//
// Run with:  dart run lib/seed_data.dart

import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

Future<void> main() async {
  // Load env
  await dotenv.load(fileName: '.env');

  final url = dotenv.env['SUPABASE_URL']!;
  final anonKey = dotenv.env['SUPABASE_ANON_KEY']!;

  await Supabase.initialize(url: url, anonKey: anonKey);
  final supabase = Supabase.instance.client;

  final seedEmail = dotenv.env['SEED_USER_EMAIL'] ?? 'test@example.com';
  final seedPassword = dotenv.env['SEED_USER_PASSWORD'] ?? 'testpassword123';

  print('Signing in as $seedEmail...');
  final authRes = await supabase.auth.signInWithPassword(
    email: seedEmail,
    password: seedPassword,
  );

  final userId = authRes.user?.id;
  if (userId == null) {
    print('Login failed. Check email/password.');
    return;
  }
  print('Signed in. User ID: $userId');

  final rand = Random(42); // fixed seed for reproducible data
  final uuid = const Uuid();
  final now = DateTime.now();

  // --- Generate 7 days of data ---
  int totalPuffs = 0;
  int totalSessions = 0;

  for (int daysAgo = 6; daysAgo >= 0; daysAgo--) {
    final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysAgo));
    final dayLabel = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

    // Random 1-3 sessions per day
    final sessionCount = 1 + rand.nextInt(3);
    // Random 5-25 puffs per day (realistic range)
    final dailyPuffs = 5 + rand.nextInt(21);

    print('\nDay $dayLabel: $dailyPuffs puffs across $sessionCount sessions');

    // Distribute puffs across sessions
    List<int> puffsPerSession = List.filled(sessionCount, dailyPuffs ~/ sessionCount);
    // Add remainder to first session
    puffsPerSession[0] += dailyPuffs % sessionCount;

    int puffIndex = 0;
    for (int s = 0; s < sessionCount; s++) {
      final sessionId = uuid.v4();
      // Spread sessions across waking hours (7 AM - 11 PM)
      final sessionStartHour = 7 + ((16 * s) ~/ sessionCount) + rand.nextInt(2);
      final sessionStart = day.add(Duration(
        hours: sessionStartHour,
        minutes: rand.nextInt(60),
      ));

      final puffsInThisSession = puffsPerSession[s];
      final avgInterval = 30.0 + rand.nextDouble() * 180; // 30s - 210s between puffs
      final sessionDurationMin = (puffsInThisSession * avgInterval / 60).round();
      final sessionEnd = sessionStart.add(Duration(minutes: sessionDurationMin.clamp(2, 60)));

      // Insert session
      await supabase.from('sessions').insert({
        'id': sessionId,
        'user_id': userId,
        'started_at': sessionStart.toUtc().toIso8601String(),
        'ended_at': sessionEnd.toUtc().toIso8601String(),
        'puff_count': puffsInThisSession,
        'avg_interval_sec': avgInterval.roundToDouble(),
      });

      print('   Session ${s + 1}: $puffsInThisSession puffs, ${sessionDurationMin}min '
          '(${sessionStart.hour}:${sessionStart.minute.toString().padLeft(2, '0')} - '
          '${sessionEnd.hour}:${sessionEnd.minute.toString().padLeft(2, '0')})');

      // Insert puff events for this session
      for (int p = 0; p < puffsInThisSession; p++) {
        final puffTime = sessionStart.add(Duration(
          seconds: (p * avgInterval).round() + rand.nextInt(20),
        ));

        // Mix of input modes: ~60% manual, ~25% video_upload, ~15% live_camera
        final modeRoll = rand.nextDouble();
        final inputMode = modeRoll < 0.60 ? 'manual'
            : modeRoll < 0.85 ? 'video_upload'
            : 'live_camera';

        // Confidence score: null for manual, 0.55-0.98 for detected
        final confidence = inputMode == 'manual'
            ? null
            : (0.55 + rand.nextDouble() * 0.43);

        await supabase.from('puff_events').insert({
          'id': uuid.v4(),
          'user_id': userId,
          'session_id': sessionId,
          'detected_at': puffTime.toUtc().toIso8601String(),
          'input_mode': inputMode,
          'confidence_score': confidence != null ? double.parse(confidence.toStringAsFixed(3)) : null,
        });

        puffIndex++;
      }

      totalPuffs += puffsInThisSession;
      totalSessions++;
    }
  }

  // --- Insert addiction score ---
  final dailyAvg = totalPuffs / 7;
  String level;
  double scoreValue;
  String topFeature;

  if (dailyAvg > 20) {
    level = 'high';
    scoreValue = 70 + rand.nextInt(25).toDouble();
    topFeature = 'High daily puff count';
  } else if (dailyAvg > 10) {
    level = 'moderate';
    scoreValue = 40 + rand.nextInt(25).toDouble();
    topFeature = 'Frequent short-interval sessions';
  } else {
    level = 'low';
    scoreValue = 10 + rand.nextInt(25).toDouble();
    topFeature = 'Low usage volume';
  }

  await supabase.from('addiction_scores').insert({
    'id': uuid.v4(),
    'user_id': userId,
    'scored_at': now.toUtc().toIso8601String(),
    'level': level,
    'score_value': scoreValue,
    'top_feature': topFeature,
  });

  print('\n====================================');
  print('SEED COMPLETE');
  print('   $totalPuffs puff events across $totalSessions sessions over 7 days');
  print('   Daily average: ${dailyAvg.toStringAsFixed(1)} puffs/day');
  print('   Addiction score: $level ($scoreValue/100)');
  print('   Top feature: $topFeature');
  print('====================================');

  await supabase.auth.signOut();
  print('\nSigned out. Done!');
}
