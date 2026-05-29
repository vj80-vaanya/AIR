import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/utils/extensions.dart';

class OtpManagerScreen extends StatefulWidget {
  const OtpManagerScreen({super.key});
  @override
  State<OtpManagerScreen> createState() => _OtpManagerScreenState();
}

class _OtpManagerScreenState extends State<OtpManagerScreen>
    with WidgetsBindingObserver {
  static const _ch = MethodChannel('ai_security/device_data');

  List<_OtpEntry> _otps  = [];
  bool            _loading = true;
  String?         _error;

  // OTP patterns — 4–8 digit codes
  static final _otpRegex = RegExp(
    r'\b(\d{4,8})\b',
    caseSensitive: false,
  );
  static final _otpKeywords = [
    'otp', 'one time', 'one-time', 'verification code', 'pin',
    'passcode', 'code is', 'code:', 'is your', 'use code',
    'do not share', 'never share', 'expires in',
  ];
  static final _bankKeywords = [
    'sbi', 'hdfc', 'icici', 'axis', 'kotak', 'pnb', 'bob', 'canara',
    'union', 'idfc', 'yes bank', 'indusind', 'rbl', 'federal',
    'amazon', 'flipkart', 'paytm', 'phonepe', 'gpay', 'google pay',
    'zomato', 'swiggy', 'myntra', 'uber', 'ola', 'irctc',
    'uidai', 'aadhaar', 'income tax', 'epfo',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await _ch.invokeListMethod<Map>('getSmsInbox', {'limit': 200});
      final entries = <_OtpEntry>[];

      for (final msg in (raw ?? [])) {
        final sender = msg['sender']?.toString() ?? '';
        final body   = msg['body']?.toString() ?? '';
        final date   = msg['date'] as int? ?? 0;
        final lower  = body.toLowerCase();

        // Must contain OTP keywords AND a digit sequence
        final hasOtpKeyword = _otpKeywords.any(lower.contains);
        if (!hasOtpKeyword) continue;

        final match = _otpRegex.firstMatch(body);
        if (match == null) continue;

        final code   = match.group(1)!;
        final bank   = _bankKeywords.firstWhere(
          (k) => lower.contains(k),
          orElse: () => '',
        );
        final ts     = DateTime.fromMillisecondsSinceEpoch(date);
        final age    = DateTime.now().difference(ts).inMinutes;
        final expired = age > 15; // OTPs are usually valid 5–10 min

        entries.add(_OtpEntry(
          code:     code,
          sender:   sender,
          service:  bank.isNotEmpty ? _capitalise(bank) : sender,
          body:     body,
          time:     ts,
          expired:  expired,
        ));

        if (entries.length >= 30) break;
      }

      setState(() { _otps = entries; _loading = false; });
    } on PlatformException catch (e) {
      setState(() { _loading = false; _error = e.message; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OTP Manager'),
        actions: [
          IconButton(
            icon:      const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _PermError(error: _error!, isDark: isDark)
              : _otps.isEmpty
                  ? _EmptyOtp(isDark: isDark)
                  : _OtpList(otps: _otps, isDark: isDark),
    );
  }
}

// ── List ──────────────────────────────────────────────────────────────────────

class _OtpList extends StatelessWidget {
  const _OtpList({required this.otps, required this.isDark});
  final List<_OtpEntry> otps;
  final bool            isDark;

  @override
  Widget build(BuildContext context) {
    final active  = otps.where((o) => !o.expired).toList();
    final expired = otps.where((o) =>  o.expired).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, 100),
      children: [
        if (active.isNotEmpty) ...[
          _SectionLabel(label: 'ACTIVE', color: AppColors.secondary),
          const SizedBox(height: 8),
          ...active.map((o) => _OtpCard(otp: o, isDark: isDark)),
          const SizedBox(height: Spacing.md),
        ],
        if (expired.isNotEmpty) ...[
          _SectionLabel(
              label: 'EXPIRED',
              color: AppColors.textSecondary),
          const SizedBox(height: 8),
          ...expired.map((o) => _OtpCard(otp: o, isDark: isDark)),
        ],
        const SizedBox(height: Spacing.md),
        _PrivacyNote(isDark: isDark),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.color});
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(
          fontSize:   11,
          fontWeight: FontWeight.w700,
          color:      color,
          letterSpacing: 1.0,
        ),
      );
}

class _OtpCard extends StatelessWidget {
  const _OtpCard({required this.otp, required this.isDark});
  final _OtpEntry otp;
  final bool      isDark;

  @override
  Widget build(BuildContext context) {
    final color = otp.expired ? AppColors.textDisabled : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: otp.expired
              ? (isDark ? AppColors.borderDark : AppColors.border)
              : AppColors.primary.withOpacity(0.30),
          width: otp.expired ? 1 : 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Service icon
                Container(
                  width:  40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:        color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Icons.lock_rounded, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        otp.service,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                        maxLines:  1,
                        overflow:  TextOverflow.ellipsis,
                      ),
                      Text(
                        otp.time.relativeTime,
                        style: TextStyle(
                          color:    AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (otp.expired)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:        AppColors.textDisabled.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Expired',
                      style: TextStyle(
                        color:      AppColors.textDisabled,
                        fontSize:   11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // OTP code + copy
            Row(
              children: [
                Expanded(
                  child: Text(
                    otp.code,
                    style: TextStyle(
                      fontSize:      32,
                      fontWeight:    FontWeight.w900,
                      letterSpacing: 8,
                      color:         otp.expired
                          ? AppColors.textDisabled
                          : (context.isDark ? Colors.white : AppColors.textPrimary),
                    ),
                  ),
                ),
                if (!otp.expired)
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: otp.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('OTP ${otp.code} copied'),
                          backgroundColor: AppColors.secondary,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.gradientStart, AppColors.gradientEnd],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color:  AppColors.primary.withOpacity(0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded,
                              color: Colors.white, size: 14),
                          SizedBox(width: 5),
                          Text(
                            'Copy',
                            style: TextStyle(
                              color:      Colors.white,
                              fontSize:   13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty / error states ──────────────────────────────────────────────────────

class _EmptyOtp extends StatelessWidget {
  const _EmptyOtp({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width:  80,
                height: 80,
                decoration: BoxDecoration(
                  color:  AppColors.secondary.withOpacity(0.12),
                  shape:  BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_open_rounded,
                  color: AppColors.secondary,
                  size:  40,
                ),
              ),
              const SizedBox(height: 20),
              const Text('No recent OTPs',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'OTPs from your SMS inbox will appear here for quick copying.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      );
}

class _PermError extends StatelessWidget {
  const _PermError({required this.error, required this.isDark});
  final String error;
  final bool   isDark;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sms_failed_rounded,
                  size: 64, color: AppColors.warning),
              const SizedBox(height: 16),
              const Text('SMS permission needed',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:        isDark
              ? AppColors.borderDark.withOpacity(0.4)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_rounded,
                color: AppColors.secondary, size: 15),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'OTPs are read locally. Nothing leaves your device.',
                style: TextStyle(
                  fontSize: 12,
                  color:    isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
}

// ── Data ──────────────────────────────────────────────────────────────────────

class _OtpEntry {
  const _OtpEntry({
    required this.code,
    required this.sender,
    required this.service,
    required this.body,
    required this.time,
    required this.expired,
  });
  final String   code, sender, service, body;
  final DateTime time;
  final bool     expired;
}
