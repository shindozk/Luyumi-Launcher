import '../services/backend_service.dart';
import '../utils/logger.dart';
import '../models/news_item.dart';

class NewsService {
  Future<List<NewsItem>> fetchNews() async {
    try {
      Logger.info('NewsService.fetchNews() called');
      final articles = await BackendService.getNews();
      Logger.info('Backend returned ${articles.length} articles');
      
      if (articles.isEmpty) {
        Logger.warning('No articles received from backend');
        return [];
      }
      
      final newsList = articles.map((json) {
        Logger.info('Processing article: ${json['title']}');
        return NewsItem(
          title: json['title'] ?? 'No Title',
          date: json['date'] ?? 'Recent',
          description: json['description'] ?? '',
          imageUrl: json['imageUrl'] ?? '',
          url: json['destUrl'] ?? '',
          tag: json['tag'] ?? 'News',
        );
      }).toList();
      
      Logger.info('Successfully created ${newsList.length} NewsItem objects');
      return newsList;
    } catch (e, stack) {
      Logger.error('Error fetching news from backend: $e');
      Logger.error('Stack trace: $stack');
      return [];
    }
  }
}
