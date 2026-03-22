import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await requestPermissions();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: CameraScreen(camera: firstCamera),
  ));
}

Future<void> requestPermissions() async {
  bool locationGranted = false;
  LocationPermission locationPermission = await Geolocator.checkPermission();
  if (locationPermission == LocationPermission.denied ||
      locationPermission == LocationPermission.deniedForever) {
    locationPermission = await Geolocator.requestPermission();
  }
  locationGranted = locationPermission == LocationPermission.always ||
      locationPermission == LocationPermission.whileInUse;

  // Permissão de câmera usando permission_handler
  var cameraStatus = await Permission.camera.status;
  if (!cameraStatus.isGranted) {
    cameraStatus = await Permission.camera.request();
  }

  if (!locationGranted || !cameraStatus.isGranted) {
    throw Exception('Permissões necessárias não concedidas');
  }
}

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;
  const CameraScreen({Key? key, required this.camera}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  List<Map<String, dynamic>> photos = [];

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.high);
    _initializeControllerFuture = _controller.initialize();
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;

      // Pega a localização no momento da foto
      Position position = await Geolocator.getCurrentPosition();

      final image = await _controller.takePicture();

      setState(() {
        photos.add({
          'path': image.path,
          'lat': position.latitude,
          'lon': position.longitude,
          'time': DateTime.now().toString().substring(11, 19),
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Foto salva com localização!')),
      );
    } catch (e) {
      print('Erro ao tirar foto: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao tirar foto: $e')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return Container(
                  width: double.infinity,
                  height: double.infinity,
                  child: CameraPreview(_controller),
                );
              } else {
                return Center(child: CircularProgressIndicator());
              }
            },
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton.extended(
                  heroTag: "btn1",
                  onPressed: _takePicture,
                  label: Text("Tirar Foto"),
                  icon: Icon(Icons.camera_alt),
                  backgroundColor: Colors.redAccent,
                ),
                FloatingActionButton.extended(
                  heroTag: "btn2",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => GalleryScreen(photos: photos)),
                    );
                  },
                  label: Text("Ver Fotos"),
                  icon: Icon(Icons.photo_library),
                  backgroundColor: Colors.blueAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GalleryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> photos;
  const GalleryScreen({Key? key, required this.photos}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Galeria com GPS"),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey[900],
      body: photos.isEmpty
          ? Center(
              child: Text("Nenhuma foto tirada",
                  style: TextStyle(color: Colors.white)))
          : ListView.builder(
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final item = photos[index];
                return Card(
                  color: Colors.black54,
                  margin: EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Image.file(File(item['path'])),
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          "Local: ${item['lat'].toStringAsFixed(4)}, ${item['lon'].toStringAsFixed(4)}\nHora: ${item['time']}",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}