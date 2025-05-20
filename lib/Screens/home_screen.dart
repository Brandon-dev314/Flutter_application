import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gisela_app/Screens/cliente_screen.dart';
import 'package:gisela_app/Screens/crear_cliente.dart';
import 'package:gisela_app/Screens/citas_screen.dart';
import 'package:gisela_app/Screens/hacer_rutina_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});  // ← agregado Key

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<String> notifications = [];
  String? _nombreUsuario;
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _loadClientAsNotifications();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
    _loadUserName();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadClientAsNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('clients')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();

    if (!mounted) return;  // ← evita usar context si ya no está en pantalla

    final mensajes = snapshot.docs.map((doc) {
      final nombre = doc['name'] ?? 'Cliente sin registro';
      final ts = (doc['createdAt'] as Timestamp?)?.toDate();
      final fecha = ts != null
          ? "${ts.day}/${ts.month}/${ts.year} ${ts.hour}:${ts.minute.toString().padLeft(2,'0')}"
          : "sin fecha";
      return "Cliente agregado: $nombre\n$fecha";
    }).toList();

    setState(() => notifications = mensajes.reversed.toList());
  }

   Future<void> _loadUserName() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(u.uid)
        .get();
    if (doc.exists) {
      setState(() {
        _nombreUsuario = doc.data()!['name'] as String?;
      });
    }
  }


  void _logoutUser() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  void _showCreateMenu() {  // ← hecho privado
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TweenAnimationBuilder(
              duration: Duration(milliseconds: 500),
              tween: Tween<double>(begin: 0.8, end: 1.0),
              curve: Curves.elasticOut,
              builder: (_, val, child) => Transform.scale(scale: val, child: child),
              child: ListTile(
                leading: Icon(Icons.person_add),
                title: Text("Agregar un cliente"),
                onTap: () async {
                  Navigator.pop(ctx);
                  final email = await Navigator.push<String?>(
                    ctx,
                    MaterialPageRoute(builder: (_) => CreateClientScreen()),
                  );
                  if (email != null) {
                    _loadClientAsNotifications();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Cliente agregado: $email"), backgroundColor: Colors.green),
                    );
                  }
                },
              ),
            ),
            TweenAnimationBuilder(
              duration: Duration(milliseconds: 600),
              tween: Tween<double>(begin: 0.8, end: 1.0),
              curve: Curves.elasticOut,
              builder: (_, val, child) => Transform.scale(scale: val, child: child),
              child: ListTile(
                leading: Icon(Icons.sports_gymnastics),
                title: Text("Crear rutina"),
                onTap: () {
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  Navigator.push(ctx, MaterialPageRoute(builder: (_) => HacerRutinaScreen()));
                },
              ),
            ),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
      final saludo = _nombreUsuario ??
                   FirebaseAuth.instance.currentUser?.email ??
                   'Usuario';
    return Scaffold(
      appBar: AppBar(
        title: Text("Bienvenido, $saludo", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(icon: Icon(Icons.logout), onPressed: _logoutUser),
        ],
      ),
      drawer: Drawer(
        child: ListView(padding: EdgeInsets.zero, children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.purple),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Aplicación Fitness",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(height: 8),
              Text(saludo, style: TextStyle(color: Colors.white)),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: _showCreateMenu,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.purple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text("Crear Programa"),
              ),
            ]),
          ),
          ListTile(leading: Icon(Icons.home), title: Text("Hoy")),
          ListTile(
            leading: Icon(Icons.contacts),
            title: Text("Contactos"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClienteScreen())),
          ),
          ListTile(leading: Icon(Icons.group), title: Text("Grupos")),
          ListTile(leading: Icon(Icons.message), title: Text("Mensajería")),
          ListTile(
            leading: Icon(Icons.calendar_today),
            title: Text("Citas"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AgendaScreen())),
          ),
          Divider(),
          ListTile(leading: Icon(Icons.exit_to_app), title: Text("Cerrar sesión"), onTap: _logoutUser),
        ]),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("¡Bienvenido, $saludo!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
          SizedBox(height: 10),

          // notificaciones
          if (notifications.isNotEmpty)
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (_, i) {
                  return SlideTransition(
                    position: _offsetAnimation,
                    child: Card(
                      color: Colors.purple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: Icon(Icons.person, color: Colors.white),
                        title: Text(notifications[i],
                            style: TextStyle(color: Colors.white)),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.white),
                          onPressed: () => setState(() => notifications.removeAt(i)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          Spacer(),

          // card fija de fondo
          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateClientScreen())),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/gimnasio_fondo.png'),
                    fit: BoxFit.cover,
                  ),
                ),
                alignment: Alignment.center,
                child: Text("¡Agrega un cliente!",
                    style: TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 4)])),
              ),
            ),
          ),
          SizedBox(height: 16),
          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HacerRutinaScreen())),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/fondo_card2.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
                alignment: Alignment.center,
                child: Text("¡Asigna una rutina!",
                    style: TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 4)])),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
