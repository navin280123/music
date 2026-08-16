import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:music/services/jam_sync_service.dart';

class JamScreen extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final String? currentTrackPath;
  final String? currentTitle;
  final String? currentArtist;
  final Duration duration;
  final Duration position;
  final bool isPlaying;

  const JamScreen({
    super.key,
    required this.audioPlayer,
    this.currentTrackPath,
    this.currentTitle,
    this.currentArtist,
    this.duration = Duration.zero,
    this.position = Duration.zero,
    this.isPlaying = false,
  });

  @override
  State<JamScreen> createState() => _JamScreenState();
}

class _JamScreenState extends State<JamScreen> with SingleTickerProviderStateMixin {
  final JamSyncService _jamService = JamSyncService.instance;

  // Scanner
  MobileScannerController? _scannerController;
  bool _isScannerActive = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _jamService.addListener(_onJamServiceChanged);
    if (!_jamService.isInJam) {
      _jamService.detectNetwork();
    }
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _jamService.removeListener(_onJamServiceChanged);
    super.dispose();
  }

  void _onJamServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _startHostJam() async {
    final hasNetwork = await _jamService.detectNetwork();
    if (!hasNetwork) {
      if (mounted) {
        _showHotspotHelpSheet();
      }
      return;
    }

    final success = await _jamService.startHostSession(
      initialTrackPath: widget.currentTrackPath,
      title: widget.currentTitle ?? 'Pocketo Audio',
      artist: widget.currentArtist ?? 'Pocketo Host',
      duration: widget.audioPlayer.duration ?? widget.duration,
      position: widget.audioPlayer.position,
      isPlaying: widget.audioPlayer.playing,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
              SizedBox(width: 10),
              Text('Pocketo Jam session started!'),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _showQrCodeDialog();
    }
  }

  Future<void> _openScanner() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Camera permission is required to scan QR code.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isScannerActive = true;
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
    });
  }

  void _closeScanner() {
    _scannerController?.dispose();
    _scannerController = null;
    setState(() {
      _isScannerActive = false;
    });
  }

  Future<void> _handleBarcodeDetected(BarcodeCapture capture) async {
    if (_isConnecting) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;

      final info = JamConnectionInfo.fromJsonString(raw);
      if (info != null) {
        setState(() => _isConnecting = true);
        _closeScanner();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
                  ),
                  const SizedBox(width: 12),
                  Text('Connecting to ${info.sessionName}...'),
                ],
              ),
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        final success = await _jamService.joinSession(info, sharedPlayer: widget.audioPlayer);
        setState(() => _isConnecting = false);

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                  SizedBox(width: 10),
                  Text('Connected to Jam! Audio is now synchronized.'),
                ],
              ),
              backgroundColor: Color(0xFF0F172A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_jamService.errorMessage ?? 'Failed to connect to host.'),
              backgroundColor: Colors.redAccent.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        break;
      }
    }
  }

  void _showQrCodeDialog() {
    final session = _jamService.currentSession;
    if (session == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black12,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull bar
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF818CF8), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Scan to Join Jam',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Ask friends to open Pocketo Play > Jam > Join Jam and scan this code.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 20),

              // QR Code View
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: session.toJsonString(),
                  version: QrVersions.auto,
                  size: 220.0,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF0F172A),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF1E1B4B),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Session Info Chips
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_tethering_rounded, size: 16, color: Colors.cyanAccent.shade400),
                    const SizedBox(width: 6),
                    Text(
                      'Host IP: ${session.hostIp}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(width: 1, height: 12, color: Colors.white24),
                    const SizedBox(width: 12),
                    Text(
                      session.sessionId,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF818CF8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Done Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Done / Keep Jam Active',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showHotspotHelpSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_tethering_off_rounded, color: Colors.amber, size: 32),
              ),
              const SizedBox(height: 14),
              Text(
                'Turn On Personal Hotspot',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'To start a Jam session, turn on your device\'s Personal Hotspot or connect to the same Wi-Fi network so nearby devices can discover each other.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await openAppSettings();
                      },
                      child: Text(
                        'Open Settings',
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _startHostJam();
                      },
                      child: const Text('I Turned On / Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showManualIpDialog() {
    final controller = TextEditingController(text: '192.168.43.1');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Manual IP Connect', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the Host IP address shown on the host device screen:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. 192.168.43.1',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            onPressed: () async {
              final ip = controller.text.trim();
              Navigator.pop(ctx);
              if (ip.isNotEmpty) {
                final info = JamConnectionInfo(
                  sessionId: 'MANUAL_JAM',
                  sessionName: 'Manual Jam Host',
                  hostIp: ip,
                  httpPort: 8992,
                  wsPort: 8993,
                );
                await _jamService.joinSession(info, sharedPlayer: widget.audioPlayer);
              }
            },
            child: const Text('Connect', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryCol = Color(0xFF6366F1);

    if (_isScannerActive) {
      return _buildScannerView();
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.speaker_group_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 5),
                  Text(
                    'POCKET JAM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _jamService.isInJam ? _buildActiveJamDashboard() : _buildIdleJamOptions(isDark, primaryCol),
      ),
    );
  }

  // ── View: Scanner Mode ──────────────────────────────────────────────────────
  Widget _buildScannerView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_scannerController != null)
            MobileScanner(
              controller: _scannerController!,
              onDetect: _handleBarcodeDetected,
            ),

          // Scanner Overlay Frame
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF6366F1), width: 2.5),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
          ),

          // Top Header with Close & Flash
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: _closeScanner,
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: ValueListenableBuilder(
                          valueListenable: _scannerController!,
                          builder: (context, state, child) {
                            return Icon(
                              state.torchState == TorchState.on
                                  ? Icons.flash_on_rounded
                                  : Icons.flash_off_rounded,
                              color: Colors.white,
                            );
                          },
                        ),
                        onPressed: () => _scannerController?.toggleTorch(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
                        onPressed: () => _scannerController?.switchCamera(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom Instruction Card
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Point camera at the Host\'s QR Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Make sure you are connected to the Host\'s Hotspot or same Wi-Fi network.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      _closeScanner();
                      _showManualIpDialog();
                    },
                    child: const Text(
                      'Enter IP Manually instead',
                      style: TextStyle(color: Color(0xFF818CF8), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── View: Idle State (Start Jam vs Join Jam) ────────────────────────────────
  Widget _buildIdleJamOptions(bool isDark, Color primaryCol) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF1E1B4B), const Color(0xFF311042)]
                    : [const Color(0xFFEEF2FF), const Color(0xFFFDF2F8)],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? const Color(0xFF6366F1).withValues(alpha: 0.3) : const Color(0xFF6366F1).withValues(alpha: 0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.spatial_audio_rounded, color: Color(0xFF818CF8), size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Group Listening',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Zero latency local multi-speaker sync',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Host a party or connect with friends! When the host plays, skips, or pauses a song, it plays simultaneously on all connected devices.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          Text(
            'CHOOSE AN OPTION',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          ),
          const SizedBox(height: 14),

          // Option 1: Start Jam
          _buildOptionCard(
            isDark: isDark,
            icon: Icons.wifi_tethering_rounded,
            iconColor: const Color(0xFF6366F1),
            title: 'Start Jam (Host)',
            subtitle: 'Broadcast music from your device to nearby friends via Hotspot or Wi-Fi.',
            badge: 'HOST',
            badgeColor: const Color(0xFF6366F1),
            buttonLabel: 'Start Host Session',
            onTap: _startHostJam,
          ),
          const SizedBox(height: 16),

          // Option 2: Join Jam
          _buildOptionCard(
            isDark: isDark,
            icon: Icons.qr_code_scanner_rounded,
            iconColor: const Color(0xFFEC4899),
            title: 'Join Jam (Guest)',
            subtitle: 'Scan a friend\'s QR Code to synchronize and listen in real-time.',
            badge: 'GUEST',
            badgeColor: const Color(0xFFEC4899),
            buttonLabel: 'Scan QR to Join',
            onTap: _openScanner,
          ),
          const SizedBox(height: 14),

          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.keyboard_alt_outlined, size: 16),
              label: const Text('Enter Host IP Manually', style: TextStyle(fontSize: 12.5)),
              onPressed: _showManualIpDialog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white60 : Colors.black54,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: iconColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: onTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    buttonLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── View: Active Jam Dashboard ─────────────────────────────────────────────
  Widget _buildActiveJamDashboard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHost = _jamService.isHost;
    final session = _jamService.currentSession;
    final peerCount = _jamService.peerCount;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isHost
                    ? [const Color(0xFF4F46E5), const Color(0xFF7C3AED)]
                    : [const Color(0xFFBE185D), const Color(0xFF831843)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (isHost ? const Color(0xFF4F46E5) : const Color(0xFFBE185D)).withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isHost ? 'HOSTING JAM SESSION' : 'CONNECTED TO JAM',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        session?.sessionId ?? 'JAM',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isHost ? Icons.wifi_tethering_rounded : Icons.headphones_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session?.sessionName ?? 'Pocketo Jam',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isHost
                                ? '$peerCount connected peer${peerCount == 1 ? '' : 's'}'
                                : 'Syncing with host at ${session?.hostIp}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Host "Show QR" quick button (so host can show QR code anytime!)
          if (isHost) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.qr_code_2_rounded, size: 22),
                label: const Text(
                  'Show Jam QR (Invite Friends)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
                onPressed: _showQrCodeDialog,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Currently Synced Track Card
          Text(
            'NOW SYNCING',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.music_note_rounded, color: Color(0xFF818CF8), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _jamService.currentTitle ?? widget.currentTitle ?? 'No Song Playing',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _jamService.currentArtist ?? widget.currentArtist ?? 'Pocketo Player',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _jamService.isPlaying
                        ? Colors.greenAccent.withValues(alpha: 0.15)
                        : Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _jamService.isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        size: 14,
                        color: _jamService.isPlaying ? Colors.greenAccent : Colors.amber,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _jamService.isPlaying ? 'SYNCED' : 'PAUSED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _jamService.isPlaying ? Colors.greenAccent : Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Audio Sync & Latency Fine-Tuner Card ─────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.sync_rounded, color: Color(0xFF38BDF8), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'AUDIO SYNC TUNER',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _jamService.lastDriftMs.abs() < 40
                            ? Colors.greenAccent.withValues(alpha: 0.15)
                            : Colors.cyanAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _jamService.lastDriftMs.abs() < 40
                            ? 'LOCKED (${_jamService.lastDriftMs}ms)'
                            : 'SYNCING (${_jamService.lastDriftMs}ms)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _jamService.lastDriftMs.abs() < 40
                              ? Colors.greenAccent
                              : Colors.cyanAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Live Stats Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Network Ping', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black45)),
                            const SizedBox(height: 2),
                            Text('${_jamService.rttMs} ms', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Auto PLL Speed', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black45)),
                            const SizedBox(height: 2),
                            Text('${_jamService.currentPlaybackSpeed.toStringAsFixed(2)}x', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Manual Offset', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black45)),
                            const SizedBox(height: 2),
                            Text('${_jamService.userLatencyOffsetMs.round()} ms', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF818CF8))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Fine Tune Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Manual Delay Calibration',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                    Text(
                      '${_jamService.userLatencyOffsetMs > 0 ? '+' : ''}${_jamService.userLatencyOffsetMs.round()} ms',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: const Color(0xFF6366F1),
                    thumbColor: const Color(0xFF818CF8),
                  ),
                  child: Slider(
                    value: _jamService.userLatencyOffsetMs.clamp(-300.0, 300.0),
                    min: -300.0,
                    max: 300.0,
                    divisions: 60,
                    onChanged: (val) {
                      _jamService.setUserLatencyOffsetMs(val);
                    },
                  ),
                ),

                // Quick Presets
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildOffsetPresetBtn('Speakers (0ms)', 0, isDark),
                    _buildOffsetPresetBtn('Bluetooth (+100ms)', 100, isDark),
                    _buildOffsetPresetBtn('Earbuds (+180ms)', 180, isDark),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Connected Members List
          if (isHost) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CONNECTED PEERS (${_jamService.connectedPeers.length})',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_jamService.connectedPeers.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.people_outline_rounded,
                        size: 32, color: isDark ? Colors.white24 : Colors.black26),
                    const SizedBox(height: 8),
                    Text(
                      'Waiting for friends to join...',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._jamService.connectedPeers.map(
                (peer) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFF6366F1),
                        child: Icon(Icons.smartphone_rounded, size: 14, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Device ${peer.address}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],

          // Leave / End Jam Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: Icon(isHost ? Icons.stop_circle_outlined : Icons.exit_to_app_rounded, size: 20),
              label: Text(
                isHost ? 'End Jam Session' : 'Leave Jam Session',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: () async {
                await _jamService.leaveSession();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Left Jam session.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffsetPresetBtn(String label, double offsetMs, bool isDark) {
    final isSelected = (_jamService.userLatencyOffsetMs.round() == offsetMs.round());
    return InkWell(
      onTap: () => _jamService.setUserLatencyOffsetMs(offsetMs),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1).withValues(alpha: 0.25)
              : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF818CF8)
                : (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? const Color(0xFF818CF8)
                : (isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      ),
    );
  }
}
