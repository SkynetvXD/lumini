import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/therapist_patient_service.dart';
import '../../services/auth_service.dart';

class AddPatientByEmailDialog extends StatefulWidget {
  const AddPatientByEmailDialog({super.key});

  @override
  State<AddPatientByEmailDialog> createState() => _AddPatientByEmailDialogState();
}

class _AddPatientByEmailDialogState extends State<AddPatientByEmailDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _diagnosisController = TextEditingController();
  DateTime? _selectedBirthDate;
  bool _isLoading = false;
  String? _dateErrorText;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _diagnosisController.dispose();
    super.dispose();
  }
  
  // Método para atualizar a data de nascimento
  void _updateBirthDate(String value) {
    if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(value)) {
      try {
        final parts = value.split('/');
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        
        if (day >= 1 && day <= 31 && month >= 1 && month <= 12 && year >= 1900 && year <= DateTime.now().year) {
          final date = DateTime(year, month, day);
          
          if (day == date.day && month == date.month && year == date.year) {
            setState(() {
              _selectedBirthDate = date;
              _dateErrorText = null;
            });
            return;
          }
        }
        
        setState(() {
          _dateErrorText = 'Data inválida';
          _selectedBirthDate = null;
        });
      } catch (e) {
        setState(() {
          _dateErrorText = 'Data inválida';
          _selectedBirthDate = null;
        });
      }
    } else if (value.isNotEmpty) {
      setState(() {
        _dateErrorText = 'Formato inválido. Use DD/MM/AAAA';
        _selectedBirthDate = null;
      });
    } else {
      setState(() {
        _dateErrorText = null;
        _selectedBirthDate = null;
      });
    }
  }

  // Função para registrar o paciente
  Future<void> _registerPatient() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Obter dados do terapeuta logado
        final therapistData = await AuthService.getTherapistData();
        if (therapistData == null) {
          throw Exception('Terapeuta não encontrado');
        }

        // Convidar paciente
        final result = await TherapistPatientService.invitePatient(
          email: _emailController.text.trim(),
          name: _nameController.text.trim(),
          therapistId: therapistData['uid'],
          birthDate: _selectedBirthDate,
          diagnosis: _diagnosisController.text.trim().isNotEmpty 
              ? _diagnosisController.text.trim() 
              : null,
        );

        if (!mounted) return;
        
        // Mostrar diálogo de sucesso
        _showSuccessDialog(result, therapistData);
      } catch (e) {
        if (!mounted) return;
        
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('Limite de')) {
      return 'Você atingiu o limite de 10 pacientes';
    } else if (error.contains('já está cadastrado')) {
      return 'Este email já está cadastrado como seu paciente';
    } else if (error.contains('Terapeuta não encontrado')) {
      return 'Erro de autenticação. Faça login novamente';
    } else {
      return 'Erro ao registrar paciente. Tente novamente';
    }
  }

  // 🆕 Implementar compartilhamento funcional
  Future<void> _sharePatientInstructions(Map<String, String> result, Map<String, dynamic> therapistData) async {
    try {
      // Gerar mensagem completa para compartilhar
      final message = _generateInstructionMessage(result, therapistData);
      
      // Mostrar opções de compartilhamento
      await _showShareOptions(message, result['email']!);
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao compartilhar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🆕 Gerar mensagem de instruções completa
  String _generateInstructionMessage(Map<String, String> result, Map<String, dynamic> therapistData) {
    final patientName = _nameController.text.trim();
    final patientEmail = result['email']!;
    final therapistName = therapistData['name'] ?? 'Seu terapeuta';
    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());

    return '''
🏥 LUMIMI - Acesso do Paciente 🏥

Olá $patientName!

Você foi cadastrado(a) no aplicativo Lumimi para realizar treinos terapêuticos personalizados.

📱 COMO ACESSAR:

1️⃣ Baixe o app "Lumimi" na loja de aplicativos

2️⃣ Abra o aplicativo e escolha "Paciente"

3️⃣ Toque em "Entrar com Google"

4️⃣ Use esta conta de email:
📧 $patientEmail

5️⃣ Comece seus treinos personalizados!

🎯 TREINOS DISPONÍVEIS:
• Treino de Cores
• Treino de Formas  
• Treino de Quantidades
• E muito mais em breve!

👨‍⚕️ EQUIPE RESPONSÁVEL: $therapistName

📅 Data de cadastro: $today

⭐ IMPORTANTE:
- Use sempre o mesmo email para acessar
- Seus progressos ficam salvos automaticamente
- Em caso de dúvidas, entre em contato com sua equipe

🚀 Pronto para começar sua jornada de aprendizado!

#Lumimi #Terapia #Aprendizado''';
  }

  // 🆕 Mostrar opções de compartilhamento
  Future<void> _showShareOptions(String message, String patientEmail) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Título
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            const Text(
              'Compartilhar Instruções',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Envie as instruções para: $patientEmail',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            
            // Opções de compartilhamento
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // WhatsApp
                _buildShareOption(
                  icon: Icons.chat,
                  label: 'WhatsApp',
                  color: Colors.green,
                  onTap: () async {
                    Navigator.pop(context);
                    await Share.share(
                      message,
                      subject: 'Instruções de Acesso - Lumimi',
                    );
                    _showSuccessMessage('Instruções compartilhadas!');
                  },
                ),
                
                // Email
                _buildShareOption(
                  icon: Icons.email,
                  label: 'Email',
                  color: Colors.blue,
                  onTap: () async {
                    Navigator.pop(context);
                    await Share.share(
                      message,
                      subject: 'Suas Instruções de Acesso - App Lumimi',
                    );
                    _showSuccessMessage('Instruções compartilhadas!');
                  },
                ),
                
                // Copiar
                _buildShareOption(
                  icon: Icons.copy,
                  label: 'Copiar',
                  color: Colors.orange,
                  onTap: () async {
                    Navigator.pop(context);
                    await Clipboard.setData(ClipboardData(text: message));
                    _showSuccessMessage('Instruções copiadas para a área de transferência!');
                  },
                ),
                
                // Mais opções
                _buildShareOption(
                  icon: Icons.share,
                  label: 'Outros',
                  color: Colors.purple,
                  onTap: () async {
                    Navigator.pop(context);
                    await Share.share(
                      message,
                      subject: 'Instruções de Acesso - Lumimi',
                    );
                    _showSuccessMessage('Instruções compartilhadas!');
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Botão cancelar
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }

  // 🆕 Widget para opção de compartilhamento
  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: color.withAlpha(76)),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 Mostrar mensagem de sucesso
  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessDialog(Map<String, String> result, Map<String, dynamic> therapistData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700),
            const SizedBox(width: 8),
            const Text('Paciente Registrado!'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result['inviteMessage'] ?? '',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.email, color: Colors.blue.shade700, size: 16),
                        const SizedBox(width: 4),
                        const Text(
                          'Email do paciente:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result['email'] ?? '',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.orange.shade700, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Use o botão "COMPARTILHAR" para enviar as instruções completas!',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Fechar diálogo de sucesso
              Navigator.of(context).pop(true); // Fechar diálogo principal e retornar sucesso
            },
            child: const Text('CONCLUIR'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop(); // Fechar diálogo de sucesso
              Navigator.of(context).pop(true); // Fechar diálogo principal e retornar sucesso
              
              // 🆕 Implementar compartilhamento real
              await _sharePatientInstructions(result, therapistData);
            },
            icon: const Icon(Icons.share, size: 16),
            label: const Text('COMPARTILHAR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxDialogWidth = MediaQuery.of(context).size.width * 0.95;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.person_add, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Registrar Paciente por Email',
              style: const TextStyle(fontSize: 20),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxDialogWidth),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Informação importante
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                          const SizedBox(width: 4),
                          const Text(
                            'Como funciona:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '• O paciente precisará do email informado\n• Ele fará login com conta Google\n• Os dados dos treinos ficarão isolados\n• Você terá acesso aos relatórios dele',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Campo de email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Email do Paciente *",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                    hintText: 'paciente@email.com',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Por favor, informe o email";
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                      return "Por favor, informe um email válido";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Campo de nome
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Nome do Paciente *",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 2) {
                      return "Por favor, informe um nome válido";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Campo de data de nascimento
                TextFormField(
                  decoration: InputDecoration(
                    labelText: "Data de Nascimento (opcional)",
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.calendar_today),
                    hintText: 'DD/MM/AAAA',
                    errorText: _dateErrorText,
                    helperText: 'Exemplo: 15/08/2010',
                  ),
                  keyboardType: TextInputType.datetime,
                  onChanged: _updateBirthDate,
                ),
                const SizedBox(height: 16),
                
                // Campo de diagnóstico
                TextFormField(
                  controller: _diagnosisController,
                  decoration: const InputDecoration(
                    labelText: "Diagnóstico (opcional)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.medical_information),
                  ),
                  maxLines: 2,
                ),
                
                const SizedBox(height: 20),
                
                // Aviso sobre limite
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_outlined, color: Colors.orange.shade700, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Limite: 10 pacientes por terapeuta',
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('CANCELAR'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _registerPatient,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('REGISTRAR'),
        ),
      ],
    );
  }
}