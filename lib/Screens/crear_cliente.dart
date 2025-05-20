import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateClientScreen extends StatefulWidget {
  const CreateClientScreen({super.key});

  @override
  _CreateClientScreenState createState() => _CreateClientScreenState();
}

class _CreateClientScreenState extends State<CreateClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController firstName = TextEditingController();
  final TextEditingController lastName = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  String gender = 'Masculino';
  bool isLoading = false;

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.deepPurple, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.deepPurple, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.deepPurple, width: 2.5),
      ),
    );
  }

  Future<void> saveClient() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        isLoading = true;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Usuario no autenticado."), backgroundColor: Colors.red),
        );
        setState(() {
          isLoading = false;
        });
        return;
      }

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('clients')
            .add({
          'name': firstName.text,
          'lastname': lastName.text,
          'email': emailController.text,
          'age': int.tryParse(ageController.text) ?? 0,
          'gender': gender,
          'weight': double.tryParse(weightController.text) ?? 0,
          'height': double.tryParse(heightController.text) ?? 0,
          'createdAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Cliente guardado exitosamente"),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, emailController.text);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al guardar el cliente"),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Crear Cliente")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: firstName,
                decoration: _buildInputDecoration("Nombre"),
                keyboardType: TextInputType.name,
                validator: (value) => value!.isEmpty ? "Ingrese su nombre" : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: lastName,
                decoration: _buildInputDecoration("Apellido completo"),
                keyboardType: TextInputType.name,
                validator: (value) => value!.isEmpty ? "Ingrese su apellido" : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: emailController,
                decoration: _buildInputDecoration("Correo"),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value!.isEmpty ? "Ingrese un correo válido" : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: ageController,
                decoration: _buildInputDecoration("Edad"),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? "Ingrese su edad" : null,
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: gender,
                decoration: _buildInputDecoration("Género"),
                items: ["Masculino", "Femenino", "Otro"].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    gender = newValue!;
                  });
                },
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: weightController,
                decoration: _buildInputDecoration("Peso (kg)"),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? "Ingrese su peso" : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: heightController,
                decoration: _buildInputDecoration("Estatura (cm)"),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? "Ingrese su estatura" : null,
              ),
              SizedBox(height: 20),
              isLoading
                  ? Center(child: CircularProgressIndicator(color: Colors.deepPurple))
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: saveClient,
                      child: Text(
                        "Guardar Cliente",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
