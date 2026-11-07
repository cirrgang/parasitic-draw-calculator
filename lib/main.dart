import 'package:flutter/material.dart';
// this is to load the files VVVV
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: ParasiticDrawPage(),
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
  // this is a test for loading files
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
  // end of the test for loading the files

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
  
  void clearFields() {
    setState(() {
      voltageController.clear();
      resistanceController.clear();

      currentDraw = 0.0;
      currentDrawMa = 0.0;

      diagnosis = "";
    });
  }

  void calculateCurrent() {
    double voltageMv =
        double.tryParse(voltageController.text) ?? 0.0;
    if (selectedMode == "Fuse Chart Lookup") {
      List<String> ratingColumns =
        loadedLines[2].split(',');
      int ratingColumn =
        ratingColumns.indexOf(selectedFuseRating);

      for (int i = 3; i < loadedLines.length; i++) {
        List<String> row =
          loadedLines[i].split(',');
        double rowVoltage =
          double.tryParse(row[0]) ?? -1;


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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Parasitic Draw Calculator"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                ElevatedButton(
                  onPressed: calculateCurrent,
                  child: const Text("Calculate"),
                ),

                const SizedBox(width: 10),

                ElevatedButton(
                  onPressed: clearFields,
                  child: const Text("Clear"),
                ),
              ],
            ),

            const SizedBox(height: 30),

            Text(
              "Current Draw:",
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: 10),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${currentDraw.toStringAsFixed(3)} A",
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "${currentDrawMa.toStringAsFixed(0)} mA",
                  style: const TextStyle(
                    fontSize: 24,
                  ),
                ),
                Text(
                  diagnosis,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

          ],
        ),
      ),
    );
  }
}