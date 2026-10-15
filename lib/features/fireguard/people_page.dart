import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/fireeye_api_service.dart';

class PeoplePage extends StatefulWidget {
  const PeoplePage({super.key, required this.eye});
  final FireeyeApiService eye;
  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  final _name = TextEditingController();
  List<Map<String, dynamic>> _people = [];
  Map<String, dynamic>? _status;
  Uint8List? _image;
  bool _loading = true, _busy = false, _consent = false, _fromPi = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final people = await widget.eye.getPeople();
      final status = await widget.eye.getFaceStatus();
      if (mounted) {
        setState(() {
          _people = people;
          _status = status;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        throw const FireeyeException('Ảnh tối đa 8 MB.');
      }
      if (mounted) {
        setState(() {
          _image = bytes;
          _fromPi = false;
          _consent = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Không mở được ảnh/camera. Kiểm tra quyền truy cập hoặc chọn ảnh khác.',
        );
      }
    }
  }

  Future<void> _register() async {
    if (!_consent ||
        _name.text.trim().isEmpty ||
        (!_fromPi && _image == null)) {
      setState(
        () => _error = 'Nhập tên, chọn nguồn ảnh và xác nhận sự đồng ý.',
      );
      return;
    }
    await _act(() async {
      await widget.eye.registerFace(
        _name.text,
        consent: _consent,
        image: _fromPi ? null : _image,
      );
      if (!mounted) return;
      _name.clear();
      setState(() {
        _image = null;
        _fromPi = false;
        _consent = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đăng ký người tham gia.')),
      );
    });
  }

  Future<void> _delete(Map<String, dynamic> person) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xóa hồ sơ ${person['name']}?'),
        content: const Text(
          'Xóa ảnh đăng ký và dữ liệu đối chiếu trên Pi; người này sẽ không còn được nhận diện bằng hồ sơ này. Bằng chứng sự kiện cũ vẫn theo thời gian lưu lịch sử.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa và ngừng đối chiếu'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await _act(() => widget.eye.deletePerson(person['id'] as int));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Người tham gia'),
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Ảnh và dữ liệu đối chiếu được lưu trên Pi. Chỉ đăng ký khi người trong ảnh đã đồng ý; có thể xóa hồ sơ để ngừng đối chiếu.',
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_status != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Đối chiếu khuôn mặt trên Pi'),
                  subtitle: Text(
                    _status!['available'] == true
                        ? 'Kiểm tra định kỳ từ camera Dahua của FireEye'
                        : 'Bộ nhận diện chưa sẵn sàng',
                  ),
                  value: _status!['running'] == true,
                  onChanged:
                      _busy ||
                          !widget.eye.canConfigure ||
                          _status!['available'] != true
                      ? null
                      : (v) => _act(() => widget.eye.setFaceWatch(v)),
                ),
              const SizedBox(height: 12),
              if (widget.eye.canConfigure)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Đăng ký người tham gia',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('person-name'),
                          controller: _name,
                          enabled: !_busy,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Tên người tham gia',
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _pick(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Chọn ảnh'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _pick(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text('Chụp ảnh'),
                            ),
                          ],
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Chụp từ camera trên Pi'),
                          subtitle: const Text(
                            'Đứng một mình trước camera Dahua khi bấm đăng ký.',
                          ),
                          value: _fromPi,
                          onChanged: _busy
                              ? null
                              : (v) => setState(() {
                                  _fromPi = v;
                                  _consent = false;
                                }),
                        ),
                        if (_image != null && !_fromPi)
                          Image.memory(
                            _image!,
                            height: 180,
                            fit: BoxFit.contain,
                          ),
                        CheckboxListTile(
                          key: const Key('face-consent'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                            'Người tham gia đã đồng ý lưu ảnh và dữ liệu khuôn mặt trên Pi để đối chiếu trong hệ thống này.',
                          ),
                          value: _consent,
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => _consent = v == true),
                        ),
                        FilledButton(
                          onPressed:
                              _busy ||
                                  !_consent ||
                                  _status?['available'] != true
                              ? null
                              : _register,
                          child: Text(
                            _busy ? 'Đang xử lý…' : 'Đăng ký khuôn mặt',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Đã đăng ký (${_people.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (_people.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Chưa có người tham gia.'),
                ),
              for (final person in _people)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text('${person['name']}'),
                    subtitle: Text(
                      person['consented_at'] == null
                          ? 'Hồ sơ cũ chưa có đồng ý — không dùng đối chiếu. Xóa và đăng ký lại.'
                          : 'Đã ghi nhận đồng ý: ${person['consented_at']}',
                    ),
                    trailing: widget.eye.canConfigure
                        ? IconButton(
                            tooltip: 'Xóa hồ sơ và rút lại đồng ý',
                            onPressed: _busy ? null : () => _delete(person),
                            icon: const Icon(Icons.person_remove_outlined),
                          )
                        : null,
                  ),
                ),
            ],
          ),
  );
}

class FireeyeImage extends StatefulWidget {
  const FireeyeImage({super.key, required this.eye, required this.path});
  final FireeyeApiService eye;
  final String path;
  @override
  State<FireeyeImage> createState() => _FireeyeImageState();
}

class _FireeyeImageState extends State<FireeyeImage> {
  late Future<Uint8List> _data = widget.eye.getImage(widget.path);
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Column(
          children: [
            Text('Không tải được ảnh: ${snapshot.error}'),
            TextButton(
              onPressed: () =>
                  setState(() => _data = widget.eye.getImage(widget.path)),
              child: const Text('Thử lại'),
            ),
          ],
        );
      }
      if (!snapshot.hasData) {
        return const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return Image.memory(
        snapshot.data!,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Text('Ảnh không hợp lệ.'),
      );
    },
  );
}
