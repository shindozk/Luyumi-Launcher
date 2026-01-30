import requests
from .LoggerService import LoggerService

class NewsService:
    NEWS_URL = 'https://launcher.hytale.com/launcher-feed/release/feed.json'
    
    @staticmethod
    def get_hytale_news():
        try:
            LoggerService.info(f"Fetching news from {NewsService.NEWS_URL}")
            
            response = requests.get(
                NewsService.NEWS_URL,
                headers={
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                    'Accept': 'application/json'
                },
                timeout=10
            )
            
            if response.status_code != 200:
                LoggerService.warning(f"News API returned status {response.status_code}")
                return []
            
            data = response.json()
            articles = data.get('articles', [])
            LoggerService.info(f"Received {len(articles)} articles from Hytale")
            
            result = []
            for article in articles:
                image_url = article.get('image_url', '')
                if image_url and not image_url.startswith('http'):
                    image_url = f"https://launcher.hytale.com/launcher-feed/release/{image_url}"
                
                result.append({
                    "title": article.get('title', ''),
                    "description": article.get('description', ''),
                    "destUrl": article.get('dest_url', ''),
                    "imageUrl": image_url,
                    "date": article.get('published_at', ''),
                    "tag": "News"
                })
            
            LoggerService.info(f"Processed {len(result)} news articles")
            return result
            
        except requests.exceptions.Timeout:
            LoggerService.error("News API request timed out")
            return []
        except requests.exceptions.RequestException as e:
            LoggerService.error(f"News API request failed: {e}")
            return []
        except Exception as e:
            LoggerService.error(f"Failed to parse news: {e}")
            import traceback
            LoggerService.error(traceback.format_exc())
            return []
