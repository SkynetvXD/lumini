import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/learner.dart';
import 'therapist_patient_service.dart';

class PatientAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'profile',
    ],
  );

  static const String _patientDataKey = 'patient_data';
  static const String _isPatientLoggedInKey = 'is_patient_logged_in';

  // Salvar dados do paciente logado
  static Future<void> _savePatientData(Learner patient) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_patientDataKey, patient.toJson());
    await prefs.setBool(_isPatientLoggedInKey, true);
  }

  // Obter dados do paciente logado
  static Future<Learner?> getPatientData() async {
    final prefs = await SharedPreferences.getInstance();
    final dataString = prefs.getString(_patientDataKey);
    
    if (dataString != null) {
      return Learner.fromJson(dataString);
    }
    return null;
  }

  // Verificar se paciente está logado
  static Future<bool> isPatientLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isPatientLoggedInKey) ?? false;
    
    // Verificar também se o usuário do Firebase ainda está logado
    final user = _auth.currentUser;
    
    return isLoggedIn && user != null;
  }

  // Login com Google para paciente
  static Future<Learner?> signInWithGoogle() async {
    try {
      // Deslogar primeiro para forçar seleção de conta
      await _googleSignIn.signOut();
      
      // Iniciar processo de login
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // Usuário cancelou o login
        return null;
      }

      // Obter tokens de autenticação
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Criar credencial para Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Fazer login no Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Verificar se o email está registrado como paciente
        final patient = await TherapistPatientService.getPatientByEmail(user.email!);
        
        if (patient == null) {
          await signOut();
          throw Exception('Este email não está registrado como paciente.\nEntre em contato com seu terapeuta.');
        }

        if (!patient.isActive) {
          await signOut();
          throw Exception('Sua conta está inativa.\nEntre em contato com seu terapeuta.');
        }

        // Atualizar último acesso
        final updatedPatient = patient.updateLastAccess();
        await TherapistPatientService.updatePatient(updatedPatient);

        // Salvar dados do paciente logado
        await _savePatientData(updatedPatient);
        
        return updatedPatient;
      }

      return null;
    } catch (e) {
      print('Erro no login do paciente: $e');
      rethrow;
    }
  }

  // Logout do paciente
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_patientDataKey);
      await prefs.setBool(_isPatientLoggedInKey, false);
    } catch (e) {
      print('Erro no logout do paciente: $e');
      rethrow;
    }
  }

  // Obter usuário atual do Firebase
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Stream para mudanças no estado de autenticação
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Atualizar dados do paciente
  static Future<bool> updatePatientData(Learner patient) async {
    try {
      final success = await TherapistPatientService.updatePatient(patient);
      if (success) {
        await _savePatientData(patient);
      }
      return success;
    } catch (e) {
      print('Erro ao atualizar dados do paciente: $e');
      return false;
    }
  }

  // Obter ID único do paciente para dados isolados
  static Future<String?> getPatientUniqueId() async {
    final patient = await getPatientData();
    return patient?.id;
  }

  // Verificar se o paciente atual pertence a um terapeuta específico
  static Future<bool> belongsToTherapist(String therapistId) async {
    final patient = await getPatientData();
    return patient?.therapistId == therapistId;
  }

  // Obter terapeuta responsável pelo paciente atual
  static Future<String?> getTherapistId() async {
    final patient = await getPatientData();
    return patient?.therapistId;
  }
}