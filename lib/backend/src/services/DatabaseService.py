import os
import hashlib
from datetime import datetime
from pymongo import MongoClient
from pymongo.errors import PyMongoError, DuplicateKeyError
from .LoggerService import LoggerService

class DatabaseService:
    """MongoDB Database Service for user authentication and profile management"""
    
    _instance = None
    _client = None
    _db = None
    _users_collection = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(DatabaseService, cls).__new__(cls)
        return cls._instance
    
    @classmethod
    def init(cls):
        """Initialize MongoDB connection"""
        if cls._db is not None:
            return True
        
        try:
            mongo_uri = os.environ.get('MONGO_URI')
            if not mongo_uri or mongo_uri.strip() == '':
                LoggerService.warning("[DatabaseService] MONGO_URI not found in environment")
                return False
            
            LoggerService.info("[DatabaseService] Connecting to MongoDB...")
            cls._client = MongoClient(mongo_uri, serverSelectionTimeoutMS=5000)
            
            # Test connection
            cls._client.admin.command('ping')
            
            # Get database
            cls._db = cls._client.get_database()
            cls._users_collection = cls._db['users']
            
            # Create index on username and email for faster queries
            cls._users_collection.create_index('username', unique=True)
            cls._users_collection.create_index('email', unique=True)
            
            LoggerService.info("[DatabaseService] Connected to MongoDB successfully")
            return True
            
        except Exception as e:
            LoggerService.error(f"[DatabaseService] MongoDB Connection Error: {e}")
            return False
    
    @classmethod
    def _hash_password(cls, password: str) -> str:
        """Hash password using SHA256"""
        return hashlib.sha256(password.encode()).hexdigest()
    
    @classmethod
    def login(cls, username: str, password: str) -> dict:
        """
        Authenticate user with username and password
        
        Args:
            username: User's username
            password: User's password
            
        Returns:
            User document if authentication successful, None otherwise
        """
        try:
            if cls._users_collection is None:
                if not cls.init():
                    return None
            
            if cls._users_collection is None:
                return None
            
            hashed_password = cls._hash_password(password)
            user = cls._users_collection.find_one({
                'username': username,
                'password': hashed_password
            })
            
            if user:
                # Ensure user has a persistent hytaleUuid for skin continuity
                if 'hytaleUuid' not in user:
                    import uuid as uuid_pkg
                    generated_uuid = str(uuid_pkg.uuid4())
                    cls._users_collection.update_one(
                        {'_id': user['_id']},
                        {'$set': {'hytaleUuid': generated_uuid}}
                    )
                    user['hytaleUuid'] = generated_uuid
                    LoggerService.info(f"[DatabaseService] Generated new hytaleUuid for '{username}': {generated_uuid}")

                LoggerService.info(f"[DatabaseService] User '{username}' logged in successfully")
                # Remove password hash from response
                user.pop('password', None)
                if '_id' in user:
                    user['_id'] = str(user['_id'])
                return user
            
            LoggerService.warning(f"[DatabaseService] Login failed for user '{username}'")
            return None
            
        except Exception as e:
            LoggerService.error(f"[DatabaseService] Login Error: {e}")
            return None
    
    @classmethod
    def register(cls, username: str, email: str, password: str) -> dict:
        """
        Register new user
        
        Args:
            username: Desired username
            email: User's email
            password: User's password
            
        Returns:
            {'success': True, 'message': '...'} or {'success': False, 'error': '...'}
        """
        try:
            if cls._users_collection is None:
                if not cls.init():
                    return {'success': False, 'error': 'Database not available'}
            
            if cls._users_collection is None:
                return {'success': False, 'error': 'Database not available'}
            
            # Check if user already exists
            existing = cls._users_collection.find_one({
                '$or': [
                    {'username': username},
                    {'email': email}
                ]
            })
            
            if existing:
                return {'success': False, 'error': 'Username or email already exists'}
            
            # Hash password
            hashed_password = cls._hash_password(password)
            
            # Create user document
            import uuid as uuid_pkg
            user_doc = {
                'username': username,
                'email': email,
                'password': hashed_password,
                'hytaleUuid': str(uuid_pkg.uuid4()),
                'createdAt': datetime.utcnow().isoformat(),
                'avatarUrl': None,
                'bio': 'Hello! I am playing Luyumi Launcher.',
                'updatedAt': datetime.utcnow().isoformat()
            }
            
            # Insert user
            result = cls._users_collection.insert_one(user_doc)
            
            LoggerService.info(f"[DatabaseService] User '{username}' registered successfully")
            return {'success': True, 'message': 'Registration successful', 'userId': str(result.inserted_id)}
            
        except DuplicateKeyError:
            return {'success': False, 'error': 'Username or email already exists'}
        except PyMongoError as e:
            LoggerService.error(f"[DatabaseService] Database Error during registration: {e}")
            return {'success': False, 'error': f'Database error: {str(e)}'}
        except Exception as e:
            LoggerService.error(f"[DatabaseService] Register Error: {e}")
            return {'success': False, 'error': 'Registration failed'}
    
    @classmethod
    def get_user(cls, username: str) -> dict:
        """
        Get user by username
        
        Args:
            username: Username to search for
            
        Returns:
            User document or None
        """
        try:
            if cls._users_collection is None:
                if not cls.init():
                    return None
            
            if cls._users_collection is None:
                return None
            
            user = cls._users_collection.find_one({'username': username})
            if user:
                # Remove password hash
                user.pop('password', None)
            return user
            
        except Exception as e:
            LoggerService.error(f"[DatabaseService] Get User Error: {e}")
            return None

    @classmethod
    def get_user_by_uuid(cls, user_uuid: str) -> dict:
        """Get user by Hytale UUID"""
        try:
            if cls._users_collection is None:
                if not cls.init():
                    return None
            
            if cls._users_collection is None:
                return None
            
            user = cls._users_collection.find_one({'hytaleUuid': user_uuid})
            return user
        except Exception as e:
            LoggerService.error(f"[DatabaseService] Get User by UUID Error: {e}")
            return None
    
    @classmethod
    def update_bio(cls, username: str, bio: str) -> dict:
        """
        Update user bio
        
        Args:
            username: Username
            bio: New bio text
            
        Returns:
            {'success': True/False, 'message': '...'}
        """
        try:
            if cls._users_collection is None:
                if not cls.init():
                    return {'success': False, 'error': 'Database not available'}
            
            if cls._users_collection is None:
                return {'success': False, 'error': 'Database not available'}
            
            result = cls._users_collection.update_one(
                {'username': username},
                {
                    '$set': {
                        'bio': bio,
                        'updatedAt': datetime.utcnow().isoformat()
                    }
                }
            )
            
            if result.matched_count == 0:
                return {'success': False, 'error': 'User not found'}
            
            LoggerService.info(f"[DatabaseService] Bio updated for user '{username}'")
            return {'success': True, 'message': 'Bio updated'}
            
        except Exception as e:
            LoggerService.error(f"[DatabaseService] Update Bio Error: {e}")
            return {'success': False, 'error': 'Failed to update bio'}
    
    @classmethod
    def update_avatar(cls, username: str, avatar_url: str) -> dict:
        """
        Update user avatar URL
        
        Args:
            username: Username
            avatar_url: New avatar URL
            
        Returns:
            {'success': True/False, 'message': '...'}
        """
        try:
            if cls._users_collection is None:
                if not cls.init():
                    return {'success': False, 'error': 'Database not available'}
            
            if cls._users_collection is None:
                return {'success': False, 'error': 'Database not available'}
            
            result = cls._users_collection.update_one(
                {'username': username},
                {
                    '$set': {
                        'avatarUrl': avatar_url,
                        'updatedAt': datetime.utcnow().isoformat()
                    }
                }
            )
            
            if result.matched_count == 0:
                return {'success': False, 'error': 'User not found'}
            
            LoggerService.info(f"[DatabaseService] Avatar updated for user '{username}'")
            return {'success': True, 'message': 'Avatar updated'}
            
        except Exception as e:
            LoggerService.error(f"[DatabaseService] Update Avatar Error: {e}")
            return {'success': False, 'error': 'Failed to update avatar'}
    
    @classmethod
    def close(cls):
        """Close MongoDB connection"""
        try:
            if cls._client:
                cls._client.close()
                cls._db = None
                cls._users_collection = None
                LoggerService.info("[DatabaseService] MongoDB connection closed")
        except Exception as e:
            LoggerService.error(f"[DatabaseService] Error closing connection: {e}")
