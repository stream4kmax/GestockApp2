// =============================================================================
//  MessagingService — envoi de messages par WhatsApp et SMS
// =============================================================================
//  Fonctionnement (sans API payante, 100 % gratuit) :
//   • WhatsApp : on ouvre le lien officiel https://wa.me/<numéro>?text=<message>
//     → WhatsApp s'ouvre sur la conversation, message déjà écrit ; l'utilisateur
//       n'a plus qu'à appuyer sur "Envoyer".
//   • SMS      : on ouvre sms:<numéro>?body=<message>
//     → l'application SMS du téléphone s'ouvre avec le texte pré-rempli.
//
//  Le package url_launcher fait le lien avec Android. Pour Android 11+, les
//  déclarations <queries> doivent figurer dans AndroidManifest.xml (voir README).
//
//  Chaque ouverture est enregistrée dans la table `messages` (historique et
//  relances). Statut 'OUVERT' : l'application a été ouverte avec le message ;
//  l'envoi final dépend de l'utilisateur et ne peut pas être confirmé.
// =============================================================================

import 'package:url_launcher/url_launcher.dart';

import 'package:gestock_pos/core/database/database_helper.dart';
import 'package:gestock_pos/core/settings/app_settings.dart';
import 'package:gestock_pos/core/utils/formatters.dart';
import 'package:gestock_pos/core/utils/ids.dart';

enum CanalMessage { whatsapp, sms }

/// Ligne d'un récapitulatif de facture (indépendante du panier ou de la base).
class LigneMessage {
  const LigneMessage(this.designation, this.quantite, this.montantTtc);
  final String designation;
  final double quantite;
  final double montantTtc;
}

class MessagingService {
  MessagingService._();
  static final MessagingService instance = MessagingService._();

  /// Indicatif pays (Outils > Options ; 213 = Algérie par défaut).
  static String get indicatifPays => AppSettings.instance.indicatifPays;

  // ---------------------------------------------------------------------------
  //  Numéros
  // ---------------------------------------------------------------------------

  /// Convertit un numéro saisi en format international SANS "+" (exigé par wa.me).
  ///   "0550 12 34 56"   → "213550123456"
  ///   "+213 550123456"  → "213550123456"
  ///   "00213550123456"  → "213550123456"
  static String normaliser(String brut) {
    var n = brut.replaceAll(RegExp(r'[^0-9+]'), '');
    if (n.startsWith('+')) n = n.substring(1);
    if (n.startsWith('00')) n = n.substring(2);
    if (n.startsWith('0')) n = indicatifPays + n.substring(1);
    return n;
  }

  /// Contrôle simple : un numéro algérien international fait 12 chiffres
  /// (213 + 9). On accepte 10 à 15 chiffres pour les autres pays.
  static bool numeroValide(String? brut) {
    if (brut == null || brut.trim().isEmpty) return false;
    final n = normaliser(brut);
    return n.length >= 10 && n.length <= 15;
  }

  // ---------------------------------------------------------------------------
  //  Envoi
  // ---------------------------------------------------------------------------

  /// Ouvre WhatsApp avec le message pré-rempli. Renvoie false si impossible
  /// (WhatsApp non installé, numéro invalide…).
  Future<bool> envoyerWhatsApp({
    required String numero,
    required String message,
    String objet = 'MESSAGE',
    String? tiersType,
    String? tiersId,
    String? documentId,
  }) async {
    if (!numeroValide(numero)) return false;
    final n = normaliser(numero);
    // Uri.encodeComponent encode les espaces en %20 et les retours à la ligne en %0A
    final uri = Uri.parse('https://wa.me/$n?text=${Uri.encodeComponent(message)}');
    final ok = await _ouvrir(uri);
    if (ok) {
      await _journaliser(CanalMessage.whatsapp, n, message, objet, tiersType, tiersId, documentId);
    }
    return ok;
  }

  /// Ouvre l'application SMS avec le message pré-rempli.
  Future<bool> envoyerSms({
    required String numero,
    required String message,
    String objet = 'MESSAGE',
    String? tiersType,
    String? tiersId,
    String? documentId,
  }) async {
    if (!numeroValide(numero)) return false;
    final n = '+${normaliser(numero)}';
    // ATTENTION : ne pas utiliser Uri(queryParameters: ...) ici, il encode les
    // espaces en "+" et certaines applications SMS affichent alors des "+".
    final uri = Uri.parse('sms:$n?body=${Uri.encodeComponent(message)}');
    final ok = await _ouvrir(uri);
    if (ok) {
      await _journaliser(CanalMessage.sms, n, message, objet, tiersType, tiersId, documentId);
    }
    return ok;
  }

