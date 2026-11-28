from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from auth import get_current_user
from typing import Optional


router = APIRouter(
    prefix="/knowledge",
    tags=["Knowledge"]
)


class KnowledgeSubmission(BaseModel):
    source_type: str = "text"
    raw_text: str


@router.post("/submit")
def submit_knowledge(
    submission: KnowledgeSubmission,
    auth_data: dict = Depends(get_current_user)
):
    user = auth_data["user"]
    client = auth_data["client"]
    memberships = auth_data["memberships"]

    # Only business owners can submit knowledge
    owner_memberships = [
        membership
        for membership in memberships
        if membership["role"] == "owner"
    ]

    if not owner_memberships:
        raise HTTPException(
            status_code=403,
            detail="Only business owners can submit knowledge"
        )

    business_id = owner_memberships[0]["business_id"]

    try:
        response = (
            client
            .table("knowledge_sources")
            .insert({
                "business_id": business_id,
                "submitted_by": str(user.id),
                "source_type": submission.source_type,
                "raw_text": submission.raw_text
            })
            .execute()
        )

        return {
            "message": "Knowledge submitted successfully",
            "source": response.data
        }

    except Exception as error:
        print("Knowledge submission error:", error)
        raise HTTPException(
            status_code=500,
            detail="Unable to submit knowledge"
        )

class KnowledgeRecordInput(BaseModel):
    source_id: str
    category: Optional[str] = None
    title: Optional[str] = None
    decision: Optional[str] = None
    reason: Optional[str] = None
    condition_text: Optional[str] = None
    exception_text: Optional[str] = None
    previous_experience: Optional[str] = None
    risk: Optional[str] = None
    advice: Optional[str] = None
    related_entity: Optional[str] = None


class KnowledgeRecordUpdate(BaseModel):
    category: Optional[str] = None
    title: Optional[str] = None
    decision: Optional[str] = None
    reason: Optional[str] = None
    condition_text: Optional[str] = None
    exception_text: Optional[str] = None
    previous_experience: Optional[str] = None
    risk: Optional[str] = None
    advice: Optional[str] = None
    related_entity: Optional[str] = None
    change_reason: str


@router.post("/records")
def create_knowledge_record(
    record: KnowledgeRecordInput,
    auth_data: dict = Depends(get_current_user)
):
    client = auth_data["client"]
    memberships = auth_data["memberships"]

    owner_memberships = [
        membership
        for membership in memberships
        if membership["role"] == "owner"
    ]

    if not owner_memberships:
        raise HTTPException(
            status_code=403,
            detail="Only business owners can create knowledge records"
        )

    business_id = owner_memberships[0]["business_id"]

    try:
        source_response = (
            client.table("knowledge_sources")
            .select("id")
            .eq("id", record.source_id)
            .eq("business_id", business_id)
            .execute()
        )

        if not source_response.data:
            raise HTTPException(
                status_code=404,
                detail="Knowledge source not found"
            )

        record_data = record.model_dump(exclude={"source_id"})
        record_data.update({
            "business_id": business_id,
            "source_id": record.source_id,
            "verification_status": "pending"
        })

        response = (
            client.table("knowledge_records")
            .insert(record_data)
            .execute()
        )

        return {
            "message": "Knowledge record created successfully",
            "record": response.data
        }

    except HTTPException:
        raise
    except Exception as error:
        print("Knowledge record error:", error)
        raise HTTPException(
            status_code=500,
            detail="Unable to create knowledge record"
        )

@router.get("/approved")
def get_approved_knowledge(
    auth_data: dict = Depends(get_current_user)
):
    client = auth_data["client"]
    memberships = auth_data["memberships"]

    business_ids = [
        membership["business_id"]
        for membership in memberships
    ]

    try:
        response = (
            client.table("knowledge_records")
            .select("*")
            .in_("business_id", business_ids)
            .eq("verification_status", "approved")
            .order("created_at", desc=True)
            .execute()
        )

        return {
            "message": "Approved knowledge retrieved successfully",
            "records": response.data or []
        }

    except Exception as error:
        print("Knowledge retrieval error:", error)
        raise HTTPException(
            status_code=500,
            detail="Unable to retrieve approved knowledge"
        )

@router.put("/records/{record_id}")
def update_knowledge_record(
    record_id: str,
    update: KnowledgeRecordUpdate,
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
            detail="Only business owners can edit knowledge records"
        )

    try:
        # Find the existing record
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

        old_record = record_response.data[0]

        if old_record["business_id"] not in owner_business_ids:
            raise HTTPException(
                status_code=403,
                detail="You cannot edit this business's knowledge"
            )

        # Prepare the updated fields
        update_data = update.model_dump(
            exclude={"change_reason"},
            exclude_unset=True
        )

        update_data["updated_at"] = datetime.now(
            timezone.utc
        ).isoformat()

        # Update the record
        response = (
            client.table("knowledge_records")
            .update(update_data)
            .eq("id", record_id)
            .eq("business_id", old_record["business_id"])
            .execute()
        )

        if not response.data:
            raise HTTPException(
                status_code=500,
                detail="Knowledge record could not be updated"
            )

        updated_record = response.data[0]

        # Find the latest version number
        version_response = (
            client.table("knowledge_versions")
            .select("version_number")
            .eq("knowledge_record_id", record_id)
            .order("version_number", desc=True)
            .limit(1)
            .execute()
        )

        if version_response.data:
            next_version = (
                version_response.data[0]["version_number"] + 1
            )
        else:
            next_version = 1

        # Save the updated snapshot
        client.table("knowledge_versions").insert({
            "knowledge_record_id": record_id,
            "version_number": next_version,
            "record_snapshot": updated_record,
            "changed_by": str(user.id),
            "change_reason": update.change_reason
        }).execute()

        return {
            "message": "Knowledge record updated successfully",
            "record": updated_record,
            "version_number": next_version
        }

    except HTTPException:
        raise
    except Exception as error:
        print("Knowledge update error:", error)
        raise HTTPException(
            status_code=500,
            detail="Unable to update knowledge record"
        )
