import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/engine/security_engine.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/helpers.dart';
import '../../../services/background/image_scam_analyzer.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/risk_badge.dart';

class ManualScanScreen extends StatefulWidget {
  const ManualScanScreen({super.key});
  @override
  State<ManualScanScreen> createState() => _ManualScanScreenState();
}

class _ManualScanScreenState extends State<ManualScanScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl    = TextEditingController();
  final _focus   = FocusNode();
  bool  _scanning = false;
  _ScanResult? _result;

  late final AnimationController _resultAnim;

  @override
  void initState() {
    super.initState();
    _resultAnim = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _resultAnim.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    _focus.unfocus();
    setState(() { _scanning = true; _result = null; });
    _resultAnim.reset();

    final r = await SecurityEngine.instance.analyzeText(text);
    HapticFeedback.mediumImpact();

    setState(() {
      _scanning = false;
      _result   = _ScanResult(
        riskScore: r.riskScore,
        category:  r.category,
        reason:    r.reason,
        safe:      r.riskScore < 40,
      );
    });
    _resultAnim.forward();
  }

  static const _maxInputLength = 1500;

  Future<void> _scanImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    _focus.unfocus();
    setState(() { _scanning = true; _result = null; });
    _resultAnim.reset();

    final analyzer = ImageScamAnalyzer(SecurityEngine.instance);
    final r = await analyzer.analyzeImage(picked.path);
    HapticFeedback.mediumImpact();

    if (!mounted) return;
    setState(() {
      _scanning = false;
      _result   = _ScanResult(
        riskScore: r.riskScore,
        category:  r.category,
        reason:    r.reason,
        safe:      r.riskScore < 40,
      );
    });
    _resultAnim.forward();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      final text = data!.text!;
      final trimmed = text.length > _maxInputLength
          ? text.substring(0, _maxInputLength)
          : text;
      _ctrl.text = trimmed;
      _ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: trimmed.length),
      );
      if (text.length > _maxInputLength && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Text trimmed to 1500 characters for analysis.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      appBar: AppBar(title: const Text('Message Scanner')),
      body: GestureDetector(
        onTap: () => _focus.unfocus(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              Spacing.md, Spacing.sm, Spacing.md, 100),
          children: [
            // ── Header ─────────────────────────────────────────────────────
            _Header(isDark: isDark),
            const SizedBox(height: Spacing.lg),

            // ── Text input ─────────────────────────────────────────────────
            _InputCard(
              ctrl:        _ctrl,
              focus:       _focus,
              isDark:      isDark,
              onPaste:     _paste,
              onScanImage: _scanImage,
              onClear:     () => setState(() { _ctrl.clear(); _result = null; }),
            ),
            const SizedBox(height: Spacing.md),

            // ── Scan button ────────────────────────────────────────────────
            AppButton(
              label:     'Analyse Message',
              icon:      Icons.manage_search_rounded,
              loading:   _scanning,
              onPressed: _ctrl.text.trim().isEmpty ? null : _scan,
              minHeight: TouchTarget.primary,
            ),

            // ── Result ─────────────────────────────────────────────────────
            if (_result != null) ...[
              const SizedBox(height: Spacing.lg),
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _resultAnim,
                  curve:  Curves.easeOut,
                ),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end:   Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _resultAnim,
                    curve:  Curves.easeOutCubic,
                  )),
                  child: _ResultCard(result: _result!, isDark: isDark),
                ),
              ),
            ],

            const SizedBox(height: Spacing.xl),

            // ── Sample scams to test ───────────────────────────────────────
            _SampleSection(
              isDark: isDark,
              onSample: (text) {
                _ctrl.text = text;
                _ctrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: text.length),
                );
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:      AppColors.primary.withOpacity(0.28),
            blurRadius: 16,
            offset:     const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width:  52,
            height: 52,
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.psychology_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Scam Detector',
                  style: TextStyle(
                    color:      Colors.white,
                    fontSize:   17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Paste any suspicious message, email, or WhatsApp forward to check if it\'s a scam. Works offline — no internet needed.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input card ───────────────────────────────────────────────────────────────

class _InputCard extends StatefulWidget {
  const _InputCard({
    required this.ctrl,
    required this.focus,
    required this.isDark,
    required this.onPaste,
    required this.onScanImage,
    required this.onClear,
  });
  final TextEditingController ctrl;
  final FocusNode             focus;
  final bool                  isDark;
  final VoidCallback          onPaste;
  final VoidCallback          onScanImage;
  final VoidCallback          onClear;

  @override
  State<_InputCard> createState() => _InputCardState();
}

class _InputCardState extends State<_InputCard> {
  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        widget.isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.focus.hasFocus
              ? AppColors.primary
              : widget.isDark ? AppColors.borderDark : AppColors.border,
          width: widget.focus.hasFocus ? 2 : 1,
        ),
        boxShadow: widget.isDark
            ? []
            : [
                BoxShadow(
                  color:  Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                ),
              ],
      ),
      child: Column(
        children: [
          TextField(
            controller:  widget.ctrl,
            focusNode:   widget.focus,
            maxLines:    7,
            minLines:    4,
            maxLength:   1500,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) {
              if (!isFocused || currentLength < 1200) return null;
              return Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 4),
                child: Text(
                  '$currentLength / $maxLength',
                  style: TextStyle(
                    fontSize: 11,
                    color: currentLength >= 1500
                        ? AppColors.danger
                        : AppColors.textSecondary,
                  ),
                ),
              );
            },
            decoration: const InputDecoration(
              hintText: 'Paste the suspicious message here…\n\nE.g. "Your account will be blocked. Send OTP to verify."',
              border:      InputBorder.none,
              filled:      false,
              contentPadding: EdgeInsets.all(16),
            ),
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          // Toolbar
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                _ToolBtn(
                  icon:  Icons.content_paste_rounded,
                  label: 'Paste',
                  onTap: widget.onPaste,
                ),
                const SizedBox(width: 8),
                _ToolBtn(
                  icon:  Icons.image_search_rounded,
                  label: 'Scan Image',
                  onTap: widget.onScanImage,
                ),
                const Spacer(),
                if (widget.ctrl.text.isNotEmpty)
                  _ToolBtn(
                    icon:  Icons.close_rounded,
                    label: 'Clear',
                    onTap: widget.onClear,
                    color: AppColors.danger,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  const _ToolBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  final Color?       color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:        c.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c, size: 14),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: c, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Result card ──────────────────────────────────────────────────────────────

