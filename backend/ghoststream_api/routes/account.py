from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as DBSession

from ..db import get_session
from ..routes.auth import current_session
from ..schemas import DeleteAccountRequest
from ..services.auth_service import AuthContext
from ..services.deletion_service import delete_account

account_router = APIRouter(prefix='/api/v1/account', tags=['account'])
delete_router = APIRouter(prefix='/api/v1/deletion', tags=['deletion'])


@account_router.get('/state')
def account_state(context: AuthContext = Depends(current_session)) -> dict:
    return {
        'state': 'active',
        'account_id': str(context.user.id),
        'email': context.user.email,
        'email_verified': context.user.email_verified,
    }


@delete_router.post('/account')
def delete_my_account(
    payload: DeleteAccountRequest,
    context: AuthContext = Depends(current_session),
    db: DBSession = Depends(get_session),
) -> dict:
    delete_account(db, context.user.id)
    return {'deleted': True}
