import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gisela_app/api/google_sign_in_api.dart';
import 'package:gisela_app/models/ejercicio.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;

class HacerRutinaScreen extends StatefulWidget {
  const HacerRutinaScreen({Key? key}) : super(key: key);

  @override
  _HacerRutinaScreenState createState() => _HacerRutinaScreenState();
}

class _HacerRutinaScreenState extends State<HacerRutinaScreen> {
  List<Ejercicio> _ejercicios = [];
  List<Ejercicio> _ejerciciosFiltrados = [];
  final List<RutinaTemporal> _rutinasTemporales = [];
  bool _seleccionandoEjercicios = true;

  // filtros
  final List<String> _gruposMusculares = [
    'Todos',
    'Pecho',
    'Espalda',
    'Pierna',
    'Bíceps',
    'Tríceps',
    'Hombros',
    'Abdomen'
  ];
  String _grupoSeleccionado = 'Todos';

  // clientes
  List<Map<String, String>> _misClientes = [];
  String? _clienteSeleccionadoEmail;

  // progreso envío
  final ValueNotifier<double> _sendProgress = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _cargarEjercicios();
    _cargarClientes();
    _agregarRutinaNueva(); // Inicia con una rutina ya creada
  }

  @override
  void dispose() {
    _sendProgress.dispose();
    super.dispose();
  }

  Future<void> _cargarEjercicios() async {
    final snap = await FirebaseFirestore.instance.collection('ejercicios').get();
    final list = snap.docs.map((d) => Ejercicio.fromMap(d.id, d.data())).toList();
    setState(() {
      _ejercicios = list;
      _ejerciciosFiltrados = list;
    });
  }

  Future<void> _cargarClientes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('clients')
        .get();
    setState(() {
      _misClientes = snap.docs
          .map((d) => {
                'name': d['name'] as String,
                'email': d['email'] as String,
              })
          .toList();
    });
  }

  void _filtrar(String query) {
    final porGrupo = _grupoSeleccionado == 'Todos'
        ? _ejercicios
        : _ejercicios.where((e) => e.musculo == _grupoSeleccionado).toList();
    setState(() {
      _ejerciciosFiltrados = porGrupo
          .where((e) => e.nombre.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _aplicarFiltroGrupoMuscular() {
    setState(() {
      if (_grupoSeleccionado == 'Todos') {
        _ejerciciosFiltrados = _ejercicios;
      } else {
        _ejerciciosFiltrados =
            _ejercicios.where((e) => e.musculo == _grupoSeleccionado).toList();
      }
    });
  }

  void _agregarRutinaNueva() {
    setState(() {
      _rutinasTemporales.add(RutinaTemporal(
        nombre: '',
        ejercicios: {},
        seleccionados: {},
        nombreController: TextEditingController(),
        duracionController: TextEditingController(),
        camposControllers: {},
      ));
      _seleccionandoEjercicios = true;
    });
  }

  Future<void> _generarYEnviarPDF() async {
    if (_clienteSeleccionadoEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Selecciona primero un cliente")),
      );
      return;
    }
    final correoDestino = _clienteSeleccionadoEmail!;

    try {
      _sendProgress.value = 0;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: Text("Enviando rutina..."),
          content: ValueListenableBuilder<double>(
            valueListenable: _sendProgress,
            builder: (_, progreso, __) {
              final pct = (progreso * 100).clamp(0, 100).toInt();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: progreso),
                  SizedBox(height: 8),
                  Text("$pct %"),
                ],
              );
            },
          ),
        ),
      );

      final pdf = pw.Document();
      final total = _rutinasTemporales.length;
      for (int i = 0; i < total; i++) {
        final rutina = _rutinasTemporales[i];
        final widgets = await Future.wait(rutina.ejercicios.entries.map((entry) async {
          final datos = entry.value;
          pw.Widget? imgWid;
          final url = datos['gif'] ?? '';
          if (url.isNotEmpty) {
            try {
              final resp = await http.get(Uri.parse(url));
              if (resp.statusCode == 200) {
                imgWid = pw.Image(pw.MemoryImage(resp.bodyBytes), width: 150, height: 150);
              }
            } catch (_) {}
          }
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('• ${datos['nombre']}'),
              pw.Text('  - Series: ${datos['series']}'),
              pw.Text('  - Repeticiones: ${datos['repeticiones']}'),
              pw.Text('  - Duración: ${datos['duracion'] ?? '-'} min'),
              pw.Text('  - Comentario: ${datos['comentario'] ?? ''}'),
              pw.SizedBox(height: 5),
              if (imgWid != null) imgWid,
              pw.SizedBox(height: 10),
            ],
          );
        }));

        pdf.addPage(
          pw.Page(
            build: (_) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Rutina: ${rutina.nombre}', style: pw.TextStyle(fontSize: 20)),
                pw.SizedBox(height: 10),
                pw.Text('Duración (semanas): ${rutina.duracionSemanas ?? ''}'),
                pw.SizedBox(height: 10),
                ...widgets,
              ],
            ),
          ),
        );

        _sendProgress.value = (i + 1) / (total + 1);
      }

      final bytes = await pdf.save();
      _sendProgress.value = total / (total + 1);

      final userGoogle = await GoogleAuthApi.signIn();
      if (userGoogle == null) throw Exception("No autorizado");
      final token = (await userGoogle.authentication).accessToken!;
      final email = userGoogle.email;
      GoogleAuthApi.signOut();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/rutina.pdf')..writeAsBytesSync(bytes);

      final smtp = gmailSaslXoauth2(email, token);
      final msg = Message()
        ..from = Address(email, 'Tu Nombre')
        ..recipients.add(correoDestino)
        ..subject = 'Tu rutina personalizada'
        ..text = 'Adjunto tu rutina de la semana en PDF'
        ..attachments = [FileAttachment(file)..fileName = 'rutina.pdf'];

      await send(msg, smtp);

      _sendProgress.value = 1.0;
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rutina enviada 👍')),
      );
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar: $e ❌')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ultima = _rutinasTemporales.isNotEmpty ? _rutinasTemporales.last : null;

    return Scaffold(
      appBar: AppBar(title: Text("Crear Rutina")),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            if (_seleccionandoEjercicios) ...[
              TextField(
                decoration: InputDecoration(labelText: "Buscar ejercicio", prefixIcon: Icon(Icons.search)),
                onChanged: _filtrar,
              ),
              DropdownButton<String>(
                isExpanded: true,
                value: _grupoSeleccionado,
                items: _gruposMusculares
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (g) => setState(() {
                  _grupoSeleccionado = g!;
                  _aplicarFiltroGrupoMuscular();
                }),
              ),
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.all(10),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, childAspectRatio: 0.85, crossAxisSpacing: 10, mainAxisSpacing: 10),
                  itemCount: _ejerciciosFiltrados.length,
                  itemBuilder: (_, i) {
                    final ej = _ejerciciosFiltrados[i];
                    final sel = ultima?.seleccionados.contains(ej) ?? false;
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (sel) {
                          ultima?.seleccionados.remove(ej);
                          ultima?.ejercicios.remove(ej.id);
                          ultima?.camposControllers.remove(ej.id);
                        } else {
                          ultima?.seleccionados.add(ej);
                          ultima?.camposControllers[ej.id] = {
                            'series': TextEditingController(),
                            'repeticiones': TextEditingController(),
                            'duracion': TextEditingController(),
                            'comentario': TextEditingController(),
                          };
                        }
                      }),
                      child: Card(
                        shape: RoundedRectangleBorder(
                            side: BorderSide(color: sel ? Colors.orange : Colors.grey.shade300, width: 2),
                            borderRadius: BorderRadius.circular(10)),
                        child: Column(children: [
                          Expanded(child: Image.network(ej.gif, fit: BoxFit.cover)),
                          Padding(padding: EdgeInsets.all(6), child: Text(ej.nombre, textAlign: TextAlign.center)),
                        ]),
                      ),
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: (ultima?.seleccionados.isNotEmpty ?? false) ? () => setState(() => _seleccionandoEjercicios = false) : null,
                child: Text("Configurar rutina"),
              ),
            ] else ...[
              if (_misClientes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: "Cliente a enviar"),
                    value: _clienteSeleccionadoEmail,
                    items: _misClientes
                        .map((c) => DropdownMenuItem(value: c['email'], child: Text(c['name']!)))
                        .toList(),
                    onChanged: (email) => setState(() => _clienteSeleccionadoEmail = email),
                  ),
                ),
              Expanded(
                child: ListView(
                  children: _rutinasTemporales.asMap().entries.map((e) {
                    final idx = e.key;
                    final r = e.value;
                    return ExpansionTile(
                      title: Text(r.nombre.isEmpty ? "Nueva Rutina ${idx + 1}" : r.nombre),
                      initiallyExpanded: idx == _rutinasTemporales.length - 1,
                      children: [
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: TextField(
                            controller: r.nombreController,
                            decoration: InputDecoration(labelText: "Nombre"),
                            onChanged: (v) => r.nombre = v,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: TextField(
                            controller: r.duracionController,
                            decoration: InputDecoration(labelText: "Duración (semanas)"),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => r.duracionSemanas = int.tryParse(v),
                          ),
                        ),
                        ...r.seleccionados.map((ej) {
                          final ctrs = r.camposControllers[ej.id]!;
                          return Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ej.nombre, style: TextStyle(fontWeight: FontWeight.bold)),
                                TextField(
                                  controller: ctrs['series'],
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(labelText: "Series"),
                                  onChanged: (v) {
                                    r.ejercicios[ej.id] ??= {'nombre': ej.nombre, 'gif': ej.gif};
                                    r.ejercicios[ej.id]!['series'] = int.tryParse(v);
                                  },
                                ),
                                TextField(
                                  controller: ctrs['repeticiones'],
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(labelText: "Repeticiones"),
                                  onChanged: (v) {
                                    r.ejercicios[ej.id]!['repeticiones'] = int.tryParse(v);
                                  },
                                ),
                                TextField(
                                  controller: ctrs['duracion'],
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(labelText: "Duración (minutos)"),
                                  onChanged: (v) {
                                    r.ejercicios[ej.id]!['duracion'] = int.tryParse(v);
                                  },
                                ),
                                TextField(
                                  controller: ctrs['comentario'],
                                  decoration: InputDecoration(labelText: "Comentario"),
                                  onChanged: (v) {
                                    r.ejercicios[ej.id]!['comentario'] = v;
                                  },
                                ),
                                Divider(),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    );
                  }).toList(),
                ),
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: Text("Añadir más rutinas"),
                onPressed: _agregarRutinaNueva,
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.send),
                label: Text("Enviar por correo"),
                onPressed: _generarYEnviarPDF,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RutinaTemporal {
  String nombre;
  int? duracionSemanas;
  final Map<String, Map<String, dynamic>> ejercicios;
  final Set<Ejercicio> seleccionados;
  final TextEditingController nombreController;
  final TextEditingController duracionController;
  final Map<String, Map<String, TextEditingController>> camposControllers;

  RutinaTemporal({
    required this.nombre,
    this.duracionSemanas,
    required this.ejercicios,
    required this.seleccionados,
    required this.nombreController,
    required this.duracionController,
    required this.camposControllers,
  });
}
