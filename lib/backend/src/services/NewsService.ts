export class NewsService {
  static async getHytaleNews() {
    try {
      const response = await fetch('https://launcher.hytale.com/launcher-feed/release/feed.json', {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
      });
      
      if (!response.ok) throw new Error('Failed to fetch news');

      const data = await response.json() as any;
      const articles = data.articles || [];
      
      return articles.map((article: any) => ({
        title: article.title || '',
        description: article.description || '',
        destUrl: article.dest_url || '',
        imageUrl: article.image_url ? 
          (article.image_url.startsWith('http') ? 
            article.image_url : 
            `https://launcher.hytale.com/launcher-feed/release/${article.image_url}`
          ) : '',
        date: article.published_at || '',
        tag: 'News'
      }));
    } catch (error: any) {
      console.error('Failed to fetch news:', error.message);
      return [];
    }
  }
}
