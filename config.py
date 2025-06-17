import os

class Config:
    # MongoDB Configuration
    MONGO_URI = os.getenv('MONGO_URI', 'mongodb://localhost:27017/')
    
    # API Security
    API_KEY = os.getenv('API_KEY', 'change_this_in_production')
    
    # Flask Configuration
    DEBUG = os.getenv('DEBUG', 'True').lower() == 'true'
    
    # Umbral Configuration
    THRESHOLD = int(os.getenv('THRESHOLD', '1'))
    N_SHARES = int(os.getenv('N_SHARES', '1'))