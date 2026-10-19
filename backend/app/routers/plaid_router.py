import os
import plaid
from plaid.api import plaid_api
from plaid.model.link_token_create_request import LinkTokenCreateRequest
from plaid.model.link_token_create_request_user import LinkTokenCreateRequestUser
from plaid.model.products import Products
from plaid.model.country_code import CountryCode
from plaid.model.item_public_token_exchange_request import ItemPublicTokenExchangeRequest
from plaid.model.transactions_sync_request import TransactionsSyncRequest
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

router = APIRouter(prefix="/plaid", tags=["plaid"])

configuration = plaid.Configuration(
    host=plaid.Environment.Sandbox,
    api_key={
        "clientId": os.environ["PLAID_CLIENT_ID"],
        "secret": os.environ["PLAID_SECRET"],
    }
)
plaid_client = plaid_api.PlaidApi(plaid.ApiClient(configuration))

# In-memory store for sandbox testing (replace with DB in production)
_access_tokens: dict[int, str] = {}

class ExchangeBody(BaseModel):
    public_token: str


@router.get("/link-token")
async def create_link_token(current_user=Depends(get_current_user)):
    try:
        req = LinkTokenCreateRequest(
            user=LinkTokenCreateRequestUser(client_user_id=str(current_user.id)),
            client_name="Saveup",
            products=[Products("transactions")],
            country_codes=[CountryCode("US")],
            language="en"
        )
        resp = plaid_client.link_token_create(req)
        return {"link_token": resp["link_token"]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/exchange")
async def exchange_token(body: ExchangeBody, current_user=Depends(get_current_user)):
    try:
        resp = plaid_client.item_public_token_exchange(
            ItemPublicTokenExchangeRequest(public_token=body.public_token)
        )
        _access_tokens[current_user.id] = resp["access_token"]
        return {"success": True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/sync")
async def sync_transactions(current_user=Depends(get_current_user), db=Depends(get_db)):
    access_token = _access_tokens.get(current_user.id)
    if not access_token:
        raise HTTPException(status_code=400, detail="No linked bank account. Connect a bank first.")

    try:
        added, cursor, has_more = [], "", True
        while has_more:
            resp = plaid_client.transactions_sync(
                TransactionsSyncRequest(access_token=access_token, cursor=cursor)
            )
            added.extend(resp["added"])
            cursor = resp["next_cursor"]
            has_more = resp["has_more"]

        imported = 0
        for txn in added:
            if txn["amount"] > 0:  # Plaid: positive = money leaving account
                # TODO: replace with your actual DB insert
                # db.execute(...)
                imported += 1

        return {"imported": imported}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
