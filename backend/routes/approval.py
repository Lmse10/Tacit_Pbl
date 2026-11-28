
from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from auth import get_current_user

router = APIRouter(
    prefix="/approval",
    tags=["Knowledge Approval"]
)

def save_knowledge_version(
    client,
    record,
    user_id,
    change_reason
):
    existing_versions = (
        client.table("knowledge_versions")
        .select("version_number")
        .eq("knowledge_record_id", record["id"])
        .order("version_number", desc=True)
        .limit(1)
        .execute()
    )

    if existing_versions.data:
        next_version = existing_versions.data[0]["version_number"] + 1
    else:
        next_version = 1

    client.table("knowledge_versions").insert({
        "knowledge_record_id": record["id"],
        "version_number": next_version,
        "record_snapshot": record,
        "changed_by": user_id,
        "change_reason": change_reason
    }).execute()


class ApprovalInput(BaseModel):
    status: Literal["approved", "rejected"]


@router.patch("/{record_id}")
def update_knowledge_approval(
    record_id: str,
    approval: ApprovalInput,
    auth_data: dict = Depends(get_current_user)
):
    client = auth_data["client"]
    user = auth_data["user"]
    memberships = auth_data["memberships"]

    owner_business_ids = [
        membership["business_id"]
        for membership in memberships
        if membership["role"] == "owner"
    ]

    if not owner_business_ids:
        raise HTTPException(
            status_code=403,
            detail="Only business owners can approve or reject knowledge"
        )

    try:
        # Find the knowledge record
        record_response = (
            client.table("knowledge_records")
           .select("*")
            .eq("id", record_id)
            .execute()
        )

        if not record_response.data:
            raise HTTPException(
                status_code=404,
                detail="Knowledge record not found"
            )

        record = record_response.data[0]

        if record["business_id"] not in owner_business_ids:
            raise HTTPException(
                status_code=403,
                detail="You cannot modify this business's knowledge"
            )

        if record["verification_status"] != "pending":
            raise HTTPException(
                status_code=400,
                detail="This knowledge record has already been reviewed"
            )

        update_data = {
            "verification_status": approval.status,
            "updated_at": datetime.now(timezone.utc).isoformat()
        }

        if approval.status == "approved":
            update_data["approved_by"] = str(user.id)
            update_data["approved_at"] = datetime.now(
                timezone.utc
            ).isoformat()

        response = (
            client.table("knowledge_records")
            .update(update_data)
            .eq("id", record_id)
            .eq("business_id", record["business_id"])
            .execute()
        )
        if response.data:
           save_knowledge_version(
                client=client,
                record=response.data[0],
                user_id=str(user.id),
                change_reason=f"Knowledge record {approval.status}"
    )

        return {
            "message": f"Knowledge record {approval.status} successfully",
            "record": response.data
        }

    except HTTPException:
        raise
    except Exception as error:
        print("Approval error:", error)
        raise HTTPException(
            status_code=500,
            detail="Unable to update knowledge approval"
        )

@router.get("/history/{record_id}")
def get_knowledge_history(
    record_id: str,
    auth_data: dict = Depends(get_current_user)
):
    client = auth_data["client"]
    memberships = auth_data["memberships"]

    owner_business_ids = [
        membership["business_id"]
        for membership in memberships
        if membership["role"] == "owner"
    ]

    if not owner_business_ids:
        raise HTTPException(
            status_code=403,
            detail="Only business owners can view knowledge history"
        )

    try:
        # Check whether the record belongs to the owner's business
        record_response = (
            client.table("knowledge_records")
            .select("id, business_id")
            .eq("id", record_id)
            .execute()
        )

        if not record_response.data:
            raise HTTPException(
                status_code=404,
                detail="Knowledge record not found"
            )

        record = record_response.data[0]

        if record["business_id"] not in owner_business_ids:
            raise HTTPException(
                status_code=403,
                detail="You cannot view this business's knowledge history"
            )

        # Retrieve all saved versions
        history_response = (
            client.table("knowledge_versions")
            .select("*")
            .eq("knowledge_record_id", record_id)
            .order("version_number", desc=True)
            .execute()
        )

        return {
            "message": "Knowledge history retrieved successfully",
            "history": history_response.data or []
        }

    except HTTPException:
        raise
    except Exception as error:
        print("Knowledge history error:", error)
        raise HTTPException(
            status_code=500,
            detail="Unable to retrieve knowledge history"
        )
