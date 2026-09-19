from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)
root = client.get('/')
health = client.get('/health')
print('ROOT', root.status_code, root.json())
print('HEALTH', health.status_code, health.json())
