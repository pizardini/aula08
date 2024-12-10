import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  //Dependência necessária para rodar em Desktop
  if (Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final database = openDatabase(
    join(await getDatabasesPath(), 'petshop.db'),
    onCreate: (db, version) {
      return db.execute(
        'CREATE TABLE caes(id INTEGER PRIMARY KEY, nome TEXT, raca TEXT, idade INTEGER)',
      );
    },
    version: 1,
  );

  runApp(MyApp(database));
}

class MyApp extends StatelessWidget {
  final Future<Database> database;

  MyApp(this.database);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Petshop',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: DogListPage(database),
    );
  }
}

class Cao {
  final int? id;
  final String nome;
  final String raca;
  final int idade;

  Cao({
    this.id, 
    required this.nome, 
    required this.raca, 
    required this.idade
    });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nome': nome,
      'raca': raca,
      'idade': idade,
    };
  }

  @override
  String toString() {
    return 'Dog{id: $id, nome: $nome, raca: $raca, idade: $idade}';
  }
}

class DogListPage extends StatefulWidget {
  final Future<Database> database;

  DogListPage(this.database);

  @override
  _DogListPageState createState() => _DogListPageState();
}

class _DogListPageState extends State<DogListPage> {
  late Future<List<Cao>> dogs;

  @override
  void initState() {
    super.initState();
    dogs = listaCaes();
  }

  Future<void> insereCao(Cao cao) async {
    final db = await widget.database;

    await db.insert(
      'caes',
      cao.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    setState(() {
      dogs = listaCaes();
    });
  }

  Future<List<Cao>> listaCaes() async {
    final db = await widget.database;

    final List<Map<String, dynamic>> maps = await db.query('caes');

    return List.generate(maps.length, (i) {
      return Cao(
        id: maps[i]['id'],
        nome: maps[i]['nome'],
        raca: maps[i]['raca'],
        idade: maps[i]['idade'],
      );
    });
  }

  Future<void> apagaCao(int id) async {
    final db = await widget.database;

    await db.delete(
      'caes',
      where: 'id = ?',
      whereArgs: [id],
    );

    setState(() {
      dogs = listaCaes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lista de Cães'),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Cao>>(
              future: dogs,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Erro: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('Nenhum cão registrado.'));
                } else {
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final dog = snapshot.data![index];
                      return ListTile(
                        title: Text(dog.nome),
                        subtitle: Text('Raça: ${dog.raca}, Idade: ${dog.idade} anos'),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            apagaCao(dog.id!);
                          },
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () async {
                final newDog = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddDogPage(),
                  ),
                );
                if (newDog != null) {
                  insereCao(newDog);
                }
              },
              child: Text('Adicionar Cão'),
            ),
          ),
        ],
      ),
    );
  }
}

class AddDogPage extends StatefulWidget {
  @override
  _AddDogPageState createState() => _AddDogPageState();
}

class _AddDogPageState extends State<AddDogPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _racaController = TextEditingController();
  final _idadeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Adicionar Cão'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: InputDecoration(labelText: 'Nome'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira um nome.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _racaController,
                decoration: InputDecoration(labelText: 'Raça'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira uma raça.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _idadeController,
                decoration: InputDecoration(labelText: 'Idade'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty || int.tryParse(value) == null) {
                    return 'Por favor, insira uma idade válida.';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final dog = Cao(
                      nome: _nomeController.text,
                      raca: _racaController.text,
                      idade: int.parse(_idadeController.text),
                    );
                    Navigator.pop(context, dog);
                  }
                },
                child: Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
