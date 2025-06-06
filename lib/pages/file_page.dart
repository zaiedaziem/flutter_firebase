import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/file_model.dart';
import '../services/file_service.dart';

class FilesPage extends StatefulWidget {
  const FilesPage({super.key});

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  final FileService _fileService = FileService();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  bool _isUploading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(),
      body: _buildUI(),
      floatingActionButton: _uploadButton(),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.primary,
      title: const Text(
        "Files",
        style: TextStyle(color: Colors.white),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  Widget _buildUI() {
    return SafeArea(
      child: Column(
        children: [
          if (_isUploading)
            const LinearProgressIndicator(),
          Expanded(child: _filesListView()),
        ],
      ),
    );
  }

  Widget _filesListView() {
    return StreamBuilder(
      stream: _fileService.getFiles(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        List files = snapshot.data?.docs ?? [];

        if (files.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  "No files uploaded yet",
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  "Tap the + button to upload your first file",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: files.length,
          itemBuilder: (context, index) {
            FileModel file = files[index].data();
            String fileId = files[index].id;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                leading: _buildFilePreview(file),
                title: Text(
                  file.fileName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (file.description.isNotEmpty)
                      Text(file.description),
                    const SizedBox(height: 4),
                    Text(
                      '${file.fileSizeFormatted} • ${DateFormat("dd-MM-yyyy h:mm a").format(file.uploadedAt.toDate())}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (file.tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: file.tags.map((tag) => Chip(
                          label: Text(tag),
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          labelStyle: const TextStyle(fontSize: 10),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        )).toList(),
                      ),
                    ],
                  ],
                ),
                trailing: PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: ListTile(
                        leading: Icon(Icons.visibility),
                        title: Text('View'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('Delete', style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'view') {
                      _viewFile(file);
                    } else if (value == 'delete') {
                      _deleteFile(fileId, file.fileName);
                    }
                  },
                ),
                onTap: () => _viewFile(file),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilePreview(FileModel file) {
    if (file.isImage) {
      Uint8List imageBytes = _fileService.base64ToUint8List(file.base64Data);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          imageBytes,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.broken_image, size: 50);
          },
        ),
      );
    } else {
      return const Icon(Icons.insert_drive_file, size: 50);
    }
  }

  Widget _uploadButton() {
    return FloatingActionButton(
      onPressed: _isUploading ? null : _showUploadOptions,
      child: _isUploading 
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.add),
    );
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      setState(() => _isUploading = true);

      XFile? pickedFile;
      if (source == ImageSource.gallery) {
        pickedFile = await _fileService.pickImageFromGallery();
      } else {
        pickedFile = await _fileService.pickImageFromCamera();
      }

      if (pickedFile != null) {
        _showUploadDialog(pickedFile);
      }
    } catch (e) {
      _showErrorDialog('Error picking image: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showUploadDialog(XFile pickedFile) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Upload File'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('File: ${pickedFile.name}'),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma separated)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., work, important, photo',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearControllers();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _uploadFile(pickedFile),
              child: const Text('Upload'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadFile(XFile pickedFile) async {
    try {
      setState(() => _isUploading = true);

      List<String> tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      FileModel? fileModel = await _fileService.convertXFileToFileModel(
        xFile: pickedFile,
        uploadedBy: 'User', // You can replace this with actual user info
        description: _descriptionController.text.trim(),
        tags: tags,
      );

      if (fileModel != null) {
        await _fileService.addFile(fileModel);
        Navigator.of(context).pop();
        _clearControllers();
        _showSuccessDialog('File uploaded successfully!');
      } else {
        _showErrorDialog('Failed to process file');
      }
    } catch (e) {
      _showErrorDialog('Upload failed: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _viewFile(FileModel file) {
    if (file.isImage) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _ImageViewPage(file: file, fileService: _fileService),
        ),
      );
    } else {
      _showErrorDialog('File type not supported for viewing');
    }
  }

  void _deleteFile(String fileId, String fileName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete File'),
          content: Text('Are you sure you want to delete "$fileName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _fileService.deleteFile(fileId);
                  Navigator.of(context).pop();
                  _showSuccessDialog('File deleted successfully!');
                } catch (e) {
                  _showErrorDialog('Delete failed: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _clearControllers() {
    _descriptionController.clear();
    _tagsController.clear();
  }

  void _showSuccessDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// Full screen image viewer
class _ImageViewPage extends StatelessWidget {
  final FileModel file;
  final FileService fileService;

  const _ImageViewPage({
    required this.file,
    required this.fileService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          file.fileName,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: InteractiveViewer(
          child: Image.memory(
            fileService.base64ToUint8List(file.base64Data),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 64, color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}