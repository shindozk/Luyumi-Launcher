import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/news_item.dart';
import '../animations.dart';

class NewsSection extends StatelessWidget {
  final Future<List<NewsItem>> newsFuture;

  const NewsSection({super.key, required this.newsFuture});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('news_title'),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: FutureBuilder<List<NewsItem>>(
              future: newsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text(
                    tr('news_empty'),
                    style: const TextStyle(color: Colors.white54),
                  );
                }

                final newsList = snapshot.data!.take(3).toList();

                return Row(
                  children: newsList
                      .map(
                        (news) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 24),
                            child: _buildNewsCard(news),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsCard(NewsItem news) {
    return ScaleOnHover(
      scale: 1.02,
      child: InkWell(
        onTap: () async {
          final uri = Uri.parse(news.url);
          if (await canLaunchUrl(uri)) await launchUrl(uri);
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF18181B).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: news.imageUrl.isNotEmpty
                    ? Image.network(
                        news.imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: news.color.withValues(alpha: 0.1),
                          child: Center(
                            child: Icon(
                              Icons.article_outlined,
                              size: 48,
                              color: news.color,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: news.color.withValues(alpha: 0.1),
                        child: Center(
                          child: Icon(
                            Icons.article_outlined,
                            size: 48,
                            color: news.color,
                          ),
                        ),
                      ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        news.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          news.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        news.date,
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
