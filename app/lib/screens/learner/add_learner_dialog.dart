import 'package:flutter/material.dart';
import '../../models/learner.dart';
import '../../services/learner_service.dart';

class AddLearnerDialog extends StatefulWidget {
  const AddLearnerDialog({Key? key}) : super(key: key);

  @override
  State<AddLearnerDialog> createState() => _AddLearnerDialogState();
}

class _AddLearnerDialogState extends State<AddLearnerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _diagnosisController = TextEditingController();
  DateTime? _selectedBirthDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _diagnosisController.dispose();
    super.dispose();
  }
  
  // Função para formatar a data manualmente no formato DD/MM/YYYY
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Função para selecionar a data de nascimento
  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime.now().subtract(const Duration(days: 365 * 5)), // 5 anos atrás por padrão
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Selecione a data de nascimento',
      fieldLabelText: 'Dia/Mês/Ano',
      fieldHintText: 'DD/MM/YYYY',
      confirmText: 'CONFIRMAR',
      cancelText: 'CANCELAR',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade500,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  // Função para registrar um novo aprendiz
  Future<void> _registerLearner() async {
    if (_formKey.currentState!.validate() && _selectedBirthDate != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Criar um novo aprendiz
        final newLearner = Learner(
          id: LearnerService.generateUniqueId(),
          name: _nameController.text.trim(),
          birthDate: _selectedBirthDate!,
          diagnosis: _diagnosisController.text.trim().isNotEmpty 
              ? _diagnosisController.text.trim() 
              : null,
          createdAt: DateTime.now(),
          lastAccess: DateTime.now(),
        );

        // Adicionar o aprendiz
        final success = await LearnerService.addLearner(newLearner);

        if (success) {
          if (!mounted) return;
          
          // Retornar true indicando que foi adicionado com sucesso
          Navigator.of(context).pop(true);
        } else {
          if (!mounted) return;
          
          // Mostrar erro caso não consiga adicionar
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao registrar aprendiz. Tente novamente.'),
              backgroundColor: Colors.red,
            ),
          );
          
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao registrar aprendiz. Tente novamente.'),
            backgroundColor: Colors.red,
          ),
        );
        
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar Aprendiz'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Campo de nome
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Nome do Aprendiz",
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
              GestureDetector(
                onTap: () => _selectBirthDate(context),
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: "Data de Nascimento",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                      hintText: 'DD/MM/YYYY',
                    ),
                    controller: TextEditingController(
                      text: _selectedBirthDate != null
                          ? _formatDate(_selectedBirthDate!)
                          : '',
                    ),
                    validator: (value) {
                      if (_selectedBirthDate == null) {
                        return "Por favor, selecione a data de nascimento";
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Campo de diagnóstico (opcional)
              TextFormField(
                controller: _diagnosisController,
                decoration: const InputDecoration(
                  labelText: "Diagnóstico (opcional)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medical_information),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('CANCELAR'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _registerLearner,
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
              : const Text('ADICIONAR'),
        ),
      ],
    );
  }
}