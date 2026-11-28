
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routes import business, knowledge, approval, chatbot

app = FastAPI(
    title="TACIT API",
    description="Business Knowledge Preservation and Retrieval System",
    version="1.0.0"
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

# Home route
@app.get("/")
def home():
    return {
        "message": "Welcome to TACIT Backend"
    }

# Health check
@app.get("/health")
def health_check():
    return {
        "status": "healthy"
    }

# Register all route modules
app.include_router(business.router)
app.include_router(knowledge.router)
app.include_router(approval.router)
app.include_router(chatbot.router)
