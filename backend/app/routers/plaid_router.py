import os

import plaid
from fastapi import APIRouter, Depends, HTTPException
from plaid.api import plaid_api
from plaid.model.country_code import CountryCode
from plaid.model.item_public_token_exchange_request import ItemPublicTokenExchangeRequest
from plaid.model.link_token_create_request import LinkTokenCreateRequest
from plaid.model.link_token_create_request_user import LinkTokenCreateRequestUser
from plaid.model.products import Products
from plaid.model.transactions_sync_request import TransactionsSyncRequest
from pydantic import BaseModel
from sqlalchemy.orm import Session

from .. import models
from ..auth import get_current_user
from ..database import get_db

router = APIRouter(prefix="/plaid", tags=["plaid"])

_plaid_client: plaid_api.PlaidApi | None = None

def _get_client() -> plaid_api.PlaidApi:
    global _plaid_client
    if _plaid_client is None:
        config = plaid.Configuration(
            host=plaid.Environment.Sandbox,
            api_key={
                "clientId": os.environ["PLAID_CLIENT_ID"],
                "secret": os.environ["PLAID_SECRET"],
            }
        )
        _plaid_client = plaid_api.PlaidApi(plaid.ApiClient(config))
    return _plaid_client

_access_tokens: dict[int, str] = {}


class ExchangeBody(BaseModel):
    public_token: str


@router.get("/link-token")
def create_link_token(user: models.User = Depends(get_current_user)):
    try:
        req = LinkTokenCreateRequest(
            user=LinkTokenCreateRequestUser(client_user_id=str(user.id)),
            client_name="Saveup",
            products=[Products("transactions")],
            country_codes=[CountryCode("US")],
            language="en"
        )
        resp = _get_client().link_token_create(req)
        return {"link_token": resp["link_token"]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/exchange")
def exchange_token(
    body: ExchangeBody,
    user: models.User = Depends(get_current_user),
):
    try:
        resp = _get_client().item_public_token_exchange(
            ItemPublicTokenExchangeRequest(public_token=body.public_token)
        )
        _access_tokens[user.id] = resp["access_token"]
        return {"success": True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sync")
def sync_transactions(
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    access_token = _access_tokens.get(user.id)
    if not access_token:
        raise HTTPException(status_code=400, detail="No linked bank account. Connect a bank first.")

    account = db.query(models.Account).filter(models.Account.user_id == user.id).first()
    if not account:
        raise HTTPException(status_code=400, detail="Add an account in Saveup before syncing.")

    try:
        added, cursor, has_more = [], "", True
        while has_more:
            resp = _get_client().transactions_sync(
                TransactionsSyncRequest(access_token=access_token, cursor=cursor)
            )
            added.extend(resp["added"])
            cursor = resp["next_cursor"]
            has_more = resp["has_more"]

        imported = 0
        for txn in added:
            if txn["amount"] <= 0:
                continue

            txn_date = txn["date"]
            if hasattr(txn_date, "isoformat"):
                txn_date = txn_date.isoformat()

            new_txn = models.Transaction(
                account_id=account.id,
                user_id=user.id,
                description=txn.get("merchant_name") or txn.get("name") or "Unknown",
                amount=float(txn["amount"]),
                category=_map_category(txn.get("category") or []),
                date=txn_date,
            )
            db.add(new_txn)
            imported += 1

        db.commit()
        return {"imported": imported}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))


def _map_category(plaid_categories: list[str]) -> str:
    joined = " ".join(c.lower() for c in plaid_categories)
    if "food" in joined or "restaurant" in joined or "dining" in joined:
        return "Food & Dining"
    if "travel" in joined or "airline" in joined or "hotel" in joined:
        return "Travel"
    if "transport" in joined or "taxi" in joined or "uber" in joined or "lyft" in joined:
        return "Transportation"
    if "shops" in joined or "shopping" in joined:
        return "Shopping"
    if "entertainment" in joined or "recreation" in joined:
        return "Entertainment"
    if "health" in joined or "medical" in joined or "pharmacy" in joined:
        return "Medical"
    if "gym" in joined or "fitness" in joined:
        return "Fitness"
    if "subscription" in joined or "software" in joined:
        return "Subscriptions"
    return "Miscellaneous"
