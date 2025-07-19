import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class PdfHelper {
  // Visualizar PDF na tela
  static Future<void> showPdfPreview(BuildContext context, File pdfFile) async {
    try {
      final bytes = await pdfFile.readAsBytes();
      
      if (!context.mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Visualizar Relatório'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () => sharePdf(pdfFile),
                ),
                IconButton(
                  icon: const Icon(Icons.print),
                  onPressed: () => printPdf(bytes),
                ),
              ],
            ),
            body: PdfPreview(
              build: (format) => Future.value(Uint8List.fromList(bytes)),
              allowPrinting: true,
              allowSharing: true,
              canChangePageFormat: false,
              canDebug: false,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao visualizar PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Compartilhar PDF
  static Future<void> sharePdf(File pdfFile) async {
    try {
      final bytes = await pdfFile.readAsBytes();
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: pdfFile.path.split('/').last,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao compartilhar PDF: $e');
      }
    }
  }

  // Imprimir PDF
  static Future<void> printPdf(List<int> bytes) async {
    try {
      await Printing.layoutPdf(
        onLayout: (format) => Future.value(Uint8List.fromList(bytes)),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao imprimir PDF: $e');
      }
    }
  }

  // Salvar PDF em local específico
  static Future<File?> savePdfToDownloads(File pdfFile, String customName) async {
    try {
      // Tentar salvar no diretório de downloads
      Directory? downloadsDir;
      
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else if (Platform.isIOS) {
        downloadsDir = await getApplicationDocumentsDirectory();
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir != null && await downloadsDir.exists()) {
        final newFile = File('${downloadsDir.path}/$customName');
        await newFile.writeAsBytes(await pdfFile.readAsBytes());
        return newFile;
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao salvar PDF: $e');
      }
      return null;
    }
  }

  // Obter informações do PDF
  static Future<Map<String, dynamic>> getPdfInfo(File pdfFile) async {
    try {
      final stat = await pdfFile.stat();
      final size = stat.size;
      final modified = stat.modified;
      
      String sizeString;
      if (size < 1024) {
        sizeString = '$size B';
      } else if (size < 1024 * 1024) {
        sizeString = '${(size / 1024).toStringAsFixed(1)} KB';
      } else {
        sizeString = '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      
      return {
        'size': size,
        'sizeString': sizeString,
        'modified': modified,
        'path': pdfFile.path,
        'name': pdfFile.path.split('/').last,
      };
    } catch (e) {
      return {
        'size': 0,
        'sizeString': 'Desconhecido',
        'modified': DateTime.now(),
        'path': pdfFile.path,
        'name': 'Relatório',
      };
    }
  }

  // Verificar se o arquivo PDF é válido
  static Future<bool> isPdfValid(File pdfFile) async {
    try {
      final bytes = await pdfFile.readAsBytes();
      
      // Verificar se começa com a assinatura PDF
      if (bytes.length < 4) return false;
      
      final header = String.fromCharCodes(bytes.take(4));
      return header == '%PDF';
    } catch (e) {
      return false;
    }
  }

  // Limpar PDFs antigos
  static Future<void> cleanOldPdfs({int maxAgeInDays = 30}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync();
      final cutoffDate = DateTime.now().subtract(Duration(days: maxAgeInDays));
      
      for (var file in files) {
        if (file is File && file.path.endsWith('.pdf')) {
          final stat = await file.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await file.delete();
            if (kDebugMode) {
              debugPrint('PDF antigo removido: ${file.path}');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao limpar PDFs antigos: $e');
      }
    }
  }

  // Listar todos os PDFs salvos
  static Future<List<File>> getAllSavedPdfs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync();
      
      final pdfFiles = <File>[];
      for (var file in files) {
        if (file is File && file.path.endsWith('.pdf')) {
          pdfFiles.add(file);
        }
      }
      
      // Ordenar por data de modificação (mais recente primeiro)
      pdfFiles.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });
      
      return pdfFiles;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao listar PDFs: $e');
      }
      return [];
    }
  }

  // Método auxiliar para conversão segura de bytes
  static Uint8List _listToUint8List(List<int> list) {
    if (list is Uint8List) {
      return list;
    }
    return Uint8List.fromList(list);
  }

  // Verificar espaço disponível no dispositivo
  static Future<bool> hasEnoughSpace({int requiredBytes = 1024 * 1024}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final stat = await directory.stat();
      
      // Esta é uma verificação simplificada
      // Em uma implementação real, você pode usar plugins específicos
      // para verificar espaço livre no dispositivo
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao verificar espaço: $e');
      }
      return true; // Assumir que há espaço em caso de erro
    }
  }

  // Calcular hash do arquivo PDF para verificação de integridade
  static Future<String> calculateFileHash(File pdfFile) async {
    try {
      final bytes = await pdfFile.readAsBytes();
      // Implementação simplificada de hash
      int hash = 0;
      for (int byte in bytes) {
        hash = hash * 31 + byte;
        hash = hash & 0x7FFFFFFF; // Manter positivo
      }
      return hash.toString();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao calcular hash: $e');
      }
      return 'unknown';
    }
  }

  // Verificar se um PDF já existe com o mesmo conteúdo
  static Future<File?> findDuplicatePdf(File newPdfFile) async {
    try {
      final allPdfs = await getAllSavedPdfs();
      final newFileHash = await calculateFileHash(newPdfFile);
      
      for (final existingPdf in allPdfs) {
        if (existingPdf.path != newPdfFile.path) {
          final existingHash = await calculateFileHash(existingPdf);
          if (newFileHash == existingHash) {
            return existingPdf;
          }
        }
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao verificar duplicatas: $e');
      }
      return null;
    }
  }

  // Compactar PDF (implementação básica)
  static Future<File?> compressPdf(File pdfFile) async {
    try {
      // Esta é uma implementação placeholder
      // Para compressão real de PDF, você precisaria de uma biblioteca específica
      // como pdf_compressor ou similar
      
      final compressedPath = pdfFile.path.replaceAll('.pdf', '_compressed.pdf');
      final compressedFile = File(compressedPath);
      
      // Por enquanto, apenas copia o arquivo
      await pdfFile.copy(compressedPath);
      
      return compressedFile;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao compactar PDF: $e');
      }
      return null;
    }
  }

  // Criptografar PDF (implementação básica)
  static Future<File?> encryptPdf(File pdfFile, String password) async {
    try {
      // Esta é uma implementação placeholder
      // Para criptografia real de PDF, você precisaria de uma biblioteca específica
      
      if (password.isEmpty) {
        return pdfFile;
      }
      
      final encryptedPath = pdfFile.path.replaceAll('.pdf', '_encrypted.pdf');
      final encryptedFile = File(encryptedPath);
      
      // Por enquanto, apenas copia o arquivo
      await pdfFile.copy(encryptedPath);
      
      return encryptedFile;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao criptografar PDF: $e');
      }
      return null;
    }
  }

  // Método para debug (apenas em desenvolvimento)
  static void debugPdfInfo(File pdfFile) {
    if (kDebugMode) {
      pdfFile.stat().then((stat) {
        debugPrint('=== Debug PDF Info ===');
        debugPrint('Arquivo: ${pdfFile.path}');
        debugPrint('Tamanho: ${stat.size} bytes');
        debugPrint('Modificado: ${stat.modified}');
        debugPrint('Tipo: ${stat.type}');
        debugPrint('======================');
      });
    }
  }
}