  /// Appel téléphonique direct (bouton "Appeler" des fiches).
  Future<bool> appeler(String numero) => _ouvrir(Uri.parse('tel:${numero.replaceAll(' ', '')}'));

  Future<bool> _ouvrir(Uri uri) async {
    try {
      // externalApplication : ouvre WhatsApp / Messages, pas un navigateur intégré
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<void> _journaliser(CanalMessage canal, String destinataire, String contenu, String objet,
      String? tiersType, String? tiersId, String? documentId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = maintenantUtc();
      await db.insert('messages', {
        'id': nouvelId(),
        'date_envoi': maintenantLocal(),
        'tiers_type': tiersType,
        'tiers_id': tiersId,
        'document_id': documentId,
        'canal': canal == CanalMessage.whatsapp ? 'WHATSAPP' : 'SMS',
        'objet': objet,
        'destinataire': destinataire,
        'contenu': contenu,
        'statut': 'OUVERT',
        'created_at': now,
        'updated_at': now,
        'sync_status': 1,
      });
    } catch (_) {
      // L'historique ne doit jamais empêcher l'envoi : on ignore l'erreur.
    }
  }

  // ---------------------------------------------------------------------------
  //  Modèles de messages pré-remplis
  // ---------------------------------------------------------------------------

  /// Récapitulatif de facture / bon après une vente.
  static String messageFacture({
    required String nomClient,
    required String typeDocument,
    required String numero,
    required DateTime date,
    required List<LigneMessage> lignes,
    required double totalHt,
    required double totalTva,
    required double totalTtc,
    required double montantPaye,
    required String societe,
  }) {
    final b = StringBuffer()
      ..writeln('Bonjour ${_nom(nomClient)},')
      ..writeln()
      ..writeln('Voici le récapitulatif de votre ${typeDocument.toLowerCase()} N° $numero '
          'du ${fmtDate(date)} :')
      ..writeln();
    for (final l in lignes) {
      b.writeln('• ${l.designation} × ${fmtQte(l.quantite)} = ${fmtMonnaie(l.montantTtc)}');
    }
    final reste = round2(totalTtc - montantPaye);
    b
      ..writeln()
      ..writeln('Total HT : ${fmtMonnaie(totalHt)}')
      ..writeln('TVA : ${fmtMonnaie(totalTva)}')
      ..writeln('*Total TTC : ${fmtMonnaie(totalTtc)}*') // *gras* dans WhatsApp
      ..writeln('Payé : ${fmtMonnaie(montantPaye)}');
    if (reste > 0) b.writeln('Reste à payer : ${fmtMonnaie(reste)}');
    b
      ..writeln()
      ..writeln('Merci pour votre confiance.');
    if (societe.isNotEmpty) b.write(societe);
    return b.toString().trim();
  }

  /// Relance de paiement (solde client).
  static String messageRelance({required String nomClient, required double solde, required String societe}) =>
      'Bonjour ${_nom(nomClient)},\n\n'
      'Sauf erreur de notre part, votre compte présente un solde de ${fmtMonnaie(solde)} '
      'restant à régler.\n'
      'Merci de bien vouloir procéder au règlement dès que possible.\n\n'
      'Cordialement,\n$societe';

  /// Promotion / information commerciale.
  static String messagePromotion({required String nomClient, required String societe}) =>
      'Bonjour ${_nom(nomClient)},\n\n'
      'Profitez de nos nouvelles offres cette semaine chez $societe ! '
      'Passez nous voir ou répondez à ce message pour commander.\n\n'
      'À bientôt !';

  /// Bon de commande de réapprovisionnement envoyé à un fournisseur.
  static String messageCommandeFournisseur({
    required String nomFournisseur,
    required List<({String designation, double quantite, String unite})> lignes,
    required String societe,
  }) {
    final b = StringBuffer()
      ..writeln('Bonjour ${_nom(nomFournisseur)},')
      ..writeln()
      ..writeln('Merci de nous préparer la commande suivante :')
      ..writeln();
    for (final l in lignes) {
      b.writeln('• ${l.designation} : ${fmtQte(l.quantite)} ${l.unite}');
    }
    b
      ..writeln()
      ..writeln('Merci de nous confirmer la disponibilité et le délai de livraison.')
      ..writeln()
      ..write('Cordialement,\n$societe');
    return b.toString().trim();
  }

  static String _nom(String nom) => nom == 'Client comptoir' ? 'cher client' : nom;
}
