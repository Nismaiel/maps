import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' show cos, sqrt, asin;

class MapView extends StatefulWidget {
  @override
  _MapViewState createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  CameraPosition _cameraPosition = CameraPosition(target: LatLng(0.0, 0.0));
  GoogleMapController mapController;
  final Geolocator _geolocator = Geolocator();
  final startAddressController = TextEditingController();
  final destinationAddressController = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  Position _currentPosition;
  String _currentAddress;
  String _startAddress;
  String _destinationAddress;
  String _placeDistance;
  Set<Marker> markers = {};
  PolylinePoints _polylinePoints;
  List<LatLng> polylineCoordinates = [];
  Map<PolylineId, Polyline> polylines = {};

  _getAddress() async {
    try {
      List<Placemark> p = await _geolocator.placemarkFromCoordinates(
          _currentPosition.latitude, _currentPosition.longitude);

      Placemark place = p[0];

      setState(() {
        _currentAddress =
            "${place.name}, ${place.locality}, ${place.postalCode}, ${place.country}";
        startAddressController.text = _currentAddress;
        _startAddress = _currentAddress;
      });
    } catch (e) {
      print(e);
    }
  }

  _getCurrentLocation() async {
    await _geolocator
        .getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
        .then((Position position) async {
      setState(() {
        _currentPosition = position;
        print('position:$_currentPosition');
        mapController.animateCamera(CameraUpdate.newCameraPosition(
            CameraPosition(
                target: LatLng(position.latitude, position.longitude),
                zoom: 18.0)));
        markers.add(Marker(
            markerId: MarkerId(position.toString()),
            draggable: true,
            position: LatLng(position.latitude, position.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen)));
      });

      await _getAddress();
    }).catchError((e) {
      print(e);
    });
  }

  // Method for calculating the distance between two places

//  double _coordinateDistance(lat1, lon1, lat2, lon2) {
//    var p = 0.017453292519943295;
//    var c = cos;
//    var a = 0.5 -
//        c((lat2 - lat1) * p) / 2 +
//        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
//    return 12742 * asin(sqrt(a));
//  }

  Widget _textField({
    TextEditingController controller,
    String label,
    String hint,
    double width,
    Icon prefixIcon,
    Widget suffixIcon,
    Function(String) locationCallback,
  }) {
    return Container(
      width: width * 0.8,
      child: TextField(
        onChanged: (value) {
          locationCallback(value);
        },
        controller: controller,
        decoration: new InputDecoration(
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(10.0),
            ),
            borderSide: BorderSide(
              color: Colors.grey[400],
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(10.0),
            ),
            borderSide: BorderSide(
              color: Colors.blue[300],
              width: 2,
            ),
          ),
          contentPadding: EdgeInsets.all(15),
          hintText: hint,
        ),
      ),
    );
  }

  _handleMarkers(LatLng tappedPoint) {
    setState(() {

      markers.add(Marker(
          markerId: MarkerId(tappedPoint.toString()),
          position: tappedPoint,
          onTap: () {
          },
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          draggable: true));
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.height,
      child: Scaffold(
        key: _scaffoldKey,
        body: Stack(
          children: [
            GoogleMap(
              onTap: _handleMarkers,
              markers: markers != null ? Set<Marker>.from(markers) : null,
              polylines: Set<Polyline>.of(polylines.values),
              initialCameraPosition: _cameraPosition,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              mapType: MapType.normal,
              zoomGesturesEnabled: true,
              zoomControlsEnabled: true,
              onMapCreated: (GoogleMapController controller) {
                mapController = controller;
              },
            ),
            Positioned(
              bottom: 110,
              right: 5,
              child: ClipOval(
                child: Material(
                  color: Colors.orange[100],
                  child: InkWell(
                    splashColor: Colors.orange,
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(Icons.my_location),
                    ),
                    onTap: () {
                      mapController.animateCamera(
                          CameraUpdate.newCameraPosition(CameraPosition(
                              target: LatLng(_currentPosition.latitude,
                                  _currentPosition.longitude),
                              zoom: 18)));
                    },
                  ),
                ),
              ),
            ),
            Positioned(
                top: 30,
                right: 20,
                left: 20,
                child: Container(
                  height: 300,
                  child: Column(
                    children: [
                      Text('Places'),
                      Container(
                        width: MediaQuery.of(context).size.width / 1.2,
                        height: 60,
                        child: _textField(
                            label: 'Start',
                            hint: 'Choose starting point',
                            prefixIcon: Icon(Icons.looks_one),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.my_location),
                              onPressed: () {
                                startAddressController.text = _currentAddress;
                                _startAddress = _currentAddress;
                              },
                            ),
                            controller: startAddressController,
                            width: MediaQuery.of(context).size.width / 1.2,
                            locationCallback: (String value) {
                              setState(() {
                                _startAddress = value;
                              });
                            }),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width / 1.2,
                        height: 60,
                        child: _textField(
                            label: 'Destination',
                            hint: 'Choose destination',
                            prefixIcon: Icon(Icons.looks_two),
                            controller: destinationAddressController,
                            width: MediaQuery.of(context).size.width / 1.2,
                            locationCallback: (String value) {
                              setState(() {
                                _destinationAddress = value;
                              });
                            }),
                      ),
                      Visibility(
                        visible: _placeDistance == null ? false : true,
                        child: Column(
                          children: [
                            SizedBox(
                              height: 5,
                            ),
                            Text(
                              'Distance: $_placeDistance km',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            )
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 5,
                      ),
                      RaisedButton(
                        onPressed:(){}

                            ,
                        color: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Show Route'.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20.0,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
