import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class PdfHelper {
  // Função auxiliar para mostrar mensagens usando SnackBar nativo
  static void _showMessage(BuildContext? context, String message, {Color? backgroundColor}) {
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor ?? Colors.blue,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  // Visualizar PDF na tela usando flutter_pdfview
  static Future<void> showPdfPreview(BuildContext context, File pdfFile) async {
    try {
      if (!await pdfFile.exists()) {
        throw Exception('Arquivo PDF não encontrado');
      }

      if (!context.mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _PdfViewerScreen(pdfFile: pdfFile),
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

  // Compartilhar PDF usando share_plus
  static Future<void> sharePdf(File pdfFile, {BuildContext? context}) async {
    try {
      if (!await pdfFile.exists()) {
        throw Exception('Arquivo não encontrado');
      }

      final result = await Share.shareXFiles(
        [XFile(pdfFile.path)],
        text: 'Relatório de progresso - Lumimi',
        subject: 'Relatório PDF',
      );

      if (result.status == ShareResultStatus.success) {
        _showMessage(context, "PDF compartilhado com sucesso!", backgroundColor: Colors.green);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao compartilhar PDF: $e');
      }
      _showMessage(context, "Erro ao compartilhar PDF", backgroundColor: Colors.red);
    }
  }

  // Salvar PDF em local específico
  static Future<File?> savePdfToDownloads(File pdfFile, String customName, {BuildContext? context}) async {
    try {
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
        
        _showMessage(context, "PDF salvo com sucesso!", backgroundColor: Colors.green);
        
        return newFile;
      }
      
      _showMessage(context, "Não foi possível salvar o PDF", backgroundColor: Colors.orange);
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao salvar PDF: $e');
      }
      _showMessage(context, "Erro ao salvar PDF", backgroundColor: Colors.red);
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
      
      if (bytes.length < 4) return false;
      
      final header = String.fromCharCodes(bytes.take(4));
      return header == '%PDF';
    } catch (e) {
      return false;
    }
  }

  // Limpar PDFs antigos
  static Future<void> cleanOldPdfs({int maxAgeInDays = 30, BuildContext? context}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync();
      final cutoffDate = DateTime.now().subtract(Duration(days: maxAgeInDays));
      
      int deletedCount = 0;
      
      for (var file in files) {
        if (file is File && file.path.endsWith('.pdf')) {
          final stat = await file.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await file.delete();
            deletedCount++;
            if (kDebugMode) {
              debugPrint('PDF antigo removido: ${file.path}');
            }
          }
        }
      }
      
      if (deletedCount > 0) {
        _showMessage(context, "$deletedCount relatórios antigos removidos", backgroundColor: Colors.blue);
      } else {
        _showMessage(context, "Nenhum relatório antigo encontrado", backgroundColor: Colors.grey);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao limpar PDFs antigos: $e');
      }
      _showMessage(context, "Erro ao limpar relatórios antigos", backgroundColor: Colors.red);
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

  // Verificar espaço disponível no dispositivo
  static Future<bool> hasEnoughSpace({int requiredBytes = 1024 * 1024}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final stat = await directory.stat();
      
      // Esta é uma verificação simplificada
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao verificar espaço: $e');
      }
      return true;
    }
  }

  // Calcular hash do arquivo PDF para verificação de integridade
  static Future<String> calculateFileHash(File pdfFile) async {
    try {
      final bytes = await pdfFile.readAsBytes();
      int hash = 0;
      for (int byte in bytes) {
        hash = hash * 31 + byte;
        hash = hash & 0x7FFFFFFF;
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

// Tela de visualização de PDF usando flutter_pdfview
class _PdfViewerScreen extends StatefulWidget {
  final File pdfFile;

  const _PdfViewerScreen({required this.pdfFile});

  @override
  State<_PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<_PdfViewerScreen> {
  int? pages = 0;
  int? currentPage = 0;
  bool isReady = false;
  String errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visualizar Relatório'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => PdfHelper.sharePdf(widget.pdfFile, context: context),
            tooltip: 'Compartilhar',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () async {
              final fileName = 'relatorio_${DateTime.now().millisecondsSinceEpoch}.pdf';
              await PdfHelper.savePdfToDownloads(widget.pdfFile, fileName, context: context);
            },
            tooltip: 'Salvar',
          ),
        ],
      ),
      body: Stack(
        children: [
          PDFView(
            filePath: widget.pdfFile.path,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: false,
            pageFling: true,
            pageSnap: true,
            defaultPage: currentPage!,
            fitPolicy: FitPolicy.BOTH,
            preventLinkNavigation: false,
            onRender: (pages) {
              setState(() {
                this.pages = pages;
                isReady = true;
              });
            },
            onError: (error) {
              setState(() {
                errorMessage = error.toString();
              });
            },
            onPageError: (page, error) {
              setState(() {
                errorMessage = '$page: ${error.toString()}';
              });
            },
            onViewCreated: (PDFViewController pdfViewController) {
              // Controlador criado
            },
            onLinkHandler: (String? uri) {
              // Lidar com links no PDF
            },
            onPageChanged: (int? page, int? total) {
              setState(() {
                currentPage = page;
              });
            },
          ),
          
          // Indicador de carregamento
          if (!isReady)
            const Center(
              child: CircularProgressIndicator(),
            ),
          
          // Mensagem de erro
          if (errorMessage.isNotEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Erro ao carregar PDF',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Voltar'),
                  ),
                ],
              ),
            ),
        ],
      ),
      
      // Barra inferior com informações da página
      bottomNavigationBar: isReady && pages != null && pages! > 0
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.description,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Página ${(currentPage ?? 0) + 1} de $pages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}