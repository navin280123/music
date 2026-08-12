import 'package:cast/cast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music/AppTheme.dart';
import 'package:music/CastService.dart';

class CastSheet extends StatefulWidget {
  final String? currentTrackPath;
  final String? currentTrackTitle;
  final String? currentTrackArtist;

  const CastSheet({
    super.key,
    this.currentTrackPath,
    this.currentTrackTitle,
    this.currentTrackArtist,
  });

  static Future<void> show(
    BuildContext context, {
    String? currentTrackPath,
    String? currentTrackTitle,
    String? currentTrackArtist,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CastSheet(
        currentTrackPath: currentTrackPath,
        currentTrackTitle: currentTrackTitle,
        currentTrackArtist: currentTrackArtist,
      ),
    );
  }

  @override
  State<CastSheet> createState() => _CastSheetState();
}

class _CastSheetState extends State<CastSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _connecting = false;
  String? _connectingDeviceName;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final castService = CastService.instance;
      if (!castService.isConnected && !castService.isDiscovering) {
        castService.startDiscovery();
      }
      if (widget.currentTrackPath != null) {
        castService.startStreamServer(
          widget.currentTrackPath!,
          title: widget.currentTrackTitle,
          artist: widget.currentTrackArtist,
        );
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _connectToDevice(CastDevice device) async {
    setState(() {
      _connecting = true;
      _connectingDeviceName = device.name;
    });

    final success = await CastService.instance.connectToDevice(device);
    if (!mounted) return;

    setState(() {
      _connecting = false;
      _connectingDeviceName = null;
    });

    if (success) {
      if (widget.currentTrackPath != null) {
        await CastService.instance.castTrack(
          widget.currentTrackPath!,
          title: widget.currentTrackTitle,
          artist: widget.currentTrackArtist,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cast_connected_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Connected to ${device.name}'),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect to ${device.name}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final sheetBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final cardBg = isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);
    final primaryAccent =
        isDark ? const Color(0xFF818CF8) : AppTheme.lightPrimary;

    return ListenableBuilder(
      listenable: CastService.instance,
      builder: (context, _) {
        final castService = CastService.instance;
        final isConnected = castService.isConnected;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28.0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag indicator
                Container(
                  margin: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isConnected
                              ? primaryAccent.withValues(alpha: 0.15)
                              : cardBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isConnected
                              ? Icons.cast_connected_rounded
                              : Icons.cast_rounded,
                          color: isConnected ? primaryAccent : textPrimary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cast to Device',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              isConnected
                                  ? 'Connected to ${castService.connectedDeviceName}'
                                  : 'Stream audio to smart TVs & speakers',
                              style: TextStyle(
                                color: isConnected
                                    ? primaryAccent
                                    : textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Main Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Connected Device Card (if connected)
                        if (isConnected) ...[
                          _buildConnectedDeviceCard(
                            context,
                            castService,
                            cardBg,
                            primaryAccent,
                            textPrimary,
                            textSecondary,
                            isDark,
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Discovery Header & Action
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'AVAILABLE CAST RECEIVERS',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            if (castService.isDiscovering)
                              Row(
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          primaryAccent),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Scanning...',
                                    style: TextStyle(
                                      color: primaryAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              )
                            else
                              TextButton.icon(
                                onPressed: () => castService.startDiscovery(),
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Refresh'),
                                style: TextButton.styleFrom(
                                  foregroundColor: primaryAccent,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Discovered Devices List
                        if (_connecting) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        primaryAccent),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  'Connecting to $_connectingDeviceName...',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        if (castService.discoveredDevices.isEmpty &&
                            !castService.isDiscovering &&
                            !_connecting)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? Colors.white10 : Colors.black12,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.cast_connected_rounded,
                                  color: textSecondary,
                                  size: 40,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No Cast Devices Found Yet',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Ensure your Chromecast, Google Nest, or Android TV is powered on and connected to the same Wi-Fi network.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                ElevatedButton.icon(
                                  onPressed: () => castService.startDiscovery(),
                                  icon: const Icon(Icons.search_rounded,
                                      size: 18),
                                  label: const Text('Search Again'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryAccent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...castService.discoveredDevices.map((device) {
                            final isThisDevice =
                                castService.connectedDevice?.host == device.host;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isThisDevice
                                    ? primaryAccent.withValues(alpha: 0.12)
                                    : cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isThisDevice
                                      ? primaryAccent.withValues(alpha: 0.4)
                                      : Colors.transparent,
                                ),
                              ),
                              child: ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isThisDevice
                                        ? primaryAccent
                                        : (isDark
                                            ? Colors.white10
                                            : Colors.black12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.tv_rounded,
                                    color: isThisDevice
                                        ? Colors.white
                                        : textPrimary,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  device.name,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  '${device.host}:${device.port}',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: isThisDevice
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: primaryAccent,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'Connected',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.chevron_right_rounded,
                                        color: textSecondary,
                                      ),
                                onTap: isThisDevice
                                    ? null
                                    : () => _connectToDevice(device),
                              ),
                            );
                          }),

                        const SizedBox(height: 24),

                        // Direct Wi-Fi Streaming & Smart TV URL Card
                        _buildDirectStreamingCard(
                          context,
                          castService,
                          cardBg,
                          primaryAccent,
                          textPrimary,
                          textSecondary,
                          isDark,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectedDeviceCard(
    BuildContext context,
    CastService castService,
    Color cardBg,
    Color primaryAccent,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(
          color: primaryAccent.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'STREAMING TO',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => castService.disconnect(),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFF43F5E),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Disconnect'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            castService.connectedDeviceName ?? 'Cast Device',
            style: TextStyle(
              color: textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (castService.currentTitle != null) ...[
            const SizedBox(height: 4),
            Text(
              '${castService.currentTitle} • ${castService.currentArtist ?? "Pocketo"}',
              style: TextStyle(
                color: textSecondary,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 14),

          // Playback & Volume controls for Cast
          Row(
            children: [
              IconButton(
                icon: Icon(
                  castService.isCastPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  color: primaryAccent,
                  size: 38,
                ),
                onPressed: () {
                  if (castService.isCastPlaying) {
                    castService.pause();
                  } else {
                    castService.play();
                  }
                },
              ),
              const SizedBox(width: 8),
              Icon(Icons.volume_down_rounded, color: textSecondary, size: 20),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    value: castService.volume,
                    activeColor: primaryAccent,
                    inactiveColor: isDark ? Colors.white24 : Colors.black12,
                    onChanged: (val) => castService.setVolume(val),
                  ),
                ),
              ),
              Icon(Icons.volume_up_rounded, color: textSecondary, size: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDirectStreamingCard(
    BuildContext context,
    CastService castService,
    Color cardBg,
    Color primaryAccent,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    final streamUrl = castService.streamUrl;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wifi_tethering_rounded,
                  color: primaryAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Smart TV / Browser Stream URL',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You can stream music to any Smart TV, laptop, or browser connected to your Wi-Fi by opening this direct stream URL:',
            style: TextStyle(
              color: textSecondary,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          if (streamUrl != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF18181B)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      streamUrl,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: primaryAccent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: streamUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Stream URL copied to clipboard!'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.copy_rounded,
                              size: 14, color: primaryAccent),
                          const SizedBox(width: 4),
                          Text(
                            'Copy',
                            style: TextStyle(
                              color: primaryAccent,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'Connect to Wi-Fi to generate local streaming address.',
              style: TextStyle(
                color: textSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}
