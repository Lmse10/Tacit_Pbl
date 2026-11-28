
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from supabase import create_client

from database import SUPABASE_URL, SUPABASE_KEY, get_supabase_client


security = HTTPBearer()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Verify the user's Supabase access token and retrieve
    their business memberships.
    """

    token = credentials.credentials

    try:
        # Verify the access token with Supabase Auth
        auth_client = create_client(
            SUPABASE_URL,
            SUPABASE_KEY
        )

        response = auth_client.auth.get_user(token)

        if not response or not response.user:
            raise HTTPException(
                status_code=401,
                detail="Invalid or expired access token"
            )

        user = response.user

        # Create a database client using this user's token
        user_client = get_supabase_client(token)

        # Find the businesses this user belongs to
        membership_response = (
            user_client
            .table("business_members")
            .select("business_id, role")
            .eq("user_id", str(user.id))
            .execute()
        )

        memberships = membership_response.data or []

        if not memberships:
            raise HTTPException(
                status_code=403,
                detail="You are not a member of any registered business"
            )

        return {
            "user": user,
            "client": user_client,
            "memberships": memberships
        }

    except HTTPException:
        raise

    except Exception as error:
        print("Authentication error:", error)

        raise HTTPException(
            status_code=401,
            detail="Authentication failed. Please log in again."
        )
