import 'package:cloud_firestore/cloud_firestore.dart';

class Cita {
  String nombre;
  String lugar;
  DateTime fecha;
  String? id;

  Cita({required this.nombre, required this.lugar, required this.fecha, this.id});

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'lugar': lugar,
      'fecha': fecha,
    };
  }

  static Cita fromMap(Map<String, dynamic> map) {
    return Cita(
      nombre: map['nombre'],
      lugar: map['lugar'],
      fecha: (map['fecha'] as Timestamp).toDate(),
    );
  }
}