class _ScanResult {
  const _ScanResult({
    required this.riskScore,
    required this.category,
    required this.reason,
    required this.safe,
  });
  final int    riskScore;
  final String category;
  final String reason;
  final bool   safe;
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.isDark});
  final _ScanResult result;
  final bool        isDark;

  @override
  Widget build(BuildContext context) {
    final color = result.riskScore.riskColor;

    return Container(
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.40), width: 1.5),
        boxShadow: [
          BoxShadow(
            color:  color.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Score header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.85), color],
              ),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                RiskBadge(score: result.riskScore, size: 56),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.safe ? '✓ Safe Message' : '⚠ Scam Detected',
                        style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        Helpers.categoryLabel(result.category),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Reason
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Analysis',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  result.reason,
                  style: TextStyle(
                    fontSize: 13.5,
                    height:   1.5,
                    color:    isDark
                        ? Colors.white70
                        : AppColors.textSecondary,
                  ),
                ),

                if (!result.safe) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:        AppColors.danger.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.block_rounded,
                            color: AppColors.danger, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Do NOT share OTPs, bank details or click links from this message.',
                            style: TextStyle(
                              color:      AppColors.danger,
                              fontSize:   12.5,
                              fontWeight: FontWeight.w600,
                              height:     1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sample scams ─────────────────────────────────────────────────────────────

class _SampleSection extends StatelessWidget {
  const _SampleSection({
    required this.isDark,
    required this.onSample,
  });
  final bool                  isDark;
  final ValueChanged<String>  onSample;

  static const _samples = [
    (
      label: 'Banking OTP scam',
      text:
          'Dear Customer, Your SBI account will be blocked. Verify KYC by sharing OTP: 947821 to our executive at +91-9876543210 immediately.',
    ),
    (
      label: 'Digital Arrest',
      text:
          'I am IPS officer Sharma from CBI. Your Aadhaar is linked to money laundering. You are under Digital Arrest. Call 9998887776 immediately or we will send police.',
    ),
    (
      label: 'Investment trap',
      text:
          'Guaranteed 40% monthly returns on stock tips! Join our WhatsApp group. Limited slots. SEBI registered advisor. Send ₹5000 to join. WhatsApp: 9876543211',
    ),
    (
      label: 'Lottery fraud',
      text:
          'Congratulations! You have won ₹25 Lakh in KBC Lucky Draw 2024. To claim prize call 09876543210. Your lucky number: KBC2024IN445566.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TEST WITH SAMPLE SCAMS',
          style: TextStyle(
            fontSize:      11,
            fontWeight:    FontWeight.w700,
            color:         AppColors.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        ..._samples.map((s) => GestureDetector(
          onTap: () => onSample(s.text),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color:        isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.bug_report_rounded,
                    color: AppColors.warning, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize:   13,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: AppColors.textDisabled, size: 13),
              ],
            ),
          ),
        )),
      ],
    );
  }
}
