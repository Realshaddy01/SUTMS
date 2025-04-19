import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../providers/violation_provider.dart';
import '../widgets/custom_text_field.dart';
import '../utils/validators.dart';

class ViolationAppealScreen extends StatefulWidget {
  final int violationId;

  const ViolationAppealScreen({
    Key? key,
    required this.violationId,
  }) : super(key: key);

  @override
  _ViolationAppealScreenState createState() => _ViolationAppealScreenState();
}

class _ViolationAppealScreenState extends State<ViolationAppealScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  File? _evidenceFile;
  bool _isLoading = false;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _loadViolationDetails();
  }
  
  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
  
  Future<void> _loadViolationDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final violationProvider = Provider.of<ViolationProvider>(context, listen: false);
      await violationProvider.getViolationDetails(widget.violationId);
    } catch (e) {
      setState(() {
        _error = 'Failed to load violation details: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _evidenceFile = File(image.path);
      });
    }
  }
  
  Future<void> _submitAppeal() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final violationProvider = Provider.of<ViolationProvider>(context, listen: false);
      
      if (authProvider.user?.token == null) {
        throw Exception("Authentication token not found");
      }
      final success = await violationProvider.submitAppeal(
        widget.violationId,
        _reasonController.text.trim(),
        evidenceFile: _evidenceFile,
      );      
      // final success = await violationProvider.submitAppeal(
      //   token: authProvider.user!.token!,
      //   violationId: widget.violationId,
      //   reason: _reasonController.text.trim(),
      //   evidenceFile: _evidenceFile,
      // );
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Appeal submitted successfully')),
          );
          Navigator.of(context).pop(); // Return to previous screen
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(violationProvider.error ?? 'Failed to submit appeal')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to submit appeal: ${e.toString()}';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error!)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final violationProvider = Provider.of<ViolationProvider>(context);
    final violation = violationProvider.currentViolation;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appeal Violation'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadViolationDetails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Violation summary card
                        if (violation != null)
                          Card(
                            margin: const EdgeInsets.only(bottom: 24),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Violation #${violation.id}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  _buildDetailRow('Type', violation.violationTypeName),
                                  const SizedBox(height: 8),
                                  _buildDetailRow('Vehicle', violation.vehicleLicensePlate),
                                  const SizedBox(height: 8),
                                  _buildDetailRow('Date', violation.formattedDate),
                                  const SizedBox(height: 8),
                                  _buildDetailRow('Fine Amount', '\$${violation.fineAmount.toStringAsFixed(2)}'),
                                ],
                              ),
                            ),
                          ),
                        
                        const Text(
                          'Appeal Reason',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Please explain why you believe this violation should be contested:',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _reasonController,
                          labelText: 'Reason',
                          hintText: 'Explain why you are appealing this violation',
                          prefixIcon: Icons.description,
                          maxLines: 5,
                          validator: (value) => Validators.validateRequired(
                            value,
                            'Please provide a reason for your appeal',
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        const Text(
                          'Supporting Evidence',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Attach any relevant evidence to support your appeal (optional):',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Evidence file selection
                        _evidenceFile != null
                            ? Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        _evidenceFile!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.cancel,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _evidenceFile = null;
                                      });
                                    },
                                  ),
                                ],
                              )
                            : GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  width: double.infinity,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Tap to add evidence',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        const SizedBox(height: 32),
                        
                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitAppeal,
                            child: _isLoading
                                ? const CircularProgressIndicator()
                                : const Text('Submit Appeal'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }
} 