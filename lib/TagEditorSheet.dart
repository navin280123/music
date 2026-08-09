import 'dart:io';
import 'package:audiotags/audiotags.dart';
import 'package:flutter/material.dart';
import 'package:music/AppTheme.dart';

class TagEditorSheet extends StatefulWidget {
  final String filePath;
  final VoidCallback? onSaved;

  const TagEditorSheet({
    super.key,
    required this.filePath,
    this.onSaved,
  });

  static void show(BuildContext context, String filePath, {VoidCallback? onSaved}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TagEditorSheet(
        filePath: filePath,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends State<TagEditorSheet> {
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _albumController = TextEditingController();
  final _genreController = TextEditingController();
  final _yearController = TextEditingController();

  List<Picture> _existingPictures = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    try {
      final tag = await AudioTags.read(widget.filePath);
      final fileName = widget.filePath.split(Platform.pathSeparator).last;
      final defaultTitle = fileName.split('.').first;

      _titleController.text = tag?.title ?? defaultTitle;
      _artistController.text = tag?.trackArtist ?? '';
      _albumController.text = tag?.album ?? '';
      _genreController.text = tag?.genre ?? '';
      _yearController.text = tag?.year?.toString() ?? '';
      _existingPictures = tag?.pictures ?? [];
    } catch (e) {
      debugPrint("Error reading tags: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveTags() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });

    try {
      final tag = Tag(
        title: _titleController.text.trim(),
        trackArtist: _artistController.text.trim(),
        album: _albumController.text.trim(),
        genre: _genreController.text.trim(),
        year: int.tryParse(_yearController.text.trim()),
        pictures: _existingPictures,
      );

      await AudioTags.write(widget.filePath, tag);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text("Audio metadata saved successfully!"),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        widget.onSaved?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving tags: $e"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _genreController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final sheetBg = isDark ? const Color(0xFF1A1A1C) : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextCol = isDark ? Colors.white54 : const Color(0xFF64748B);
    final activeCol = isDark ? const Color(0xFF818CF8) : AppTheme.lightPrimary;
    final cardBg = isDark ? const Color(0xFF242426) : const Color(0xFFF1F5F9);
    final borderCol = isDark ? const Color(0xFF2E2E32) : const Color(0xFFE2E8F0);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: activeCol.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.edit_note_rounded, color: activeCol, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Edit Audio Tags",
                        style: TextStyle(
                          color: textCol,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: subTextCol),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Column(
                        children: [
                          _buildTextField("Track Title", _titleController, Icons.title_rounded,
                              cardBg, borderCol, textCol, subTextCol),
                          const SizedBox(height: 12),
                          _buildTextField("Artist", _artistController, Icons.person_rounded,
                              cardBg, borderCol, textCol, subTextCol),
                          const SizedBox(height: 12),
                          _buildTextField("Album", _albumController, Icons.album_rounded,
                              cardBg, borderCol, textCol, subTextCol),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField("Genre", _genreController,
                                    Icons.category_rounded, cardBg, borderCol, textCol, subTextCol),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 110,
                                child: _buildTextField(
                                  "Year",
                                  _yearController,
                                  Icons.calendar_today_rounded,
                                  cardBg,
                                  borderCol,
                                  textCol,
                                  subTextCol,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _saveTags,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_rounded),
                              label: Text(_isSaving ? "Saving..." : "Save Metadata"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: activeCol,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon,
    Color bg,
    Color border,
    Color textCol,
    Color subTextCol, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: textCol, fontSize: 14.5),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: subTextCol, fontSize: 13),
          prefixIcon: Icon(icon, color: subTextCol, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
