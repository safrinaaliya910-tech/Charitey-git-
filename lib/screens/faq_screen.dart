// faq_screen.dart
import 'package:flutter/material.dart';

/// Role-based FAQ screen.
///
/// Shows ONLY the FAQs that match the signed-in user's own role
/// ([initialRole]) — a donor sees the 10 donor FAQs, an NGO sees the 10
/// NGO FAQs, a volunteer sees the 10 volunteer FAQs. There is no switcher
/// to browse the other roles' FAQs.
class FaqScreen extends StatefulWidget {
  /// Pass the current user's role (e.g. user.role from AuthProvider):
  /// 'donor', 'ngo', 'volunteer', or 'travel_agency'.
  final String initialRole;

  const FaqScreen({super.key, required this.initialRole});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem(this.question, this.answer);
}

class _FaqScreenState extends State<FaqScreen> {
  final Color themeColor = const Color(0xFF7D444C);

  static const List<_FaqItem> _donorFaqs = [
    _FaqItem(
      'Who can register as a Donor on Fourth Idly?',
      'Anyone who wants to support an NGO’s listed needs can register through the Donor option in the app and complete the required sign-up details.',
    ),
    _FaqItem(
      'Does a Donor account require document approval?',
      'The Donor account is designed to become active after successful registration. NGO and Volunteer accounts have separate document-review requirements.',
    ),
    _FaqItem(
      'How can I find an NGO that needs support?',
      'Sign in as a Donor and explore the available NGO Need Requests. Review the request details before choosing one to support.',
    ),
    _FaqItem(
      'What is a Need Request?',
      'A Need Request is a request created by an approved NGO describing the items or support it needs. Donors can view available requests and decide whether to contribute.',
    ),
    _FaqItem(
      'How do I make a donation through Fourth Idly?',
      'Open an available Need Request, review the details and follow the in-app steps to record or confirm your contribution.',
    ),
    _FaqItem(
      'Can I choose which NGO or Need Request to support?',
      'Yes. You can review the available requests and choose a request that you are willing and able to support.',
    ),
    _FaqItem(
      'How will I know what happens after I donate?',
      'The app provides relevant request-status notifications and communication features. You can follow the available updates associated with your contribution.',
    ),
    _FaqItem(
      'What is the role of a Volunteer after I make a donation?',
      'A Volunteer can accept the related delivery task, coordinate pickup, collect the contribution and deliver it to the NGO.',
    ),
    _FaqItem(
      'Is the delivery fee part of my donation?',
      'No. The donation supports the NGO’s stated need. The delivery fee is a separate amount associated with the delivery process and is shown separately in the app where applicable.',
    ),
    _FaqItem(
      'How can I share feedback about my experience?',
      'After the relevant interaction is completed, use the app’s rating and feedback feature to share your experience.',
    ),
  ];

  static const List<_FaqItem> _ngoFaqs = [
    _FaqItem(
      'How can an NGO register on Fourth Idly?',
      'Choose the NGO option in the app, enter the organisation details and submit the required NGO registration or licence document for review.',
    ),
    _FaqItem(
      'Can an NGO use all features immediately after registering?',
      'No. The NGO account must complete the required document-review and approval process before accessing approval-restricted features such as creating Need Requests.',
    ),
    _FaqItem(
      'What documents are required for NGO verification?',
      'The current onboarding flow requires the NGO’s relevant registration or licence document in PDF format, along with the requested organisation and contact details.',
    ),
    _FaqItem(
      'How does an approved NGO create a Need Request?',
      'After approval, sign in to the NGO account and use the Need Request feature to describe the items or support required and submit the request details.',
    ),
    _FaqItem(
      'What should an NGO include in a Need Request?',
      'Provide a clear description of the need and complete the fields requested in the app. Accurate, specific information helps Donors understand what support is required.',
    ),
    _FaqItem(
      'How does an NGO receive support from Donors?',
      'Donors can browse available Need Requests and choose one to support. The app records the relevant donation and request activity.',
    ),
    _FaqItem(
      'How is pickup and delivery coordinated?',
      'A Volunteer can accept an available delivery task, coordinate with the relevant participants, collect the contribution and deliver it to the NGO. In-app chat and notifications support coordination.',
    ),
    _FaqItem(
      'How does an NGO confirm that a contribution has arrived?',
      'After receiving the contribution, the NGO should use the receipt-confirmation step in the app. This records that delivery has been received and helps complete the workflow.',
    ),
    _FaqItem(
      'Can an NGO share updates about its activities and impact?',
      'Yes. NGOs can use the Impact Posts feature to share relevant updates about their work and the outcomes of community support.',
    ),
    _FaqItem(
      'Can an NGO review or respond to feedback?',
      'The app supports ratings and feedback for relevant interactions. NGOs should use the available in-app features to review feedback and support a transparent experience.',
    ),
  ];

