from fastapi import APIRouter
from ..services.NewsService import NewsService
from ..services.LoggerService import LoggerService

router = APIRouter(prefix="/api")

@router.get("/news")
def get_news():
    try:
        LoggerService.info("Fetching Hytale news...")
        news = NewsService.get_hytale_news()
        LoggerService.info(f"Retrieved {len(news)} news articles")
        return news
    except Exception as e:
        LoggerService.error(f"Failed to fetch news: {e}")
        import traceback
        LoggerService.error(traceback.format_exc())
        return []
