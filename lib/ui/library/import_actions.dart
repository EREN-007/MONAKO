import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../../l10n/app_localizations.dart';
import '../../services/asset_renderer.dart';

/// Import de PDF et d'images (section 10). Le fichier original est gardé
/// tel quel; la recoloration se fait à l'affichage.
Future<Notebook?> importDocument(BuildContext context,
    {Notebook? into, String? folderId}) async {
  final l = AppLocalizations.of(context);
  final repo = context.read<NotesRepository>();
  final messenger = ScaffoldMessenger.of(context);
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'heic', 'gif'],
  );
  if (files.isEmpty) return null;
  final file = files.first;
  messenger.showSnackBar(SnackBar(content: Text(l.importing(file.name))));
  try {
    final bytes = await file.xFile.readAsBytes();
    final isPdf = file.name.toLowerCase().endsWith('.pdf');
    final sizes = isPdf
        ? await AssetRenderer.pdfPageSizes(bytes)
        : [await AssetRenderer.imageSize(bytes)];
    final nb = await repo.importDocument(
      bytes: bytes,
      fileName: file.name,
      kind: isPdf ? AssetKind.pdf : AssetKind.image,
      pageSizes: sizes,
      into: into,
      folderId: folderId,
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.importDone(sizes.length))));
    return nb;
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.importFailed('$e'))));
    return null;
  }
}
