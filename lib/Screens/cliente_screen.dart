import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClienteScreen extends StatelessWidget {
  const ClienteScreen({super.key});

  Future<List<DocumentSnapshot>> _getClientes(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('clients')
        .get();
    return snapshot.docs;
  }

  Future<List<DocumentSnapshot>> _getRutinas(String userId, String clienteId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('clients')
        .doc(clienteId)
        .collection('rutinas')
        .get();
    return snapshot.docs;
  }

  void _editarCliente(BuildContext context, DocumentSnapshot cliente) {
    final email = cliente['email'];
    final TextEditingController alturaController =
        TextEditingController(text: cliente['height'].toString());
    final TextEditingController pesoController =
        TextEditingController(text: cliente['weight'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar cliente: $email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: alturaController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Altura (cm)'),
            ),
            TextField(
              controller: pesoController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Peso (kg)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text('Guardar'),
            onPressed: () async {
              final nuevaAltura = double.tryParse(alturaController.text);
              final nuevoPeso = double.tryParse(pesoController.text);
              if (nuevaAltura != null && nuevoPeso != null) {
                await cliente.reference.update({
                  'height': nuevaAltura,
                  'weight': nuevoPeso,
                });
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Valores inválidos')),
                );
              }
            },
          ),
        ],
      ),
    );
   
  }

  void _editarRutinaDialog(BuildContext context, DocumentSnapshot rutina, String userId, String clienteId) {
    // Implementa tu lógica de edición aquí
     final rutinaData = rutina.data() as Map<String, dynamic>;
    final ejercicios = List<Map<String, dynamic>>.from(rutinaData['ejercicios'] ?? []);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Editar rutina: ${rutinaData['nombre']}"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: ejercicios.length,
              itemBuilder: (context, index) {
                final ejercicio = ejercicios[index];
                final seriesController =
                    TextEditingController(text: (ejercicio['series'] ?? '').toString());
                final repeticionesController =
                    TextEditingController(text: (ejercicio['repeticiones'] ?? '').toString());

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ejercicio['nombre'] ?? '', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextField(
                      decoration: InputDecoration(labelText: 'Series'),
                      keyboardType: TextInputType.number,
                      controller: seriesController,
                      onChanged: (val) {
                        ejercicio['series'] = int.tryParse(val);
                      },
                    ),
                    TextField(
                      decoration: InputDecoration(labelText: 'Repeticiones'),
                      keyboardType: TextInputType.number,
                      controller: repeticionesController,
                      onChanged: (val) {
                        ejercicio['repeticiones'] = int.tryParse(val);
                      },
                    ),
                    Divider(),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('clients')
                    .doc(clienteId)
                    .collection('rutinas')
                    .doc(rutina.id)
                    .update({'ejercicios': ejercicios});
                Navigator.pop(context);
              },
              child: Text("Guardar cambios"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(child: Text("Usuario no autenticado"));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Clientes',),
      ),
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: _getClientes(user.uid),
        builder: (context, snapshotClientes) {
          if (snapshotClientes.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshotClientes.hasData || snapshotClientes.data!.isEmpty) {
            return Center(child: Text("No hay clientes registrados"));
          }
          

          return ListView.builder(
            itemCount: snapshotClientes.data!.length,
            itemBuilder: (context, index) {
              final client = snapshotClientes.data![index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.deepPurple)),
                child: ExpansionTile(
                  leading: Icon(Icons.person, color: Colors.blueAccent),
                  title: Text(
                    client['email'],
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("Altura: ${client['height']} cm | Peso: ${client['weight']} kg"),
                  childrenPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(Icons.edit),
                      label: Text("Editar cliente", style: TextStyle(color: Colors.white)),
                      onPressed: () => _editarCliente(context, client),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                      ),
                    ),
                    FutureBuilder<List<DocumentSnapshot>>(
                      future: _getRutinas(user.uid, client.id),
                      builder: (context, snapshotRutinas) {
                        if (snapshotRutinas.connectionState == ConnectionState.waiting) {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: LinearProgressIndicator(),
                          );
                        }

                        if (!snapshotRutinas.hasData || snapshotRutinas.data!.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text("Sin rutinas asignadas."),
                          );
                        }

                        return Column(
                          children: snapshotRutinas.data!.map((rutinaDoc) {
                            final rutina = rutinaDoc.data() as Map<String, dynamic>;
                            final nombre = rutina['nombre'] ?? '';
                            final ejercicios = List<Map<String, dynamic>>.from(rutina['ejercicios'] ?? []);

                            return Card(
                              color: Colors.grey.shade100,
                              margin: EdgeInsets.symmetric(vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.deepPurple)),
                              child: ListTile(
                                leading: Icon(Icons.fitness_center, color: Colors.deepPurple),
                                title: Text(nombre),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: ejercicios.map((ej) {
                                    return Text(
                                      "${ej['nombre']} - ${ej['series'] ?? '-'}x${ej['repeticiones'] ?? '-'}",
                                      style: TextStyle(fontSize: 13),
                                    );
                                  }).toList(),
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.edit, color: Colors.orange),
                                  onPressed: () => _editarRutinaDialog(
                                    context, rutinaDoc, user.uid, client.id),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
