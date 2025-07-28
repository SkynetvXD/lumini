import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'profile',
    ],
  );

  static const String _therapistDataKey = 'therapist_data';
  static const String _isLoggedInKey = 'is_therapist_logged_in';

  // 🔒 LISTA DE EMAILS AUTORIZADOS PARA TERAPEUTAS
  // ADICIONE AQUI OS EMAILS DOS TERAPEUTAS AUTORIZADOS
  static const List<String> _authorizedTherapistEmails = [
    'cogluna.contact@gmail.com',           // ← SEU EMAIL PRINCIPAL
    'bruna81adm@gmail.com',               // ← EMAIL INSTITUCIONAL
    'leobraga.25@gmail.com',                   // ← EMAIL ADMIN
    
    // 📝 ADICIONE MAIS EMAILS AUTORIZADOS AQUI:
    // 'dr.fulano@gmail.com',
    // 'dra.cicrana@hotmail.com',
    // 'terapeuta.exemplo@clinica.com.br',
  ];

  // 🔒 DOMÍNIOS INSTITUCIONAIS AUTORIZADOS (OPCIONAL)
  static const List<String> _authorizedDomains = [
    '@cogluna.com',                        // ← SEU DOMÍNIO
    // '@hospital.com.br',                 // ← HOSPITAL
    // '@clinica.med.br',                  // ← CLÍNICA
  ];

  // Modelo para dados do terapeuta
  static Future<void> _saveTherapistData(Map<String, dynamic> therapistData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_therapistDataKey, jsonEncode(therapistData));
    await prefs.setBool(_isLoggedInKey, true);
  }

  // Obter dados do terapeuta logado
  static Future<Map<String, dynamic>?> getTherapistData() async {
    final prefs = await SharedPreferences.getInstance();
    final dataString = prefs.getString(_therapistDataKey);
    
    if (dataString != null) {
      return Map<String, dynamic>.from(jsonDecode(dataString));
    }
    return null;
  }

  // Verificar se terapeuta está logado
  static Future<bool> isTherapistLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    
    // Verificar também se o usuário do Firebase ainda está logado
    final user = _auth.currentUser;
    
    if (isLoggedIn && user != null) {
      // Verificar se o email ainda está autorizado
      return _isValidTherapistEmail(user.email ?? '');
    }
    
    return false;
  }

  // Login com Google - SEGURO
  static Future<Map<String, dynamic>?> signInWithGoogle() async {
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
        final email = user.email ?? '';
        
        // 🔒 VERIFICAÇÃO RIGOROSA DE SEGURANÇA
        if (!_isValidTherapistEmail(email)) {
          await signOut();
          throw Exception('🚫 ACESSO NEGADO\n\nEmail: $email\n\nEste email não está autorizado para acesso de terapeuta.\n\nEmails autorizados:\n${_getAuthorizedEmailsList()}');
        }

        // Salvar dados do terapeuta autorizado
        final therapistData = {
          'uid': user.uid,
          'name': user.displayName ?? 'Terapeuta',
          'email': email,
          'photoUrl': user.photoURL ?? '',
          'loginTime': DateTime.now().toIso8601String(),
          'authorized': true,
        };

        await _saveTherapistData(therapistData);
        
        return therapistData;
      }

      return null;
    } catch (e) {
      // Log do erro para debug
      print('Erro no login com Google: $e');
      rethrow;
    }
  }

  // 🔒 VERIFICAÇÃO RIGOROSA DE EMAIL DE TERAPEUTA
  static bool _isValidTherapistEmail(String email) {
    final emailLower = email.toLowerCase().trim();
    
    // Verificar se está na lista de emails específicos autorizados
    if (_authorizedTherapistEmails.contains(emailLower)) {
      return true;
    }
    
    // Verificar se pertence a domínio autorizado
    for (String domain in _authorizedDomains) {
      if (emailLower.endsWith(domain.toLowerCase())) {
        return true;
      }
    }
    
    // 🚫 ACESSO NEGADO - email não autorizado
    return false;
  }

  // Obter lista de emails autorizados (para mensagem de erro)
  static String _getAuthorizedEmailsList() {
    final buffer = StringBuffer();
    
    if (_authorizedTherapistEmails.isNotEmpty) {
      buffer.writeln('Emails específicos:');
      for (String email in _authorizedTherapistEmails) {
        buffer.writeln('• $email');
      }
    }
    
    if (_authorizedDomains.isNotEmpty) {
      buffer.writeln('\nDomínios autorizados:');
      for (String domain in _authorizedDomains) {
        buffer.writeln('• *$domain');
      }
    }
    
    return buffer.toString();
  }

  // Logout
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_therapistDataKey);
      await prefs.setBool(_isLoggedInKey, false);
    } catch (e) {
      print('Erro no logout: $e');
      rethrow;
    }
  }

  // Obter usuário atual do Firebase
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Stream para mudanças no estado de autenticação
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Reautenticar usuário (útil para operações sensíveis)
  static Future<bool> reauthenticate() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      
      if (googleUser == null) {
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final user = _auth.currentUser;
      if (user != null) {
        await user.reauthenticateWithCredential(credential);
        
        // Verificar se ainda está autorizado
        return _isValidTherapistEmail(user.email ?? '');
      }

      return false;
    } catch (e) {
      print('Erro na reautenticação: $e');
      return false;
    }
  }

  // Deletar conta (se necessário)
  static Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.delete();
        await signOut();
      }
    } catch (e) {
      print('Erro ao deletar conta: $e');
      rethrow;
    }
  }

  // Atualizar perfil do terapeuta
  static Future<void> updateTherapistProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName);
        await user.updatePhotoURL(photoURL);
        
        // Atualizar dados salvos localmente
        final therapistData = await getTherapistData();
        if (therapistData != null) {
          therapistData['name'] = displayName ?? therapistData['name'];
          therapistData['photoUrl'] = photoURL ?? therapistData['photoUrl'];
          await _saveTherapistData(therapistData);
        }
      }
    } catch (e) {
      print('Erro ao atualizar perfil: $e');
      rethrow;
    }
  }

  // Verificar se precisa de reautenticação (para operações sensíveis)
  static Future<bool> needsReauth() async {
    final user = _auth.currentUser;
    if (user == null) return true;
    
    // Verificar último login (Firebase automaticamente requer reauth após certo tempo)
    final metadata = user.metadata;
    final lastSignIn = metadata.lastSignInTime;
    
    if (lastSignIn == null) return true;
    
    // Requer reauth se o último login foi há mais de 5 minutos (para operações críticas)
    final now = DateTime.now();
    final difference = now.difference(lastSignIn);
    
    return difference.inMinutes > 5;
  }

  // 🔧 MÉTODOS ADMINISTRATIVOS

  // Verificar se um email está autorizado (debug)
  static bool checkEmailAuthorization(String email) {
    return _isValidTherapistEmail(email);
  }

  // Obter lista de emails autorizados (debug)
  static List<String> getAuthorizedEmails() {
    return List.from(_authorizedTherapistEmails);
  }

  // Obter lista de domínios autorizados (debug)
  static List<String> getAuthorizedDomains() {
    return List.from(_authorizedDomains);
  }

  // 🔒 VALIDAÇÃO ADICIONAL DE SEGURANÇA
  static Future<bool> validateCurrentSession() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      final email = user.email ?? '';
      if (!_isValidTherapistEmail(email)) {
        await signOut();
        return false;
      }
      
      return true;
    } catch (e) {
      print('Erro na validação de sessão: $e');
      return false;
    }
  }
}