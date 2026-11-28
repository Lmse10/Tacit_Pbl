
from fastapi import APIRouter, Depends, HTTPException

from auth import get_current_user

router = APIRouter(
    prefix="/business",
    tags=["Business"]
)


@router.get("/profile")
def get_business_profile(
    auth_data: dict = Depends(get_current_user)
):
    """
    Fetch the business details associated with
    the currently authenticated user.
    """

    client = auth_data["client"]
    memberships = auth_data["memberships"]

    business_ids = [
        membership["business_id"]
        for membership in memberships
    ]

    try:
        response = (
            client
            .table("businesses")
            .select(
                "id, name, business_type, description, created_at"
            )
            .in_("id", business_ids)
            .execute()
        )

        businesses = response.data or []

        # Match each business with the user's role
        membership_roles = {
            membership["business_id"]: membership["role"]
            for membership in memberships
        }

        result = []

        for business in businesses:
            business["role"] = membership_roles.get(
                business["id"]
            )
            result.append(business)

        return {
            "message": "Business profile retrieved successfully",
            "businesses": result
        }

    except Exception as error:
        print("Business profile error:", error)

        raise HTTPException(
            status_code=500,
            detail="Unable to retrieve business profile"
        )
