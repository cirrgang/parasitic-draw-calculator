import 'package:flutter/material.dart';
// this is to load the files VVVV
import 'package:flutter/services.dart';

//
// ====================================================================
// PARASITIC DRAW CALCULATOR
//
// Purpose:
// Convert fuse voltage-drop measurements into current draw.
//
// Features:
//   • Manual resistance calculations
//   • Fuse chart lookups
//   • Dynamic fuse file loading
//   • Interpolated values between chart points
//   • Dark mode user interface
//
// Fuse chart files are stored in:
//
//   assets/data/
//
// Supported Fuse Types:
//   • Mini
//   • Micro
//   • Standard
//   • Maxi
//   • Cartridge
//   • Glass
//
// The lookup engine loads fuse chart files at runtime and uses
// linear interpolation when the voltage entered falls between
// published chart values.
//
// This project was developed as both a Flutter learning project
// and a practical automotive diagnostic tool.
//
// ====================================================================
//

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: const ParasiticDrawPage(),
    );
  }
}

class ParasiticDrawPage extends StatefulWidget {
  const ParasiticDrawPage({super.key});

  @override
  State<ParasiticDrawPage> createState() => _ParasiticDrawPageState();
}

class _ParasiticDrawPageState extends State<ParasiticDrawPage> {
  final TextEditingController voltageController =
      TextEditingController();

  final TextEditingController resistanceController =
      TextEditingController();
  
  //
  // ====================================================================
  // FUSE FILE LOADER
  //
  // Reads fuse chart data from the assets/data directory.
  // When a fuse type is selected, the corresponding file:
  //
  //   Mini      -> mini_fuse.txt
  //   Micro     -> micro_fuse.txt
  //   Standard  -> standard_fuse.txt
  //
  // is loaded into memory.
  //
  // loadedLines   = entire file contents
  // loadedRatings = ratings extracted from row 2
  //
  // ====================================================================
  //

  Future<void> loadFuseFile(String fuseType) async {
    
    String fileName = fuseFiles[fuseType]!;
    print("Loading fuse file: $fileName");
    String data =
      await rootBundle.loadString(
        'assets/data/$fileName',
      );
    List<String> lines = data.split('\n');
    loadedLines = lines;

    List<String> testRow = lines[50].split(',');

    String ratingLine = lines[2];
    List<String> ratings = ratingLine.split(',');
    ratings.removeAt(0);

    setState(() {
      loadedRatings = ratings;
      if (loadedRatings.isNotEmpty) {
        selectedFuseRating = loadedRatings[0];
      }
    });

  }
  //
  // end of the test for loading the files
  //
  //
  // the variables
  //
  List<String> loadedRatings = [];
  List<String> loadedLines = [];
  double currentDraw = 0.0;
  double currentDrawMa = 0.0;
  String diagnosis = "";
  String selectedFuseType = "Mini";
  final List<String> fuseTypes = [
    'Mini',
    'Micro',
    'Standard',
    'Maxi',
    'Cartridge',
    'Glass'
  ];
  final Map<String, String> fuseFiles = {
    'Mini': 'mini_fuse.txt',
    'Micro': 'micro_fuse.txt',
    'Standard': 'standard_fuse.txt',
    'Maxi': 'maxi_fuse.txt',
    'Cartridge': 'cartrige_fuse.txt',
    'Glass': 'glass_fuse.txt',
  };
  String selectedFuseRating = "10Amp";

  String selectedMode = "Manual Resistance";

  final List<String> calculationModes = [
    "Manual Resistance",
    "Fuse Chart Lookup"
  ];

  double lookupCurrentMa = 0.0;

  @override
  void initState() {
    super.initState();
    loadFuseFile(selectedFuseType);
  }

  //
  // End of variable section
  //
  //
  // functions for the buttons
  //

  void clearFields() {
    setState(() {
      voltageController.clear();
      resistanceController.clear();

      currentDraw = 0.0;
      currentDrawMa = 0.0;

      diagnosis = "";
    });
  }

  //
  // ====================================================================
  // CURRENT DRAW CALCULATOR
  //
  // MANUAL MODE
  //   Current = Voltage Drop / Fuse Resistance
  //
  // LOOKUP MODE
  //   1. Determine selected fuse rating column.
  //   2. Find the two voltage rows surrounding the input value.
  //   3. Interpolate between those rows.
  //   4. Display current draw results.
  //
  // ====================================================================
  //

