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
  final _scaffoldKey=GlobalKey<ScaffoldState>();
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
      });
      await _getAddress();
    }).catchError((e) {
      print(e);
    });
  }
  // Method for calculating the distance between two places
  Future<bool> _calculateDistance() async {
    try {
      // Retrieving placemarks from addresses
      List<Placemark> startPlacemark =
      await _geolocator.placemarkFromAddress(_startAddress);
      List<Placemark> destinationPlacemark =
      await _geolocator.placemarkFromAddress(_destinationAddress);

      if (startPlacemark != null && destinationPlacemark != null) {
        // Use the retrieved coordinates of the current position,
        // instead of the address if the start position is user's
        // current position, as it results in better accuracy.
        Position startCoordinates = _startAddress == _currentAddress
            ? Position(
            latitude: _currentPosition.latitude,
            longitude: _currentPosition.longitude)
            : startPlacemark[0].position;
        Position destinationCoordinates = destinationPlacemark[0].position;

        // Start Location Marker
        Marker startMarker = Marker(
          markerId: MarkerId('$startCoordinates'),
          position: LatLng(
            startCoordinates.latitude,
            startCoordinates.longitude,
          ),
          infoWindow: InfoWindow(
            title: 'Start',
            snippet: _startAddress,
          ),
          icon: BitmapDescriptor.defaultMarker,
        );

        // Destination Location Marker
        Marker destinationMarker = Marker(
          markerId: MarkerId('$destinationCoordinates'),
          position: LatLng(
            destinationCoordinates.latitude,
            destinationCoordinates.longitude,
          ),
          infoWindow: InfoWindow(
            title: 'Destination',
            snippet: _destinationAddress,
          ),
          icon: BitmapDescriptor.defaultMarker,
        );

        // Adding the markers to the list
        markers.add(startMarker);
        markers.add(destinationMarker);

        print('START COORDINATES: $startCoordinates');
        print('DESTINATION COORDINATES: $destinationCoordinates');

        Position _northeastCoordinates;
        Position _southwestCoordinates;

        // Calculating to check that
        // southwest coordinate <= northeast coordinate
        if (startCoordinates.latitude <= destinationCoordinates.latitude) {
          _southwestCoordinates = startCoordinates;
          _northeastCoordinates = destinationCoordinates;
        } else {
          _southwestCoordinates = destinationCoordinates;
          _northeastCoordinates = startCoordinates;
        }

        // Accommodate the two locations within the
        // camera view of the map
        mapController.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              northeast: LatLng(
                _northeastCoordinates.latitude,
                _northeastCoordinates.longitude,
              ),
              southwest: LatLng(
                _southwestCoordinates.latitude,
                _southwestCoordinates.longitude,
              ),
            ),
            100.0,
          ),
        );
        // Calculating the distance between the start and the end positions
        // with a straight path, without considering any route
        // double distanceInMeters = await Geolocator().bearingBetween(
        //   startCoordinates.latitude,
        //   startCoordinates.longitude,
        //   destinationCoordinates.latitude,
        //   destinationCoordinates.longitude,
        // );

        await _createPolyLines(startCoordinates, destinationCoordinates);

        double totalDistance = 0.0;

        // Calculating the total distance by adding the distance
        // between small segments
        for (int i = 0; i < polylineCoordinates.length - 1; i++) {
          totalDistance += _coordinateDistance(
            polylineCoordinates[i].latitude,
            polylineCoordinates[i].longitude,
            polylineCoordinates[i + 1].latitude,
            polylineCoordinates[i + 1].longitude,
          );
        }

        setState(() {
          _placeDistance = totalDistance.toStringAsFixed(2);
          print('DISTANCE: $_placeDistance km');
        });

        return true;
      }
    } catch (e) {
      print(e);
    }
    return false;
      }
  _createPolyLines(Position start, Position destination) async {
    _polylinePoints = PolylinePoints();
    PolylineResult result = await _polylinePoints.getRouteBetweenCoordinates(
        'AIzaSyCShaIyht8QiAtoSg0hd_v0PQLBH_YQKtM',
        PointLatLng(start.latitude, start.longitude),
        PointLatLng(destination.latitude, destination.longitude),
        travelMode: TravelMode.transit);
    if (result.points.isNotEmpty) {
      //Adding the coordinates to the list
      result.points.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    }
    PolylineId id = PolylineId('poly');
    Polyline polyline = Polyline(
        polylineId: id,
        color: Colors.orange[100],
        points: polylineCoordinates,
        width: 3);
    polylines[id] = polyline;
  }

  double _coordinateDistance(lat1, lon1, lat2, lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
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
      child: Scaffold(key: _scaffoldKey,
        body: Stack(
          children: [
            GoogleMap(
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
                          child: TextField(
                            controller: startAddressController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30)),
                              labelText: 'start',
                              prefixIcon: Icon(Icons.looks_one),
                              suffixIcon: Icon(Icons.my_location),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          )),
                      SizedBox(
                        height: 10,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width / 1.2,
                        height: 60,
                        child: TextField(
                          decoration: InputDecoration(
                              prefixIcon: Icon(Icons.looks_two),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30)),
                              labelText: 'Destination',
                              filled: true,
                              fillColor: Colors.white),
                        ),
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
                    onPressed: (_startAddress != '' &&
                        _destinationAddress != '')
                        ? () async {
                      setState(() {
                        if (markers.isNotEmpty) markers.clear();
                        if (polylines.isNotEmpty)
                          polylines.clear();
                        if (polylineCoordinates.isNotEmpty)
                          polylineCoordinates.clear();
                        _placeDistance = null;
                      });

                      _calculateDistance().then((isCalculated) {
                        if (isCalculated) {
                          _scaffoldKey.currentState.showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Distance Calculated Sucessfully'),
                            ),
                          );
                        } else {
                          _scaffoldKey.currentState.showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Error Calculating Distance'),
                            ),
                          );
                        }
                      });
                    }
                        : null,
                    color: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Show Route'.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.0,
                      ),),),)],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
