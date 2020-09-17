import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite/tflite.dart';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:async/async.dart';
import 'dart:io';
import 'models.dart';

typedef void Callback(List<dynamic> list, int h, int w);

class Camera extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Callback setRecognitions;
  final String model;

  Camera(this.cameras, this.model, this.setRecognitions);

  @override
  _CameraState createState() => new _CameraState();
}

class _CameraState extends State<Camera> {
  CameraController controller;
  bool isDetecting = false;

  @override
  void initState() {
    super.initState();

    if (widget.cameras == null || widget.cameras.length < 1) {
      print('No camera is found');
    } else {
      controller = new CameraController(
        widget.cameras[1],
        ResolutionPreset.high,
      );
      controller.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {});

        controller.startImageStream((CameraImage img) {
          if (!isDetecting) {
            isDetecting = true;
            int startTime = new DateTime.now().millisecondsSinceEpoch;
            if (widget.model == mobilenet) {
              //Upload();
              Tflite.runModelOnFrame(
                bytesList: img.planes.map((plane) {
                  return plane.bytes;
                }).toList(),
                imageHeight: img.height,
                imageWidth: img.width,
                numResults: 2,
              ).then((recognitions) {
                int endTime = new DateTime.now().millisecondsSinceEpoch;
                print("Detection took ${endTime - startTime}");
                widget.setRecognitions(recognitions, img.height, img.width);
                isDetecting = false;
              });
            }
            // #region old code -> POSE & TINY YOLO
            // else if (widget.model == posenet) {
            //   Tflite.runPoseNetOnFrame(
            //     bytesList: img.planes.map((plane) {
            //       return plane.bytes;
            //     }).toList(),
            //     imageHeight: img.height,
            //     imageWidth: img.width,
            //     numResults: 2,
            //   ).then((recognitions) {
            //     int endTime = new DateTime.now().millisecondsSinceEpoch;
            //     print("Detection took ${endTime - startTime}");

            //     widget.setRecognitions(recognitions, img.height, img.width);

            //     isDetecting = false;
            //   });
            // }
            else {
              Tflite.detectObjectOnFrame(
                bytesList: img.planes.map((plane) {
                  return plane.bytes;
                }).toList(),
                model: widget.model == ssd ? "SSDMobileNet" : "YOLO",
                imageHeight: img.height,
                imageWidth: img.width,
                imageMean: widget.model == ssd ? 0 : 127.5,
                imageStd: widget.model == ssd ? 255.0 : 127.5,
                numResultsPerClass: 1,
                threshold: widget.model == ssd ? 0.2 : 0.4,
              ).then((recognitions) {
                int endTime = new DateTime.now().millisecondsSinceEpoch;
                print("Detection took ${endTime - startTime}");

                widget.setRecognitions(recognitions, img.height, img.width);

                isDetecting = false;
              });
            }
            // #endregion
          }
        });
      });
    }
  }

Future<int> testAPI() async {
    final response = await http.get('https://diemx.vn:6969/api/faceidentity/get-names');
    var a = response.body;
    return response.statusCode;
}
Upload() async { 
    var imageFile = new File('preview.jpg');
    var stream = new http.ByteStream(DelegatingStream.typed(imageFile.openRead()));
      int length = int.parse(imageFile.length().toString());

      var uri = Uri.parse('https://diemx.vn:6969/api/faceidentity/upload-detect');

     var request = new http.MultipartRequest("POST", uri);
      var multipartFile = new http.MultipartFile('file', stream, length,
          filename: basename(imageFile.path));
          //contentType: new MediaType('image', 'png'));

      request.files.add(multipartFile);
      var response = await request.send();
      print(response.statusCode);
}

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller.value.isInitialized) {
      return Container();
    }

    var tmp = MediaQuery.of(context).size;
    var screenH = math.max(tmp.height, tmp.width);
    var screenW = math.min(tmp.height, tmp.width);
    tmp = controller.value.previewSize;
    var previewH = math.max(tmp.height, tmp.width);
    var previewW = math.min(tmp.height, tmp.width);
    var screenRatio = screenH / screenW;
    var previewRatio = previewH / previewW;

    return OverflowBox(
      maxHeight:
          screenRatio > previewRatio ? screenH : screenW / previewW * previewH,
      maxWidth:
          screenRatio > previewRatio ? screenH / previewH * previewW : screenW,
      child: CameraPreview(controller),
    );
  }
}