  static const List<_FaqItem> _volunteerFaqs = [
    _FaqItem(
      'How can I register as a Volunteer?',
      'Choose the Volunteer option, complete the registration details and submit the required driving-licence document and UPI ID as requested in the app.',
    ),
    _FaqItem(
      'Does a Volunteer account become active immediately?',
      'Volunteer delivery access is subject to the required driving-licence review and approval. Follow the status shown in the app.',
    ),
    _FaqItem(
      'Why does Fourth Idly ask for my driving licence?',
      'The driving-licence document is part of the Volunteer verification process for users who take on pickup and delivery tasks.',
    ),
    _FaqItem(
      'Why do I need to provide a UPI ID?',
      'The Volunteer onboarding flow collects a UPI ID for delivery-related payment coordination where applicable. Use the payment details and instructions displayed in the app.',
    ),
    _FaqItem(
      'How can I find delivery tasks?',
      'After approval, open the Volunteer section and view the available delivery tasks shown in the app.',
    ),
    _FaqItem(
      'What happens when I accept a delivery task?',
      'The task is assigned to you according to the app’s workflow. Review the pickup and delivery details, then coordinate with the relevant participant before proceeding.',
    ),
    _FaqItem(
      'What am I expected to do during pickup?',
      'Coordinate the pickup, collect the donor’s contribution as described in the task and handle the items responsibly while preparing for delivery to the NGO.',
    ),
    _FaqItem(
      'How is the delivery fee handled?',
      'Where a delivery fee applies, follow the UPI or QR payment instructions displayed for the task. The app provides an “I’ve paid” confirmation step after payment.',
    ),
    _FaqItem(
      'What should I do if my delivery-fee payment is not verified?',
      'Use the in-app dispute or support process where available and provide the relevant payment details. The issue can then be reviewed through the platform’s administrative process.',
    ),
    _FaqItem(
      'When is my delivery task considered complete?',
      'After delivering the contribution to the NGO, the NGO must confirm receipt in the app. Relevant task status updates and the available rating or feedback feature help close the interaction.',
    ),
  ];

  static const Map<String, List<_FaqItem>> _faqsByRoleLabel = {
    'Donor': _donorFaqs,
    'NGO': _ngoFaqs,
    'Volunteer': _volunteerFaqs,
  };

  // Small accent colour per role, used for the icon badge and the
  // numbered circles — purely visual, doesn't affect content or logic.
  static const Map<String, Color> _roleAccent = {
    'Donor': Color(0xFFB56F76),
    'NGO': Color(0xFF7D444C),
    'Volunteer': Color(0xFF6F8F6B),
  };

  static const Map<String, IconData> _roleIcon = {
    'Donor': Icons.volunteer_activism_rounded,
    'NGO': Icons.apartment_rounded,
    'Volunteer': Icons.directions_car_rounded,
  };

  static const Map<String, String> _roleSubtitle = {
    'Donor': 'Donating, tracking and the delivery fee',
    'NGO': 'Verification, Need Requests and receipts',
    'Volunteer': 'Pickup, delivery and payment confirmation',
  };

  /// Maps the app's user.role values to a FAQ set label above.
  /// 'travel_agency' has no dedicated FAQ set in the source document, so
  /// it falls back to the NGO FAQs since travel agencies use the NGO
  /// dashboard flow elsewhere in the app. Adjust here if you'd rather it
  /// show something else.
  String _roleLabelFor(String role) {
    switch (role.toLowerCase().trim()) {
      case 'ngo':
      case 'travel_agency':
        return 'NGO';
      case 'volunteer':
        return 'Volunteer';
      case 'donor':
      default:
        return 'Donor';
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = _roleLabelFor(widget.initialRole);
    final faqs = _faqsByRoleLabel[roleLabel] ?? const [];
    final accent = _roleAccent[roleLabel] ?? themeColor;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Help & FAQs',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFDF7F8), Color(0xFFEEDAE0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.08, 1.0],
          ),
        ),
        child: _FaqList(
          faqs: faqs,
          accentColor: accent,
          headerIcon: _roleIcon[roleLabel] ?? Icons.help_outline_rounded,
          headerTitle: '$roleLabel FAQs',
          headerSubtitle: _roleSubtitle[roleLabel] ?? '',
        ),
      ),
    );
  }
}

class _FaqList extends StatelessWidget {
  final List<_FaqItem> faqs;
  final Color accentColor;
  final IconData headerIcon;
  final String headerTitle;
  final String headerSubtitle;

  const _FaqList({
    required this.faqs,
    required this.accentColor,
    required this.headerIcon,
    required this.headerTitle,
    required this.headerSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: faqs.length + 1,
      itemBuilder: (context, index) {
        // Header card: role icon + short blurb, shown once above the list.
        if (index == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withOpacity(0.18)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(headerIcon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headerTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        headerSubtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade700,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final faq = faqs[index - 1];
        final qNumber = index; // 1-based

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              iconColor: accentColor,
              collapsedIconColor: Colors.grey.shade400,
              leading: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$qNumber',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: accentColor,
                  ),
                ),
              ),
              title: Text(
                faq.question,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                  color: Colors.black87,
                  height: 1.3,
                ),
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    faq.answer,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.grey.shade700,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}