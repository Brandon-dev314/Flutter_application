import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  _AgendaScreenState createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _notaController = TextEditingController();
  TimeOfDay? _horaInicio;
  DateTime? _fecha;
  Color? _colorSeleccionado;

  final Map<String, Color> _coloresDisponibles = {
    'Púrpura': Colors.purple,
    'Naranja': Colors.orange
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Agenda')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tareas')
                  .orderBy('fecha')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final tareas = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: tareas.length,
                  itemBuilder: (context, index) {
                    final tarea = tareas[index];
                    final fecha = DateFormat('dd/MM/yyyy')
                        .format(DateTime.parse(tarea['fecha']));
                    final hora = tarea['horaInicio'];
                    final notificar = tarea['notificar'] ?? false;
                    return Card(
                      color: _colorDesdeHex(tarea['color']),
                      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: ListTile(
                        title: Text(tarea['titulo']),
                        subtitle: Text(
                            'Fecha: $fecha\nHora: $hora\n${tarea['nota']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.black87),
                              onPressed: () {
                                _mostrarDialogoEditar(tarea);
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await FirebaseFirestore.instance
                                    .collection('tareas')
                                    .doc(tarea.id)
                                    .delete();
                                _cancelarNotificacion(tarea.id);
                              },
                            ),
                            Switch(
                              value: notificar,
                              onChanged: (value) async {
                                await FirebaseFirestore.instance
                                    .collection('tareas')
                                    .doc(tarea.id)
                                    .update({'notificar': value});

                                final fechaDate =
                                    DateTime.parse(tarea['fecha']);
                                final horaObj =
                                    _parseTimeOfDay(tarea['horaInicio']);
                                final fechaHora = DateTime(
                                  fechaDate.year,
                                  fechaDate.month,
                                  fechaDate.day,
                                  horaObj.hour,
                                  horaObj.minute,
                                );

                                if (value) {
                                  _programarNotificacion(
                                    id: tarea.id,
                                    titulo: tarea['titulo'],
                                    cuerpo: tarea['nota'],
                                    fechaHora: fechaHora,
                                  );
                                } else {
                                  _cancelarNotificacion(tarea.id);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _formularioTarea(),
        ],
      ),
    );
  }

  Widget _formularioTarea() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _tituloController,
              decoration: InputDecoration(labelText: 'Título'),
              validator: (value) =>
                  value!.isEmpty ? 'Ingresa un título' : null,
            ),
            TextFormField(
              controller: _notaController,
              decoration: InputDecoration(labelText: 'Nota'),
            ),
            Row(
              children: [
                Text(_fecha == null
                    ? 'Fecha no seleccionada'
                    : DateFormat('dd/MM/yyyy').format(_fecha!)),
                Spacer(),
                ElevatedButton(
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _fecha = picked);
                    }
                  },
                  child: Text('Seleccionar Fecha'),
                ),
              ],
            ),
            Row(
              children: [
                Text(_horaInicio == null
                    ? 'Hora no seleccionada'
                    : _horaInicio!.format(context)),
                Spacer(),
                ElevatedButton(
                  onPressed: () async {
                    TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (picked != null) {
                      setState(() => _horaInicio = picked);
                    }
                  },
                  child: Text('Seleccionar Hora'),
                ),
              ],
            ),
            DropdownButtonFormField<Color>(
              value: _colorSeleccionado,
              hint: Text('Seleccionar Color'),
              onChanged: (color) => setState(() => _colorSeleccionado = color),
              items: _coloresDisponibles.entries.map((entry) {
                return DropdownMenuItem<Color>(
                  value: entry.value,
                  child: Row(
                    children: [
                      Container(
                          width: 20,
                          height: 20,
                          color: entry.value,
                          margin: EdgeInsets.only(right: 8)),
                      Text(entry.key),
                    ],
                  ),
                );
              }).toList(),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate() &&
                    _fecha != null &&
                    _horaInicio != null &&
                    _colorSeleccionado != null) {
                  final horaStr = _horaInicio!.format(context);
                  final colorHex =
                      '#${_colorSeleccionado!.toARGB32().toRadixString(16).padLeft(8, '0')}';
                  final nuevaTarea = {
                    'titulo': _tituloController.text,
                    'nota': _notaController.text,
                    'fecha': _fecha!.toIso8601String(),
                    'horaInicio': horaStr,
                    'notificar': false,
                    'color': colorHex,
                  };

                  await FirebaseFirestore.instance
                      .collection('tareas')
                      .add(nuevaTarea);

                  _tituloController.clear();
                  _notaController.clear();
                  setState(() {
                    _fecha = null;
                    _horaInicio = null;
                    _colorSeleccionado = null;
                  });
                }
              },
              child: Text('Agregar Tarea'),
            )
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoEditar(QueryDocumentSnapshot tarea) {
    final TextEditingController tituloController =
        TextEditingController(text: tarea['titulo']);
    final TextEditingController notaController =
        TextEditingController(text: tarea['nota']);
    DateTime fecha = DateTime.parse(tarea['fecha']);
    TimeOfDay hora = _parseTimeOfDay(tarea['horaInicio']);

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Editar Tarea'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextFormField(
                    controller: tituloController,
                    decoration: InputDecoration(labelText: 'Título'),
                  ),
                  TextFormField(
                    controller: notaController,
                    decoration: InputDecoration(labelText: 'Nota'),
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Text(DateFormat('dd/MM/yyyy').format(fecha)),
                      Spacer(),
                      ElevatedButton(
                        onPressed: () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: fecha,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => fecha = picked);
                          }
                        },
                        child: Text('Cambiar Fecha'),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(hora.format(context)),
                      Spacer(),
                      ElevatedButton(
                        onPressed: () async {
                          TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: hora,
                          );
                          if (picked != null) {
                            setState(() => hora = picked);
                          }
                        },
                        child: Text('Cambiar Hora'),
                      ),
                    ],
                  ),
                  DropdownButton<Color>(
                    value: _colorSeleccionado,
                    hint: Text('Color'),
                    onChanged: (color) =>
                        setState(() => _colorSeleccionado = color),
                    items: _coloresDisponibles.entries.map((entry) {
                      return DropdownMenuItem<Color>(
                        value: entry.value,
                        child: Row(
                          children: [
                            Container(
                                width: 20,
                                height: 20,
                                color: entry.value,
                                margin: EdgeInsets.only(right: 8)),
                            Text(entry.key),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final colorHex =
                      '#${_colorSeleccionado!.toARGB32().toRadixString(16).padLeft(8, '0')}';
                  await FirebaseFirestore.instance
                      .collection('tareas')
                      .doc(tarea.id)
                      .update({
                    'titulo': tituloController.text,
                    'nota': notaController.text,
                    'fecha': fecha.toIso8601String(),
                    'horaInicio': hora.format(context),
                    'color': colorHex,
                  });
                  Navigator.pop(context);
                },
                child: Text('Guardar'),
                  ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Cancelar'),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _colorDesdeHex(String hexColor) {
  hexColor = hexColor.replaceAll('#', '');
  if (hexColor.length == 6) {
    hexColor = 'FF$hexColor'; // añade opacidad completa si no está
  }
  return Color(int.parse(hexColor, radix: 16));
}

  TimeOfDay _parseTimeOfDay(String input) {
    final cleaned = input.replaceAll(RegExp(r'[\u00A0\u202F]'), ' ').trim();
    final regex = RegExp(r'(\d{1,2}):(\d{2})\s*([AaPp][Mm])');
    final match = regex.firstMatch(cleaned);
    if (match == null) {
      throw FormatException('Formato de hora no válido: "$input"');
    }
    int hour = int.parse(match.group(1)!);
    int minute = int.parse(match.group(2)!);
    final period = match.group(3)!.toLowerCase();
    if (period == 'pm' && hour != 12) hour += 12;
    if (period == 'am' && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  }


  void _programarNotificacion({
    required String id,
    required String titulo,
    required String cuerpo,
    required DateTime fechaHora,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id.hashCode,
        channelKey: 'tareas_channel',
        title: titulo,
        body: cuerpo,
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar(
        year: fechaHora.year,
        month: fechaHora.month,
        day: fechaHora.day,
        hour: fechaHora.hour,
        minute: fechaHora.minute,
        second: 0,
        millisecond: 0,
        preciseAlarm: true,
      ),
    );
  }

  void _cancelarNotificacion(String id) async {
    await AwesomeNotifications().cancel(id.hashCode);
  }
}
