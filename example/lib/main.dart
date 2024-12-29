import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_face_api/flutter_face_api.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() => runApp(MaterialApp(home: MyApp()));

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  var faceSdk = FaceSDK.instance;

  var _status = "nil";
  var _similarityStatus = "nil";
  var _livenessStatus = "nil";
  var _uiImage1 = Image.asset('assets/images/portrait.png');
  var _uiImage2 = Image.asset('assets/images/portrait.png');

  set status(String val) => setState(() => _status = val);
  set similarityStatus(String val) => setState(() => _similarityStatus = val);
  set livenessStatus(String val) => setState(() => _livenessStatus = val);
  set uiImage1(Image val) => setState(() => _uiImage1 = val);
  set uiImage2(Image val) => setState(() => _uiImage2 = val);

  MatchFacesImage? mfImage1;
  MatchFacesImage? mfImage2;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    init();
  }

  void init() async {
    if (!await initialize()) return;
    status = "Ready";
  }

  Future<bool> initialize() async {
    status = "Initializing...";
    var license = await loadAssetIfExists("assets/regula.license");
    InitConfig? config;
    if (license != null) config = InitConfig(license);
    var (success, error) = await faceSdk.initialize(config: config);
    if (!success) {
      status = error!.message;
      print("${error.code}: ${error.message}");
    }
    return success;
  }

  Future<ByteData?> loadAssetIfExists(String path) async {
    try {
      return await rootBundle.load(path);
    } catch (_) {
      return null;
    }
  }

  Future<void> setImageFromUrl(String url, int number) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final imageBytes = response.bodyBytes; // Get image data as Uint8List
        setImage(imageBytes, ImageType.PRINTED, number); // Update the UI
      } else {
        status = "Failed to load image from URL!";
      }
    } catch (e) {
      status = "Error: $e";
    }
  }

  setImage(Uint8List bytes, ImageType type, int number) {
    similarityStatus = "nil";
    var mfImage = MatchFacesImage(bytes, type);
    if (number == 1) {
      mfImage1 = mfImage;
      uiImage1 = Image.memory(bytes);
      livenessStatus = "nil";
    }
    if (number == 2) {
      mfImage2 = mfImage;
      uiImage2 = Image.memory(bytes);
    }
  }

  Widget image(Image image, Function() onTap) => GestureDetector(
    onTap: onTap,
    child: Image(height: 150, width: 150, image: image.image),
  );

  Widget button(String text, Function() onPressed) {
    return Container(
      child: textButton(text, onPressed,
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all<Color>(Colors.black12),
          )),
      width: 250,
    );
  }

  Widget text(String text) => Text(text, style: TextStyle(fontSize: 18));

  Widget textButton(String text, Function() onPressed, {ButtonStyle? style}) =>
      TextButton(
        child: Text(text),
        onPressed: onPressed,
        style: style,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Center(child: Text(_status))),
      body: Container(
        margin: EdgeInsets.fromLTRB(0, 0, 0, MediaQuery.of(context).size.height / 8),
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            image(_uiImage1, () => setImageFromUrl("https://avatars.githubusercontent.com/u/62563665?v=4", 1)),
            image(_uiImage2, () => getImageFromCamera()),
            Container(margin: EdgeInsets.fromLTRB(0, 0, 0, 15)),
            button("Match", () => matchFaces()),
            button("Clear", () => clearResults()),
            Container(margin: EdgeInsets.fromLTRB(0, 15, 0, 0)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                text("Similarity: " + _similarityStatus),
                Container(margin: EdgeInsets.fromLTRB(20, 0, 0, 0)),
                text("Liveness: " + _livenessStatus)
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<void> getImageFromCamera() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setImage(bytes, ImageType.LIVE, 2);
    }
  }

  Future<void> matchFaces() async {
    if (mfImage1 == null || mfImage2 == null) {
      status = "Both images required!";
      return;
    }
    status = "Processing...";
    var request = MatchFacesRequest([mfImage1!, mfImage2!]);
    var response = await faceSdk.matchFaces(request);
    var split = await faceSdk.splitComparedFaces(response.results, 0.75);
    var match = split.matchedFaces;
    similarityStatus = "failed";
    if (match.isNotEmpty) {
      similarityStatus = (match[0].similarity * 100).toStringAsFixed(2) + "%";
    }
    status = "Ready";
  }

  void clearResults() {
    status = "Ready";
    similarityStatus = "nil";
    livenessStatus = "nil";
    uiImage2 = Image.asset('assets/images/portrait.png');
    uiImage1 = Image.asset('assets/images/portrait.png');
    mfImage1 = null;
    mfImage2 = null;
  }
}
