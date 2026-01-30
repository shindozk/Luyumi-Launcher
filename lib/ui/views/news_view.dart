import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/news_item.dart';
import '../../core/services/news_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/utils/logger.dart';
import '../widgets/animations.dart';

class NewsView extends StatefulWidget {
  const NewsView({super.key});

  @override
  State<NewsView> createState() => _NewsViewState();
}

class _NewsViewState extends State<NewsView> {
  final NewsService _newsService = NewsService();
  late Future<List<NewsItem>> _newsFuture;

  @override
  void initState() {
    super.initState();
    Logger.info('NewsView.initState() - Starting news fetch');
    _newsFuture = _newsService.fetchNews().then((news) {
      Logger.info('NewsView.initState() - Received ${news.length} news items');
      // If no news on first load, retry after 2 seconds
      if (news.isEmpty) {
        Logger.warning('NewsView.initState() - No news received, will retry');
        return Future.delayed(const Duration(seconds: 2)).then((_) {
          Logger.info('NewsView.initState() - Retrying news fetch');
          return _newsService.fetchNews();
        });
      }
      return news;
    });
  }

  Future<void> _refreshNews() async {
    Logger.info('NewsView - Manual refresh triggered');
    setState(() {
      _newsFuture = _newsService.fetchNews();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: FutureBuilder<List<NewsItem>>(
            future: _newsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Theme.of(context).primaryColor),
                      const SizedBox(height: 16),
                      Text(
                        'Loading latest news...',
                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }
              
              if (snapshot.hasError) {
                Logger.error('NewsView - Error loading news: ${snapshot.error}');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load news',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _refreshNews,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                Logger.info('NewsView - No news data available');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.newspaper_outlined, color: Colors.white54, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        tr('news_empty'),
                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _refreshNews,
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                );
              }

              return FadeInEntry(
                delay: const Duration(milliseconds: 100),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 0),
                  itemCount: snapshot.data!.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final news = snapshot.data![index];
                    return FadeInEntry(
                      delay: Duration(milliseconds: 100 * index),
                      child: _buildNewsCard(news),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.article, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(width: 16),
          Text(
            tr('news_title'),
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: tr('update'),
            onPressed: _refreshNews,
            style: IconButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              padding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsCard(NewsItem news) {
    return ScaleOnHover(
      scale: 1.01,
      child: InkWell(
        onTap: () async {
          AudioService().playClick();
          final uri = Uri.parse(news.url);
          if (await canLaunchUrl(uri)) await launchUrl(uri);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (news.imageUrl.isNotEmpty)
                  SizedBox(
                    width: 140,
                    child: Image.network(
                      news.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                         return Container(color: news.color.withValues(alpha: 0.2), child: const Icon(Icons.broken_image, color: Colors.white24));
                      },
                    ),
                  )
                else
                  Container(
                    width: 8,
                    color: news.color,
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: news.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                news.tag.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: news.color,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              news.date,
                              style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          news.title,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          news.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
