import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:multicrop/service/storage_service.dart';

class NewDataEntryPage extends StatefulWidget {
  final String workerId;

  const NewDataEntryPage({super.key, required this.workerId});

  @override
  State<NewDataEntryPage> createState() => _NewDataEntryPageState();
}

class _NewDataEntryPageState extends State<NewDataEntryPage> {
  // ===== STATE VARIABLES =====
  DateTime selectedDate = DateTime.now();
  final TextEditingController plotController = TextEditingController();
  final TextEditingController stageController = TextEditingController();
  int? selectedTreeNumber = 1;
  final TextEditingController bunchNumberController = TextEditingController(text: '0');
  final TextEditingController weightController = TextEditingController(text: '0.00');
  final FocusNode plotFocusNode = FocusNode();
  final List<int> treeNumbers = List.generate(12, (index) => index + 1);

  // ===== LIFECYCLE METHODS =====
  @override
  void initState() {
    super.initState();
    plotFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    plotFocusNode.dispose();
    stageController.dispose();
    plotController.dispose();
    bunchNumberController.dispose();
    weightController.dispose();
    super.dispose();
  }

  // ===== UTILITY FUNCTIONS =====
  
  String _formatDate(DateTime date) {
    return "${_weekday(date.weekday)}, ${_month(date.month)} ${date.day}, ${date.year}";
  }

