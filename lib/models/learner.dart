import 'dart:convert';

class Learner {
  final String id;
  final String name;
  final DateTime birthDate;
  final String? diagnosis;
  final DateTime createdAt;
  final DateTime? lastAccess;
  
  // NOVOS CAMPOS para suporte Gmail (opcionais)
  final String? email;          // Para autenticação Gmail
  final String? therapistId;    // ID do terapeuta responsável
  final bool isActive;          // Controle ativo/inativo
  final bool isAuthenticated;   // Gmail=true, Local=false

  Learner({
    required this.id,
    required this.name,
    required this.birthDate,
    this.diagnosis,
    required this.createdAt,
    this.lastAccess,
    // Novos campos opcionais
    this.email,
    this.therapistId,
    this.isActive = true,
    this.isAuthenticated = false, // false = local, true = Gmail
  });

  // Idade do aprendiz em anos
  int get age {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || 
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  // Verificar se é paciente autenticado
  bool get isGmailPatient => isAuthenticated && email != null;
  
  // Verificar se é learner local
  bool get isLocalLearner => !isAuthenticated;

  // Converter para um mapa (para armazenamento)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'birthDate': birthDate.toIso8601String(),
      'diagnosis': diagnosis,
      'createdAt': createdAt.toIso8601String(),
      'lastAccess': lastAccess?.toIso8601String(),
      // Novos campos
      'email': email,
      'therapistId': therapistId,
      'isActive': isActive,
      'isAuthenticated': isAuthenticated,
    };
  }

  // Criar a partir de um mapa (para recuperação)
  factory Learner.fromMap(Map<String, dynamic> map) {
    return Learner(
      id: map['id'],
      name: map['name'],
      birthDate: DateTime.parse(map['birthDate']),
      diagnosis: map['diagnosis'],
      createdAt: DateTime.parse(map['createdAt']),
      lastAccess: map['lastAccess'] != null ? DateTime.parse(map['lastAccess']) : null,
      // Novos campos com fallback para compatibilidade
      email: map['email'],
      therapistId: map['therapistId'],
      isActive: map['isActive'] ?? true,
      isAuthenticated: map['isAuthenticated'] ?? false,
    );
  }

  // Atualizar o momento do último acesso
  Learner updateLastAccess() {
    return Learner(
      id: id,
      name: name,
      birthDate: birthDate,
      diagnosis: diagnosis,
      createdAt: createdAt,
      lastAccess: DateTime.now(),
      email: email,
      therapistId: therapistId,
      isActive: isActive,
      isAuthenticated: isAuthenticated,
    );
  }

  // Converter para JSON
  String toJson() => jsonEncode(toMap());

  // Criar a partir de JSON
  factory Learner.fromJson(String source) => Learner.fromMap(jsonDecode(source));

  // Método copyWith para criar cópias com modificações
  Learner copyWith({
    String? id,
    String? name,
    DateTime? birthDate,
    String? diagnosis,
    DateTime? createdAt,
    DateTime? lastAccess,
    String? email,
    String? therapistId,
    bool? isActive,
    bool? isAuthenticated,
  }) {
    return Learner(
      id: id ?? this.id,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      diagnosis: diagnosis ?? this.diagnosis,
      createdAt: createdAt ?? this.createdAt,
      lastAccess: lastAccess ?? this.lastAccess,
      email: email ?? this.email,
      therapistId: therapistId ?? this.therapistId,
      isActive: isActive ?? this.isActive,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }

  // Factory para criar learner local (sistema antigo)
  factory Learner.createLocal({
    required String name,
    required DateTime birthDate,
    String? diagnosis,
  }) {
    return Learner(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      birthDate: birthDate,
      diagnosis: diagnosis,
      createdAt: DateTime.now(),
      isAuthenticated: false, // Local
    );
  }

  // Factory para criar paciente Gmail
  factory Learner.createGmailPatient({
    required String email,
    required String name,
    required String therapistId,
    DateTime? birthDate,
    String? diagnosis,
  }) {
    return Learner(
      id: '${DateTime.now().millisecondsSinceEpoch}_gmail',
      name: name,
      birthDate: birthDate ?? DateTime.now(),
      diagnosis: diagnosis,
      createdAt: DateTime.now(),
      email: email,
      therapistId: therapistId,
      isAuthenticated: true, // Gmail
    );
  }
}