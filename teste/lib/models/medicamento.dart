 import 'package:flutter/material.dart';

// model medicamentos
class Medicamento {
  int? id;
  String nome;
  String tipo;
  String dose;
  String dataHoraAgendamento;
  bool isTaken;
  bool isIgnored;

  Medicamento({
    this.id,
    required this.nome,
    required this.tipo,
    required this.dose,
    required this.dataHoraAgendamento,
    this.isTaken = false,
    this.isIgnored = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'tipo': tipo,
        'dose': dose,
        'dataHoraAgendamento': dataHoraAgendamento,
        'isTaken': isTaken,
        'isIgnored': isIgnored,
        
      };

  static Medicamento fromJson(Map<String, dynamic> json) {
    return Medicamento(
      id: json['id'],
      nome: json['nome'] ?? '',
      tipo: json['tipo'] ?? '',
      dose: json['dose'] ?? '',
      dataHoraAgendamento: json['dataHoraAgendamento'] ??
          DateTime.now().toIso8601String(),
      isTaken: json['isTaken'] ?? false,
      isIgnored: json['isIgnored'] ?? false,
    );
  }

  DateTime get scheduledDateTime {
    return DateTime.parse(dataHoraAgendamento);
  }

  TimeOfDay get scheduledTimeOfDay {
    final dt = DateTime.parse(dataHoraAgendamento);
    return TimeOfDay(hour: dt.hour, minute: dt.minute);
  }
}