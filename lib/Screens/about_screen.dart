import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

import '../Utils/tools.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "About Page 🧾",
          style: Tools.h2(context).copyWith(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: SingleChildScrollView(
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Developer Card
                Card(
                  color: Colors.grey[900],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          "Developed By:",
                          style: Tools.h2(context).copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "KAVIN M",
                          style: Tools.h2(context).copyWith(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
            
                // Contact Info
                _buildInfoTile("📞 Phone", "+91 9384242333", context),
                _buildInfoTile("📧 Email", "mkavin2005@gmail.com", context),
                _buildInfoTile("📸 Instagram", "i_kavinm", context),
                _buildClickableTile(
                  "💼 LinkedIn",
                  "Kavin M",
                  "https://www.linkedin.com/in/kavin-m--",
                  context,
                ),
                const SizedBox(height: 20),
                // Other Apps Showcase
                _buildOtherAppsSection(context),
                
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.info_outline, color: Colors.blueAccent),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        value,
        style: Tools.h3(context).copyWith(color: Colors.white, fontSize: 18),
      ),
    );
  }

  Widget _buildClickableTile(String label, String value, String url, BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.link, color: Colors.blueAccent),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      subtitle: InkWell(
        onTap: () async {
          await _launchURL(url, context);
        },
        child: Text(
          value,
          style: Tools.h3(context).copyWith(
            color: Colors.blueAccent,
            fontSize: 18,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  // ================= Other Apps Section =================
  Widget _buildOtherAppsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Our Other Apps ",
          style: Tools.h2(context).copyWith(color: Colors.white),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 170,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _appCard(
                context: context,
                title: "MHCDB",
                subtitle: "Madras High Court and Madurai Bench Display Board",
                url: "https://play.google.com/store/apps/details?id=mhc.file.mhcdb&hl=en_IN",
                colour: const Color(0xFF2A5298),
                icon: Icons.gavel,
              ),
              _appCard(
                context: context,
                title: "Legal Desk",
                subtitle: "Smart docs for legal work",
                url: "https://play.google.com/store/apps/details?id=my.legal.desk&hl=en_IN",
                colour:  const Color(0xFF2C5364),
                icon: Icons.gavel,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _appCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String url,
    required Color colour,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async => _launchURL(url, context),
        child: Container(
          width: 240,
          decoration: BoxDecoration(
            // gradient: LinearGradient(
            //   colors: colors,
            //   begin: Alignment.topLeft,
            //   end: Alignment.bottomRight,
            // ),
            color: colour,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: colour.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white.withOpacity(0.15),
                      child: Icon(icon, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Tools.h3(context).copyWith(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Icon(Icons.open_in_new, color: Colors.white70, size: 18),
                    SizedBox(width: 6),
                    Text(
                      "View on Play Store",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchURL(String url, BuildContext context) async {
    try {
      final Uri uri = Uri.parse(url);
      
      // First try to launch with external application mode
      if (await canLaunchUrl(uri)) {
        final bool launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        if (!launched) {
          // If external application fails, try in-app browser
          final bool launchedInApp = await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView,
          );
          
          if (!launchedInApp) {
            _showErrorSnackBar(context, "Could not launch $url");
          }
        }
      } else {
        // If canLaunchUrl returns false, try alternative approach
        final bool launched = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
        
        if (!launched) {
          _showErrorSnackBar(context, "No app found to open $url");
        }
      }
    } catch (e) {
      _showErrorSnackBar(context, "Error launching URL: $e");
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Copy URL',
          textColor: Colors.white,
          onPressed: () {
            // You can add clipboard functionality here if needed
          },
        ),
      ),
    );
  }
}
