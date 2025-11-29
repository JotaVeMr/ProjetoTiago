import 'package:flutter/material.dart';

class Medicamento {
  int? id;
  int? usuarioId;

  String nome;
  String tipo;
  String dose;

  String dataHoraAgendamento;
  String dataInicio;
  String dataFim;

  bool isTaken;
  bool isIgnored;
  bool isPendente;

  /// 🔹 Caminho local do arquivo da foto (opcional)
  String? fotoPath;

  Medicamento({
    this.id,
    this.usuarioId,
    required this.nome,
    required this.tipo,
    required this.dose,
    required this.dataHoraAgendamento,
    required this.dataInicio,
    required this.dataFim,
    this.isTaken = false,
    this.isIgnored = false,
    this.isPendente = false,
    this.fotoPath, // ← novo
  });

  // ============================================================
  // 🔹 SALVAR NO SQLITE
  // ============================================================
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuarioId': usuarioId,

      'nome': nome,
      'tipo': tipo,
      'dose': dose,

      'dataHoraAgendamento': dataHoraAgendamento,
      'dataInicio': dataInicio,
      'dataFim': dataFim,

      'isTaken': isTaken ? 1 : 0,
      'isIgnored': isIgnored ? 1 : 0,
      'isPendente': isPendente ? 1 : 0,

      'fotoPath': fotoPath, // ← NOVO
    };
  }

  // ============================================================
  // 🔹 LER DO SQLITE
  // ============================================================
  factory Medicamento.fromMap(Map<String, dynamic> map) {
    return Medicamento(
      id: map['id'],
      usuarioId: map['usuarioId'],

      nome: map['nome'] ?? '',
      tipo: map['tipo'] ?? '',
      dose: map['dose'] ?? '',

      dataHoraAgendamento:
          map['dataHoraAgendamento'] ?? DateTime.now().toIso8601String(),
      dataInicio:
          map['dataInicio'] ?? DateTime.now().toIso8601String(),
      dataFim:
          map['dataFim'] ?? DateTime.now().toIso8601String(),

      isTaken: (map['isTaken'] ?? 0) == 1,
      isIgnored: (map['isIgnored'] ?? 0) == 1,
      isPendente: (map['isPendente'] ?? 0) == 1,

      fotoPath: map['fotoPath'], // ← NOVO
    );
  }

  // ============================================================
  // 🔹 SALVAR EM JSON (SharedPreferences)
  // ============================================================
  Map<String, dynamic> toJson() => {
        'id': id,
        'usuarioId': usuarioId,

        'nome': nome,
        'tipo': tipo,
        'dose': dose,

        'dataHoraAgendamento': dataHoraAgendamento,
        'dataInicio': dataInicio,
        'dataFim': dataFim,

        'isTaken': isTaken,
        'isIgnored': isIgnored,
        'isPendente': isPendente,

        'fotoPath': fotoPath, // ← NOVO
      };

  // ============================================================
  // 🔹 LER DO JSON
  // ============================================================
  static Medicamento fromJson(Map<String, dynamic> json) {
    return Medicamento(
      id: json['id'],
      usuarioId: json['usuarioId'],

      nome: json['nome'] ?? '',
      tipo: json['tipo'] ?? '',
      dose: json['dose'] ?? '',

      dataHoraAgendamento:
          json['dataHoraAgendamento'] ?? DateTime.now().toIso8601String(),
      dataInicio:
          json['dataInicio'] ?? DateTime.now().toIso8601String(),
      dataFim:
          json['dataFim'] ?? DateTime.now().toIso8601String(),

      isTaken: json['isTaken'] ?? false,
      isIgnored: json['isIgnored'] ?? false,
      isPendente: json['isPendente'] ?? false,

      fotoPath: json['fotoPath'], // ← NOVO
    );
  }

  // Helpers
  DateTime get scheduledDateTime {
    return DateTime.parse(dataHoraAgendamento);
  }

  TimeOfDay get scheduledTimeOfDay {
    final dt = DateTime.parse(dataHoraAgendamento);
    return TimeOfDay(hour: dt.hour, minute: dt.minute);
  }
}
