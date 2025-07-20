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
    
    return isLoggedIn && user != null;
  }

  // Login com Google
  static Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      // Deslogar primeiro para forçar seleção de conta
      await _googleSignIn.signOut();
      
      // Iniciar processo de login - API CORRETA
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
        // Verificar se é um email válido para terapeuta
        if (!_isValidTherapistEmail(user.email ?? '')) {
          await signOut();
          throw Exception('Email não autorizado para acesso de terapeuta');
        }

        // Salvar dados do terapeuta
        final therapistData = {
          'uid': user.uid,
          'name': user.displayName ?? 'Terapeuta',
          'email': user.email ?? '',
          'photoUrl': user.photoURL ?? '',
          'loginTime': DateTime.now().toIso8601String(),
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

  // Verificar se o email é válido para terapeuta
  static bool _isValidTherapistEmail(String email) {
    // Lista de emails específicos permitidos (ADICIONE SEUS EMAILS AQUI)
    final allowedEmails = [
      'cogluna.contact@gmail.com',           // ← ADICIONE SEU EMAIL AQUI
      'terapeuta@cogluna.com',        // Exemplo com seu domínio
      'admin@cogluna.com',            // Exemplo admin
      // Adicione mais emails conforme necessári
    ];

    // Lista de domínios permitidos
    final allowedDomains = [
      '@gmail.com',
      '@hotmail.com',
      '@outlook.com',
      '@yahoo.com',
      '@cogluna.com',                 // Seu domínio
      // Adicione domínios específicos da sua instituição
      // '@hospital.com.br',
      // '@clinica.med.br',
    ];

    // Se houver emails específicos permitidos, verificar primeiro
    if (allowedEmails.isNotEmpty && allowedEmails.contains(email.toLowerCase())) {
      return true;
    }

    // Verificar domínios permitidos
    for (String domain in allowedDomains) {
      if (email.toLowerCase().endsWith(domain)) {
        return true;
      }
    }

    // DESENVOLVIMENTO: permitir qualquer email Gmail (REMOVER EM PRODUÇÃO)
    if (email.toLowerCase().endsWith('@gmail.com')) {
      return true;
    }

    return false;
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
        return true;
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
}