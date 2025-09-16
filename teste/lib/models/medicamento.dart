import 'package:flutter/material.dart';

class Medicamento {
  int? id;
  String nome;
  String tipo;
  String dose;
  String dataHoraAgendamento;
  String dataInicio; // NOVO
  String dataFim;    // NOVO
  bool isTaken;
  bool isIgnored;
  bool isPendente;

  Medicamento({
    this.id,
    required this.nome,
    required this.tipo,
    required this.dose,
    required this.dataHoraAgendamento,
    required this.dataInicio, // NOVO
    required this.dataFim,    // NOVO
    this.isTaken = false,
    this.isIgnored = false,
    this.isPendente = false,
  });

  // 🔹 Para salvar no SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'tipo': tipo,
      'dose': dose,
      'dataHoraAgendamento': dataHoraAgendamento,
      'dataInicio': dataInicio, // NOVO
      'dataFim': dataFim,       // NOVO
      'isTaken': isTaken ? 1 : 0,
      'isIgnored': isIgnored ? 1 : 0,
      'isPendente': isPendente ? 1 : 0,
    };
  }

  // 🔹 Para ler do SQLite
  factory Medicamento.fromMap(Map<String, dynamic> map) {
    return Medicamento(
      id: map['id'],
      nome: map['nome'] ?? '',
      tipo: map['tipo'] ?? '',
      dose: map['dose'] ?? '',
      dataHoraAgendamento:
          map['dataHoraAgendamento'] ?? DateTime.now().toIso8601String(),
      dataInicio: map['dataInicio'] ?? DateTime.now().toIso8601String(),
      dataFim: map['dataFim'] ?? DateTime.now().toIso8601String(),
      isTaken: (map['isTaken'] ?? 0) == 1,
      isIgnored: (map['isIgnored'] ?? 0) == 1,
      isPendente: (map['isPendente'] ?? 0) == 1,
    );
  }

  // 🔹 Para salvar no SharedPreferences (mantido)
  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'tipo': tipo,
        'dose': dose,
        'dataHoraAgendamento': dataHoraAgendamento,
        'dataInicio': dataInicio, // NOVO
        'dataFim': dataFim,       // NOVO
        'isTaken': isTaken,
        'isIgnored': isIgnored,
        'isPendente': isPendente,
      };

  static Medicamento fromJson(Map<String, dynamic> json) {
    return Medicamento(
      id: json['id'],
      nome: json['nome'] ?? '',
      tipo: json['tipo'] ?? '',
      dose: json['dose'] ?? '',
      dataHoraAgendamento:
          json['dataHoraAgendamento'] ?? DateTime.now().toIso8601String(),
      dataInicio: json['dataInicio'] ?? DateTime.now().toIso8601String(),
      dataFim: json['dataFim'] ?? DateTime.now().toIso8601String(),
      isTaken: json['isTaken'] ?? false,
      isIgnored: json['isIgnored'] ?? false,
      isPendente: json['isPendente'] ?? false,
    );
  }

  // 🔹 Helpers
  DateTime get scheduledDateTime {
    return DateTime.parse(dataHoraAgendamento);
  }

  TimeOfDay get scheduledTimeOfDay {
    final dt = DateTime.parse(dataHoraAgendamento);
    return TimeOfDay(hour: dt.hour, minute: dt.minute);
  }
}
