import '../services/backend_service.dart';
import '../utils/logger.dart';
import '../models/news_item.dart';

class NewsService {
  Future<List<NewsItem>> fetchNews() async {
    try {
      final articles = await BackendService.getNews();
      return articles.map((json) => NewsItem(
        title: json['title'] ?? 'No Title',
        date: json['date'] ?? 'Recent',
        description: json['description'] ?? '',
        imageUrl: json['imageUrl'] ?? '',
        url: json['destUrl'] ?? '',
        tag: json['tag'] ?? 'News',
      )).toList();
    } catch (e) {
      Logger.error('Error fetching news from backend: $e');
      return [
        NewsItem(
          title: 'Welcome to Luyumi',
          date: 'Now',
          description: 'Backend might be offline.',
          imageUrl: '',
          url: 'https://hytale.com/news',
          tag: 'System',
        ),
      ];
    }
  }
}
