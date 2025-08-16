// lib/widgets/user_image_picker.dart
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// 画像ピッカー（プロフィール用）
/// - initialImageUrl … 既に保存済みの画像URL（ネットワーク画像）
/// - onPickImage … 新規に選択/撮影した画像ファイルを親へ返す
/// - onDelete … 画像削除を親に依頼（Firestore/Storage 更新は親で処理）
class UserImagePicker extends StatefulWidget {
  const UserImagePicker({
    super.key,
    this.initialImageUrl,
    required this.onPickImage,
    this.onDelete,
    this.radius = 64,
  });

  final String? initialImageUrl;
  final void Function(File image) onPickImage;
  final Future<void> Function()? onDelete;
  final double radius;

  @override
  State<UserImagePicker> createState() => _UserImagePickerState();
}

class _UserImagePickerState extends State<UserImagePicker> {
  final _picker = ImagePicker();

  File? _pickedFile;        // 端末から新規に選んだ（or 撮った）画像
  String? _networkImageUrl; // 既存のダウンロードURL

  @override
  void initState() {
    super.initState();
    _networkImageUrl = widget.initialImageUrl;
  }

  /// 親から initialImageUrl が後から届いたら追随する（←これが超重要）
  @override
  void didUpdateWidget(covariant UserImagePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialImageUrl != widget.initialImageUrl) {
      setState(() {
        _networkImageUrl = widget.initialImageUrl;
        // 既存URLが来たらローカル選択はクリア（表示をURL優先に）
        if (_networkImageUrl != null && _networkImageUrl!.isNotEmpty) {
          _pickedFile = null;
        }
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (x == null) return;
    if (kIsWeb) return; // 今回はAndroid/iOS前提。Webなら別実装に切り替え。

    final file = File(x.path);
    setState(() {
      _pickedFile = file;
      _networkImageUrl = null;
    });
    widget.onPickImage(file);
  }

  Future<void> _pickFromCamera() async {
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (x == null) return;
    if (kIsWeb) return;

    final file = File(x.path);
    setState(() {
      _pickedFile = file;
      _networkImageUrl = null;
    });
    widget.onPickImage(file);
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('画像を削除しますか？'),
        content: const Text('プロフィール画像をなしに戻します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // 親に削除処理（Firestore/Storage）を依頼
    await widget.onDelete?.call();

    // UIは即座にプレースホルダーへ戻す
    if (mounted) {
      setState(() {
        _pickedFile = null;
        _networkImageUrl = null;
      });
    }
  }

  void _openPickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        final canDelete = _pickedFile != null ||
            (_networkImageUrl != null && _networkImageUrl!.isNotEmpty);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text('ギャラリーから選ぶ'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('カメラで撮影'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromCamera();
                },
              ),
              if (canDelete)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    '画像を削除',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? provider;
    if (_pickedFile != null) {
      provider = FileImage(_pickedFile!);
    } else if (_networkImageUrl != null && _networkImageUrl!.isNotEmpty) {
      provider = NetworkImage(_networkImageUrl!);
    }

    final radius = widget.radius;

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: radius,
              backgroundImage: provider,
              child: provider == null
                  ? Icon(Icons.pets, size: radius * 0.75, color: Colors.white70)
                  : null,
              backgroundColor:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
            ),
            // 右下の鉛筆ボタン
            Positioned(
              bottom: 6,
              right: 6,
              child: Material(
                color: Theme.of(context).colorScheme.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _openPickerSheet,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.edit, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '画像を選択',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