  String _weekday(int w) {
    const days = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday",
    ];
    return days[w - 1];
  }

  String _month(int m) {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    return months[m - 1];
  }

  // ===== VALIDATION FUNCTIONS =====
  
  bool _isFormValid() {
    return plotController.text.isNotEmpty &&
        stageController.text.isNotEmpty &&
        selectedTreeNumber != null &&
        (int.tryParse(bunchNumberController.text) ?? 0) >= 0 &&
        (double.tryParse(weightController.text) ?? 0.0) >= 0.0;
  }

  // ===== UI HELPER FUNCTIONS =====
  
  void _showPopup(BuildContext context, bool success, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: success ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (success ? Colors.green : Colors.red).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: success ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: Icon(
                  success ? Icons.check : Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ===== DATA FUNCTIONS =====
  
  Future<void> _refreshData() async {
    await Future.delayed(const Duration(milliseconds: 1000));

    plotController.clear();
    stageController.clear();
    bunchNumberController.text = '0';
    weightController.text = '0.00';

    setState(() {
      selectedDate = DateTime.now();
      selectedTreeNumber = 1;
    });
  }

  Future<void> _submitEntry() async {
    if (_isFormValid()) {
      Map<String, dynamic> newEntry = {
        "date": selectedDate,
        "stage": stageController.text.trim(),
        "block": plotController.text.trim(),
        "tree": selectedTreeNumber,
        "bunches": int.tryParse(bunchNumberController.text) ?? 0,
        "weight": double.tryParse(weightController.text) ?? 0.0,
      };

      List<Map<String, dynamic>> currentEntries =
          await StorageHelper.loadEntries();
      currentEntries.add(newEntry);
      await StorageHelper.saveEntries(currentEntries);

      _showPopup(context, true, "Entry Added Successfully!");

      plotController.clear();
      stageController.clear();
      bunchNumberController.text = '0';
      weightController.text = '0.00';
      setState(() {
        selectedDate = DateTime.now();
        selectedTreeNumber = 1;
      });
    } else {
      _showPopup(context, false, "Please fill in all fields correctly!");
    }
  }

  void _changeNumberValue({
    required TextEditingController controller,
    required bool increase,
    required double step,
    required bool isDecimal,
  }) {
    double currentValue = double.tryParse(controller.text) ?? 0.00;
    double stepValue = step;

    setState(() {
      double newValue = increase
          ? currentValue + stepValue
          : currentValue - stepValue;

      if (isDecimal) {
        int decimalPlaces = step.toString().split('.').length > 1
            ? step.toString().split('.')[1].length
            : 0;
        controller.text = (newValue > 0 ? newValue : 0.00).toStringAsFixed(
          decimalPlaces,
        );
      } else {
        controller.text = (newValue > 0 ? newValue : 0).toInt().toString();
      }
    });
  }

  // ===== UI BUILD METHODS =====

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const double fixedInputHeight = 50;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8F9EE), Color(0xFFD6F5E3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshData,
                  color: Colors.white,
                  backgroundColor: Colors.transparent,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 20,
                    ),
                    child: Column(
                      children: [
                        _buildDateField(size, fixedInputHeight),
                        _buildStageField(size, fixedInputHeight),
                        const SizedBox(height: 10),
                        _buildPlotAndTreeRow(fixedInputHeight),
                        _buildBunchesAndWeightRow(),
                        const SizedBox(height: 5),
                        _buildSubmitButton(),
                        const SizedBox(height: 15),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Header Widget
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 14,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE9F8EE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SvgPicture.asset(
              'lib/assets/tree_palm.svg',
              colorFilter: const ColorFilter.mode(
                Colors.green,
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "New Data Entry",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "ID ${widget.workerId}",
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Date Field Widget
  Widget _buildDateField(Size size, double fixedInputHeight) {
    return _buildFieldCard(
      icon: Icons.calendar_today_outlined,
      iconColor: const Color(0xFF10B981),
      label: "Date of Entry",
      width: size.width,
      child: SizedBox(
        height: fixedInputHeight,
        child: OutlinedButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null && picked != selectedDate) {
              setState(() => selectedDate = picked);
            }
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black87,
            backgroundColor: Colors.white,
            side: const BorderSide(
              color: Color(0xFF10B981),
              width: 1.5,
            ),
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            _formatDate(selectedDate),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // Stage Field Widget
  Widget _buildStageField(Size size, double fixedInputHeight) {
    return _buildFieldCard(
      icon: Icons.spa_outlined,
      iconColor: Colors.green,
      label: "Tree Stage",
      width: size.width,
      child: SizedBox(
        height: fixedInputHeight,
        child: _buildTextField(
          stageController,
          "e.g. SRF 5/13",
          keyboardType: TextInputType.text,
          color: Colors.green,
        ),
      ),
    );
  }

  // Plot and Tree Row Widget
  Widget _buildPlotAndTreeRow(double fixedInputHeight) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildFieldCard(
            icon: Icons.square_outlined,
            iconColor: Colors.teal,
            label: "Plot",
            child: SizedBox(
              height: fixedInputHeight,
              child: _buildPlotTextField(),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildFieldCard(
            icon: Icons.nature_outlined,
            iconColor: Colors.cyan,
            label: "Tree",
            child: SizedBox(
              height: fixedInputHeight,
              child: _buildTreeDropdown(),
            ),
          ),
        ),
      ],
    );
  }

  // Bunches and Weight Row Widget
  Widget _buildBunchesAndWeightRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildFieldCard(
            icon: Icons.grass_rounded,
            iconColor: Colors.lime,
            label: "Bunches",
            child: _buildHybridNumberInput(
              controller: bunchNumberController,
              color: Colors.black,
              unit: 'Bunches',
              step: 1,
              isDecimal: false,
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildFieldCard(
            icon: Icons.scale_outlined,
            iconColor: const Color(0xFF14B8A6),
            label: "Weight",
            child: _buildHybridNumberInput(
              controller: weightController,
              color: Colors.black,
              unit: 'kg',
              step: 0.01,
              isDecimal: true,
            ),
          ),
        ),
      ],
    );
  }

  // Submit Button Widget
  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.green, Colors.lightGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.5),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _submitEntry,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: 38,
            vertical: 15,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Text(
              'ADD ENTRY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Text Field Widget
  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
    required Color color,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: color),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 18, color: Colors.black45),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade100, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade100, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 2.5),
        ),
      ),
    );
  }

  // Plot Text Field Widget
  Widget _buildPlotTextField() {
    const Color color = Colors.blue;
    final bool showHint =
        !plotFocusNode.hasFocus && plotController.text.isEmpty;

    return TextField(
      focusNode: plotFocusNode,
      controller: plotController,
      keyboardType: TextInputType.number,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: color,
      ),
      decoration: InputDecoration(
        hintText: showHint ? "Plot" : null,
        hintStyle: const TextStyle(fontSize: 20, color: Colors.black45),
        prefixText: "P ",
        prefixStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade300,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade100, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade100, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: color, width: 2.5),
        ),
      ),
    );
  }

  // Tree Dropdown Widget
  Widget _buildTreeDropdown() {
    return DropdownButtonFormField<int>(
      value: selectedTreeNumber,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: 8,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Colors.teal,
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Colors.teal,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Colors.teal,
            width: 2.5,
          ),
        ),
      ),
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: Colors.teal.shade700,
      ),
      icon: Icon(
        Icons.arrow_drop_down,
        color: Colors.teal.shade700,
        size: 30,
      ),
      items: treeNumbers.map((int number) {
        return DropdownMenuItem<int>(
          value: number,
          child: Center(child: Text('$number')),
        );
      }).toList(),
      onChanged: (int? newValue) {
        setState(() {
          selectedTreeNumber = newValue;
        });
      },
    );
  }

  // Hybrid Number Input Widget
  Widget _buildHybridNumberInput({
    required TextEditingController controller,
    required Color color,
    required String unit,
    double step = 1.0,
    bool isDecimal = false,
  }) {
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.5), width: 1.0),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: TextField(
              controller: controller,
              keyboardType: isDecimal
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.number,
              textAlign: TextAlign.center,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: color,
              ),
              decoration: InputDecoration(
                hintText: isDecimal ? '0.00' : '0',
                hintStyle: TextStyle(
                  fontSize: 30,
                  color: color.withOpacity(0.4),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlCircle(
                icon: Icons.remove,
                color: color,
                onTap: () => _changeNumberValue(
                  controller: controller,
                  increase: false,
                  step: step,
                  isDecimal: isDecimal,
                ),
              ),
              _buildControlCircle(
                icon: Icons.add,
                color: color,
                onTap: () => _changeNumberValue(
                  controller: controller,
                  increase: true,
                  step: step,
                  isDecimal: isDecimal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Control Circle Widget
  Widget _buildControlCircle({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  // Field Card Widget
  Widget _buildFieldCard({
    required String label,
    required Widget child,
    required IconData icon,
    required Color iconColor,
    double? width,
  }) {
    return Container(
      width: width,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: iconColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
