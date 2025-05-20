class Ejercicio {
  final String id;
  final String nombre;
  final String gif;
  final String musculo;

  Ejercicio({
    required this.id,
    required this.nombre,
    required this.gif,
    required this.musculo,
  });

  factory Ejercicio.fromMap(String id, Map<String, dynamic> data){
    return Ejercicio(
      id: id, 
      nombre: data['nombre'] ?? '', 
      gif: data['gif'] ?? '',
      musculo: data['musculo'] ?? 'Sin especificar',
    );
  }
}