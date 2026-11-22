# TACIT – AI-Powered Business Knowledge Preservation System

## About the Project
TACIT is an AI-powered knowledge preservation system designed to capture, organise and preserve undocumented business knowledge, including business decisions, reasoning, rules, exceptions and experiences.

It aims to help successors access valuable knowledge through natural-language queries and contextual AI-generated explanations.

## Current Progress
- Supabase project created.
- PostgreSQL database configured.
- Five core database tables created:
  - businesses
  - business_members
  - knowledge_sources
  - knowledge_records
  - knowledge_versions
- User authentication configured.
- Row Level Security policies established.
- Sample business knowledge inserted.
- Database schema captured using Supabase migrations.

## Technology Stack
- Database: Supabase (PostgreSQL)
- Authentication: Supabase Auth
- Storage: Supabase Storage
- Backend: Python / FastAPI (planned)
- Frontend: React (planned)
- AI: Existing LLM API (planned)

## Project Structure
- `supabase/`: Supabase configuration and database migrations.
- `database/`: Additional database documentation and sample data.
- `docs/`: Project documentation.

## Getting Started
1. Clone this repository.
2. Install the Supabase CLI.
3. Configure your own Supabase project.
4. Apply the database migrations to your development database.
5. Refer to the documentation before modifying the database.

## Team Collaboration
All database structure changes should be documented through Supabase migration files and committed to GitHub.