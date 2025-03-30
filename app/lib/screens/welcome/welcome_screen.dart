import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../models/learner.dart';
import '../../services/learner_service.dart';
import '../common_widgets/gradient_background.dart';
import '../menu/menu_trainings_page.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
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
          // Navegação para a tela principal
          if (!mounted) return;
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MenuTrainingsPage()),
          );
        } else {
          if (!mounted) return;
          
          // Mostrar erro caso não consiga adicionar
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao registrar aprendiz. Tente novamente.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        colors: AppColors.menuGradient,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  
                  // Logo e título
                  Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.school,
                          color: Colors.white,
                          size: 80,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Lumimi",
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Aprendizado divertido!",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white.withAlpha(220),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Card com formulário
                  Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Vamos começar!",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Preencha os dados do aprendiz para continuar",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 24),
                            
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
                            const SizedBox(height: 24),
                            
                            // Botão de cadastro
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _registerLearner,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text(
                                        "CADASTRAR",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}