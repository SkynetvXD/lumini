// lib/services/unified_auth_service.dart
// Integração completa entre autenticação nativa e Google OAuth
import 'dart:async';
import '../services/auth_service.dart';
import '../services/patient_auth_service.dart';
import '../services/native_auth_service.dart';

class UnifiedAuthService {
  
  // ==================== TERAPEUTA ====================
  
  /// Verificar se terapeuta está logado (qualquer método)
  static Future<bool> isTherapistLoggedIn() async {
    try {
      // 1. PRIORIDADE: Verificar login nativo primeiro
      final isNativeLoggedIn = await NativeAuthService.isTherapistLoggedInNative();
      if (isNativeLoggedIn) {
        print('✅ Terapeuta nativo está logado');
        return true;
      }
      
      // 2. Verificar login Google OAuth
      try {
        final isGoogleLoggedIn = await AuthService.isTherapistLoggedIn();
        if (isGoogleLoggedIn) {
          print('✅ Terapeuta Google está logado');
          return true;
        }
      } catch (e) {
        print('⚠️ Erro na verificação Google do terapeuta (ignorado): $e');
      }
      
      print('❌ Nenhum terapeuta logado');
      return false;
    } catch (e) {
      print('❌ Erro geral na verificação de terapeuta: $e');
      return false;
    }
  }

  /// Obter dados do terapeuta logado (qualquer método)
  static Future<Map<String, dynamic>?> getTherapistData() async {
    try {
      // 1. Tentar dados nativos primeiro
      final nativeData = await NativeAuthService.getTherapistDataNative();
      if (nativeData != null) {
        print('✅ Dados de terapeuta nativo obtidos');
        return nativeData;
      }
      
      // 2. Tentar dados do Google OAuth
      try {
        final googleData = await AuthService.getTherapistData();
        if (googleData != null) {
          print('✅ Dados de terapeuta Google obtidos');
          return googleData;
        }
      } catch (e) {
        print('⚠️ Erro ao obter dados Google do terapeuta (ignorado): $e');
      }
      
      print('❌ Nenhum dado de terapeuta encontrado');
      return null;
    } catch (e) {
      print('❌ Erro geral ao obter dados do terapeuta: $e');
      return null;
    }
  }

  /// Logout completo do terapeuta
  static Future<void> signOutTherapist() async {
    try {
      print('🚪 Fazendo logout completo do terapeuta...');
      
      // Fazer logout de ambos os métodos
      await Future.wait([
        NativeAuthService.signOutTherapist().catchError((e) {
          print('⚠️ Erro no logout nativo (ignorado): $e');
        }),
        AuthService.signOut().catchError((e) {
          print('⚠️ Erro no logout Google (ignorado): $e');
        }),
      ]);
      
      print('✅ Logout completo do terapeuta realizado');
    } catch (e) {
      print('❌ Erro no logout de terapeuta: $e');
      // Continuar mesmo se houver erro para garantir limpeza
    }
  }

  // ==================== PACIENTE ====================
  
  /// Verificar se paciente está logado (qualquer método)
  static Future<bool> isPatientLoggedIn() async {
    try {
      // 1. PRIORIDADE: Verificar login nativo primeiro
      final isNativeLoggedIn = await NativeAuthService.isPatientLoggedInNative();
      if (isNativeLoggedIn) {
        print('✅ Paciente nativo está logado');
        return true;
      }
      
      // 2. Verificar login Google OAuth
      try {
        final isGoogleLoggedIn = await PatientAuthService.isPatientLoggedIn();
        if (isGoogleLoggedIn) {
          print('✅ Paciente Google está logado');
          return true;
        }
      } catch (e) {
        print('⚠️ Erro na verificação Google do paciente (ignorado): $e');
      }
      
      print('❌ Nenhum paciente logado');
      return false;
    } catch (e) {
      print('❌ Erro geral na verificação de paciente: $e');
      return false;
    }
  }

