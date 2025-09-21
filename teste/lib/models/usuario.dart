// lib/models/usuario.dart
import 'package:flutter/material.dart';

enum Sexo { masculino, feminino, outro }

String sexoToString(Sexo s) {
  switch (s) {
    case Sexo.masculino:
      return 'masculino';
    case Sexo.feminino:
      return 'feminino';
    case Sexo.outro:
      return 'outro';
  }
}

Sexo sexoFromString(String? v) {
  switch ((v ?? '').toLowerCase()) {
    case 'masculino':
      return Sexo.masculino;
    case 'feminino':
      return Sexo.feminino;
    default:
      return Sexo.outro;
  }
}

class Usuario {
  final int? id;
  final String nome;
  final String sobrenome;
  final Sexo sexo;
  final String pin; // usado apenas para REMOVER perfil

  const Usuario({
    this.id,
    required this.nome,
    required this.sobrenome,
    required this.sexo,
    required this.pin,
  });

  String get nomeCompleto =>
      (sobrenome.trim().isEmpty) ? nome : '$nome $sobrenome';

  Usuario copyWith({
    int? id,
    String? nome,
    String? sobrenome,
    Sexo? sexo,
    String? pin,
  }) {
    return Usuario(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      sobrenome: sobrenome ?? this.sobrenome,
      sexo: sexo ?? this.sexo,
      pin: pin ?? this.pin,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'sobrenome': sobrenome,
      'sexo': sexoToString(sexo),
      'pin': pin,
    };
  }

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'],
      nome: map['nome'] ?? '',
      sobrenome: map['sobrenome'] ?? '',
      sexo: sexoFromString(map['sexo']),
      pin: map['pin'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'sobrenome': sobrenome,
        'sexo': sexoToString(sexo),
        'pin': pin,
      };

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'],
      nome: json['nome'] ?? '',
      sobrenome: json['sobrenome'] ?? '',
      sexo: sexoFromString(json['sexo']),
      pin: json['pin'] ?? '',
    );
  }
}
