// Modes de règlement proposés à l'encaissement.

import 'package:flutter/material.dart';

enum ModePaiement {
  especes('ESPECES', 'Espèces', Icons.payments_outlined),
  cheque('CHEQUE', 'Chèque', Icons.receipt_long_outlined),
  virement('VIREMENT', 'Virement', Icons.account_balance_outlined),
  carte('CARTE', 'Carte (CIB/Edahabia)', Icons.credit_card),
  // "Crédit" = rien n'est encaissé, le montant va au solde du client.
  credit('CREDIT', 'À crédit', Icons.schedule);

  const ModePaiement(this.code, this.libelle, this.icone);
  final String code;
  final String libelle;
  final IconData icone;
}