  /// Obter dados do paciente logado (qualquer método)
  static Future<Map<String, dynamic>?> getPatientData() async {
    try {
      // 1. Tentar dados nativos primeiro
      final nativeData = await NativeAuthService.getPatientDataNative();
      if (nativeData != null) {
        print('✅ Dados de paciente nativo obtidos');
        return nativeData;
      }
      
      // 2. Tentar dados do Google OAuth (conversão necessária)
      try {
        final learner = await PatientAuthService.getPatientData();
        if (learner != null) {
          print('✅ Dados de paciente Google obtidos');
          return {
//'id': learner['id'] ?? learner['uid'],
   //         'name': learner['name'],
    //        'email': learner['email'],
      //      'birthDate': learner['birthDate'],
        //    'therapistId': learner['therapistId'],
          //  'isActive': learner['isActive'] ?? true,
            //'lastAccess': learner['lastAccess'],
            //'authMethod': 'google',
          };
        }
      } catch (e) {
        print('⚠️ Erro ao obter dados Google do paciente (ignorado): $e');
      }
      
      print('❌ Nenhum dado de paciente encontrado');
      return null;
    } catch (e) {
      print('❌ Erro geral ao obter dados do paciente: $e');
      return null;
    }
  }

  /// Logout completo do paciente
  static Future<void> signOutPatient() async {
    try {
      print('🚪 Fazendo logout completo do paciente...');
      
      // Fazer logout de ambos os métodos
      await Future.wait([
        NativeAuthService.signOutPatient().catchError((e) {
          print('⚠️ Erro no logout nativo (ignorado): $e');
        }),
        PatientAuthService.signOut().catchError((e) {
          print('⚠️ Erro no logout Google (ignorado): $e');
        }),
      ]);
      
      print('✅ Logout completo do paciente realizado');
    } catch (e) {
      print('❌ Erro no logout de paciente: $e');
      // Continuar mesmo se houver erro para garantir limpeza
    }
  }

  // ==================== UTILITÁRIOS ====================
  
  /// Verificar qual método de autenticação está ativo
  static Future<String?> getActiveAuthMethod() async {
    try {
      // Verificar terapeuta nativo
      if (await NativeAuthService.isTherapistLoggedInNative()) {
        return 'native_therapist';
      }
      
      // Verificar paciente nativo
      if (await NativeAuthService.isPatientLoggedInNative()) {
        return 'native_patient';
      }
      
      // Verificar terapeuta Google
      try {
        if (await AuthService.isTherapistLoggedIn()) {
          return 'google_therapist';
        }
      } catch (e) {
        print('⚠️ Erro na verificação Google terapeuta (ignorado): $e');
      }
      
      // Verificar paciente Google
      try {
        if (await PatientAuthService.isPatientLoggedIn()) {
          return 'google_patient';
        }
      } catch (e) {
        print('⚠️ Erro na verificação Google paciente (ignorado): $e');
      }
      
      return null;
    } catch (e) {
      print('❌ Erro ao verificar método ativo: $e');
      return null;
    }
  }

  /// Logout completo de todos os métodos
  static Future<void> signOutAll() async {
    try {
      print('🚪 Fazendo logout completo de todos os métodos...');
      
      await Future.wait([
        signOutTherapist(),
        signOutPatient(),
      ]);
      
      print('✅ Logout completo de todos os métodos realizado');
    } catch (e) {
      print('❌ Erro no logout completo: $e');
    }
  }

  /// Verificar se sistema tem usuários nativos disponíveis
  static bool hasNativeUsers() {
    return NativeAuthService.hasUsers();
  }

  /// Fazer login nativo de terapeuta
  static Future<Map<String, dynamic>?> signInTherapistNative(String email, String password) async {
    try {
      return await NativeAuthService.signInTherapistWithEmail(email, password);
    } catch (e) {
      print('❌ Erro no login nativo de terapeuta: $e');
      rethrow;
    }
  }

  /// Fazer login nativo de paciente
  static Future<Map<String, dynamic>?> signInPatientNative(String email, String password) async {
    try {
      return await NativeAuthService.signInPatientWithEmail(email, password);
    } catch (e) {
      print('❌ Erro no login nativo de paciente: $e');
      rethrow;
    }
  }

  /// Fazer login Google de terapeuta
  static Future<Map<String, dynamic>?> signInTherapistGoogle() async {
    try {
      return await AuthService.signInWithGoogle();
    } catch (e) {
      print('❌ Erro no login Google de terapeuta: $e');
      rethrow;
    }
  }

  /// Fazer login Google de paciente
  static Future<dynamic> signInPatientGoogle() async {
    try {
      return await PatientAuthService.signInWithGoogle();
    } catch (e) {
      print('❌ Erro no login Google de paciente: $e');
      rethrow;
    }
  }
}