  void calculateCurrent() {
    double voltageMv =
        double.tryParse(voltageController.text) ?? 0.0;
    if (selectedMode == "Fuse Chart Lookup") {
      List<String> ratingColumns =
        loadedLines[2].split(',');
      int ratingColumn =
        ratingColumns.indexOf(selectedFuseRating);

        //
        // Linear interpolation
        //
        // Example:
        //
        // Table:
        //
        //   4.8 mV -> 647 mA
        //   4.9 mV -> 660 mA
        //
        // User enters:
        //
        //   4.85 mV
        //
        // Result:
        //
        //   approximately 654 mA
        //
        // This allows current estimates between published chart values
        // rather than requiring an exact chart match.
        //

        for (int i = 3; i < loadedLines.length - 1; i++) {
          List<String> row1 =
            loadedLines[i].split(',');
          List<String> row2 =
            loadedLines[i + 1].split(',');
          double v1 =
            double.tryParse(row1[0]) ?? -1;
          double v2 =
            double.tryParse(row2[0]) ?? -1;
          if (voltageMv >= v1 &&
            voltageMv <= v2) {
              double c1 =
                double.tryParse(
                  row1[ratingColumn]) ?? 0.0;
              double c2 =
                double.tryParse(
                  row2[ratingColumn]) ?? 0.0;
              double lookupValue =
                c1 +
                (voltageMv - v1) *
                (c2 - c1) /
                (v2 - v1);
              setState(() {
                currentDrawMa = lookupValue;
                currentDraw = lookupValue / 1000.0;
                if (currentDrawMa < 50) {
                  diagnosis = "Normal";
                } else if (currentDrawMa < 100) {
                  diagnosis = "Elevated";
                } else {
                  diagnosis = "Excessive Draw";
                }
              });
              print("Interpolated Value:");
              print(lookupValue);
              return;
            }
        }
    }

    double resistanceMohm =
        double.tryParse(resistanceController.text) ?? 0.0;

    if (resistanceMohm > 0) {
      setState(() {
        currentDraw = voltageMv / resistanceMohm;
        currentDrawMa = currentDraw * 1000;
        if (currentDrawMa < 50) {
          diagnosis = "Normal";
        }
        else if (currentDrawMa < 100) {
          diagnosis = "Elevated";
        }
        else {
          diagnosis = "Excessive Draw";
        }
      });
    }
  }

//
// ====================================================================
// USER INTERFACE
//
// Layout:
//
//   AppBar
//
//   Main Card
//      ├─ Reference Information
//      ├─ Calculation Mode Selector
//      ├─ Fuse Type Selector
//      ├─ Fuse Rating Selector
//      ├─ Voltage Input
//      ├─ Resistance Input (Manual Mode Only)
//      ├─ Action Buttons
//      └─ Results Section
//
// Dark theme optimized for garage and field use.
//
// ====================================================================
//

  @override
  Widget build(BuildContext context) {
    Color diagnosisColor = Colors.green;
    if (diagnosis == "Normal") {
      diagnosisColor = Colors.green;
    } else if (diagnosis == "Elevated") {
      diagnosisColor = Colors.orange;
    } else if (diagnosis == "Excessive Draw") {
      diagnosisColor = Colors.red;
    }
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Parasitic Draw Calculator"),
      ),
      
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade900,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Reference:\n"
                          "1mV = 0.001V | 1mA = 0.001A | 1mΩ = 0.001Ω",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    const Text(
                      "Calculation Mode",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    DropdownButton<String>(
                      value: selectedMode,
                      isExpanded: true,
                      items: calculationModes.map((String mode) {
                        return DropdownMenuItem<String>(
                          value: mode,
                          child: Text(mode),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedMode = newValue!;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    if (selectedMode == "Fuse Chart Lookup") ...[
                      const Text(
                        "Fuse Type",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    
                      DropdownButton<String>(
                        value: selectedFuseType,
                        isExpanded: true,
                        items: fuseTypes.map((String fuseType) {
                          return DropdownMenuItem<String>(
                            value: fuseType,
                            child: Text(fuseType),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedFuseType = newValue!;
                          });
                          loadFuseFile(selectedFuseType);
                        },
                      ),

                      const SizedBox(height: 20),
                    ],

                  if (selectedMode == "Fuse Chart Lookup") ...[
                    const Text(
                      "Fuse Rating",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    DropdownButton<String>(
                      value: selectedFuseRating,
                      isExpanded: true,
                      //items: fuseRatings.map((String rating) {
                      items: loadedRatings.map((String rating) {
                        return DropdownMenuItem<String>(
                          value: rating,
                          child: Text(rating),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedFuseRating = newValue!;
                        });
                      },
                    ),
                  ],

                  TextField(
                    controller: voltageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Voltage Drop (mV)",
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (selectedMode == "Manual Resistance")
                    TextField(
                      controller: resistanceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Fuse Resistance (mΩ)",
                      ),
                    ),

                  const SizedBox(height: 20),

                  Row(
                    children: [

                      SizedBox(
                        width: 140,
                        height: 50,
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          onPressed: calculateCurrent,
                          child: const Text(
                            "Calculate",
                            style: TextStyle(
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      SizedBox(
                        width: 100,
                        height: 50,
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade700,
                              foregroundColor: Colors.white,
                            ),
                          onPressed: clearFields,
                          child: const Text(
                            "Clear",
                            style: TextStyle(
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),

                    ],
                  ),

                  const SizedBox(height: 30),

                  const Row(
                    children: [
                      Icon(Icons.electric_bolt,
                          color: Colors.amber),
                      SizedBox(width: 8),
                      Text("Current Draw"),
                    ],
                  ),
                  // Text(
                  //   "Current Draw:",
                  //   style: Theme.of(context).textTheme.titleLarge,
                  // ),

                  const SizedBox(height: 10),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${currentDrawMa.toStringAsFixed(0)} mA",
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${currentDraw.toStringAsFixed(3)} A",
                        style: const TextStyle(
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        diagnosis,
                        style: TextStyle(
                          color: diagnosisColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}