import 'dart:collection';
import '../../data/datasources/local/database_manager.dart';
import 'package:sqflite/sqflite.dart';

class SenderReputationManager {
  static const int _velocityThreshold = 5;
  static const int _callBotThreshold = 3;
  static const Duration _window = Duration(minutes: 5);

  /// Records a call and returns risk score. 
  Future<double> updateCallReputation(String senderHash) async {
    final db = await DatabaseManager.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final List<Map<String, dynamic>> maps = await db.query(
      'reputation',
      where: 'sender_hash = ?',
      whereArgs: [senderHash],
    );

    if (maps.isEmpty) {
      await db.insert('reputation', {
        'sender_hash': senderHash,
        'last_call_at': now,
        'call_count': 1,
      });
      return 0.0;
    }

    final data = maps.first;
    final lastCallAt = data['last_call_at'] as int? ?? 0;
    final callCount = data['call_count'] as int? ?? 0;

    // Reset count if it's been more than an hour
    if (now - lastCallAt > 3600000) {
      await db.update('reputation', {
        'last_call_at': now,
        'call_count': 1,
      }, where: 'sender_hash = ?', whereArgs: [senderHash]);
      return 0.0;
    }

    final newCount = callCount + 1;
    await db.update('reputation', {
      'last_call_at': now,
      'call_count': newCount,
    }, where: 'sender_hash = ?', whereArgs: [senderHash]);

    if (newCount >= _callBotThreshold) {
      return 0.5 + (newCount * 0.1);
    }
    return 0.0;
  }

  /// Records a message and returns risk score based on velocity.
  Future<double> updateReputation(String senderHash) async {
    final db = await DatabaseManager.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final List<Map<String, dynamic>> maps = await db.query(
      'reputation',
      where: 'sender_hash = ?',
      whereArgs: [senderHash],
    );

    if (maps.isEmpty) {
      await db.insert('reputation', {
        'sender_hash': senderHash,
        'last_message_at': now,
        'message_count': 1,
      });
      return 0.0;
    }

    final data = maps.first;
    final lastMsgAt = data['last_message_at'] as int? ?? 0;
    final msgCount = data['message_count'] as int? ?? 0;

    // Reset count if outside velocity window (5 mins)
    if (now - lastMsgAt > _window.inMilliseconds) {
      await db.update('reputation', {
        'last_message_at': now,
        'message_count': 1,
      }, where: 'sender_hash = ?', whereArgs: [senderHash]);
      return 0.0;
    }

    final newCount = msgCount + 1;
    await db.update('reputation', {
      'last_message_at': now,
      'message_count': newCount,
    }, where: 'sender_hash = ?', whereArgs: [senderHash]);

    if (newCount > _velocityThreshold) {
      return (newCount / _velocityThreshold) * 0.2; 
    }
    
    return 0.0;
  }
}
