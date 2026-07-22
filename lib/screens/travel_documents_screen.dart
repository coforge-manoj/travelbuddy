import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/travel_document.dart';
import '../utils/sample_data.dart';

class TravelDocumentsScreen extends StatefulWidget {
  const TravelDocumentsScreen({super.key});

  @override
  State<TravelDocumentsScreen> createState() => _TravelDocumentsScreenState();
}

class _TravelDocumentsScreenState extends State<TravelDocumentsScreen> {
  final _documents = List<TravelDocument>.from(SampleData.documents);

  @override
  Widget build(BuildContext context) {
    final expiringSoon = _documents.where((d) => d.isExpiringSoon).toList();
    final expired = _documents.where((d) => d.isExpired).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Travel Documents')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDocumentDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Document'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (expired.isNotEmpty) ...[
              _AlertBanner(
                color: const Color(0xFFD32F2F),
                icon: Icons.error_outline,
                title: '${expired.length} document${expired.length > 1 ? 's' : ''} expired',
                message: 'Please renew your expired documents before travelling.',
              ),
              const SizedBox(height: 12),
            ],
            if (expiringSoon.isNotEmpty) ...[
              _AlertBanner(
                color: const Color(0xFFF57C00),
                icon: Icons.warning_amber_rounded,
                title: '${expiringSoon.length} document${expiringSoon.length > 1 ? 's' : ''} expiring soon',
                message: 'Renew documents expiring within 90 days to avoid travel disruptions.',
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              'My Documents',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_documents.isEmpty)
              const _EmptyDocumentsCard()
            else
              ..._documents.map((doc) => _DocumentCard(
                    document: doc,
                    onDelete: () {
                      setState(() {
                        _documents.removeWhere((d) => d.id == doc.id);
                      });
                    },
                  )),
          ],
        ),
      ),
    );
  }

  void _showAddDocumentDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _AddDocumentSheet(),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String message;

  const _AlertBanner({
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final TravelDocument document;
  final VoidCallback? onDelete;

  const _DocumentCard({required this.document, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy');

    Color borderColor = Colors.transparent;
    if (document.isExpired) {
      borderColor = const Color(0xFFD32F2F);
    } else if (document.isExpiringSoon) {
      borderColor = const Color(0xFFF57C00);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: borderColor != Colors.transparent
            ? BorderSide(color: borderColor, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(document.typeIcon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        document.typeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (document.isExpired)
                  _StatusChip(label: 'Expired', color: const Color(0xFFD32F2F))
                else if (document.isExpiringSoon)
                  _StatusChip(label: 'Expiring Soon', color: const Color(0xFFF57C00))
                else if (document.expiryDate != null)
                  _StatusChip(label: 'Valid', color: const Color(0xFF388E3C)),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete' && onDelete != null) {
                      onDelete!();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'view', child: Text('View Details')),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (document.documentNumber != null)
                  _InfoChip(
                    icon: Icons.tag,
                    label: document.documentNumber!,
                  ),
                if (document.issuingCountry != null)
                  _InfoChip(
                    icon: Icons.flag_outlined,
                    label: document.issuingCountry!,
                  ),
                if (document.issueDate != null)
                  _InfoChip(
                    icon: Icons.calendar_month_outlined,
                    label: 'Issued: ${dateFormat.format(document.issueDate!)}',
                  ),
                if (document.expiryDate != null)
                  _InfoChip(
                    icon: Icons.event_available_outlined,
                    label: 'Expires: ${dateFormat.format(document.expiryDate!)}',
                    color: document.isExpired
                        ? const Color(0xFFD32F2F)
                        : document.isExpiringSoon
                            ? const Color(0xFFF57C00)
                            : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? Colors.grey[600]!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: textColor),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: textColor),
        ),
      ],
    );
  }
}

class _EmptyDocumentsCard extends StatelessWidget {
  const _EmptyDocumentsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.description_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No documents yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add your passport, visa, and other travel documents',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddDocumentSheet extends StatefulWidget {
  const _AddDocumentSheet();

  @override
  State<_AddDocumentSheet> createState() => _AddDocumentSheetState();
}

class _AddDocumentSheetState extends State<_AddDocumentSheet> {
  DocumentType _selectedType = DocumentType.passport;
  final _titleController = TextEditingController();
  final _numberController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Add Document',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<DocumentType>(
            value: _selectedType,
            decoration: const InputDecoration(labelText: 'Document Type'),
            items: DocumentType.values.map(
              (t) {
                final doc = TravelDocument(
                  id: '',
                  type: t,
                  title: '',
                );
                return DropdownMenuItem(
                  value: t,
                  child: Text('${doc.typeIcon}  ${doc.typeLabel}'),
                );
              },
            ).toList(),
            onChanged: (v) => setState(() => _selectedType = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title / Description'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _numberController,
            decoration: const InputDecoration(labelText: 'Document Number (optional)'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Document added successfully')),
                );
              },
              child: const Text('Add Document'),
            ),
          ),
        ],
      ),
    );
  }
}
