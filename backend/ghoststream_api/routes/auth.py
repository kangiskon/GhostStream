from __future__ import annotations

import smtplib
import uuid
from email.message import EmailMessage

from fastapi import APIRouter, Depends, HTTPException, Response, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import InvalidTokenError
from sqlalchemy import select
from sqlalchemy.orm import Session as DBSession

from ..config import get_settings
from ..db import get_session
from ..models import Device, Session, User
from ..schemas import (
    AppleAuthRequest,
    ChangePasswordRequest,
    EmailTokenRequest,
    ForgotPasswordRequest,
    LoginRequest,
    LogoutRequest,
    RefreshRequest,
    RegisterRequest,
    ResetPasswordRequest,
    TokenPair,
)
from ..security import decode_access_token, hash_password
from ..services.apple_auth import AppleAuthError, verify_apple_identity_token
from ..services.auth_service import (
    AuthContext,
    AuthError,
    authenticate_password,
    change_password,
    consume_email_action,
    issue_email_action,
    issue_session,
    reset_password,
    revoke_refresh_token,
    rotate_refresh_token,
    upsert_device,
)

router = APIRouter(prefix='/api/v1/auth', tags=['auth'])
bearer = HTTPBearer(auto_error=False)


def _send_email(to: str, subject: str, body: str) -> None:
    settings = get_settings()
    if not settings.smtp_host:
        return
    message = EmailMessage()
    message['From'] = settings.smtp_from
    message['To'] = to
    message['Subject'] = subject
    message.set_content(body)
    with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=10) as smtp:
        smtp.starttls()
        if settings.smtp_username:
            smtp.login(settings.smtp_username, settings.smtp_password)
        smtp.send_message(message)


def send_verification_email(email: str, token: str) -> None:
    base = get_settings().public_web_base_url.rstrip('/')
    _send_email(email, 'Verify your GhostStream account', f'Verify your email: {base}/verify-email/?token={token}')


def send_reset_email(email: str, token: str) -> None:
    base = get_settings().public_web_base_url.rstrip('/')
    _send_email(email, 'Reset your GhostStream password', f'Reset your password: {base}/reset-password/?token={token}')


def _auth_http_error(error: AuthError) -> HTTPException:
    code = status.HTTP_401_UNAUTHORIZED
    if error.code == 'device_owned_by_other_account':
        code = status.HTTP_409_CONFLICT
    if error.code == 'account_deleted':
        code = status.HTTP_410_GONE
    return HTTPException(status_code=code, detail={'code': error.code, 'message': error.message})


def current_session(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: DBSession = Depends(get_session),
) -> AuthContext:
    if credentials is None:
        raise HTTPException(status_code=401, detail={'code': 'missing_token'})
    try:
        claims = decode_access_token(credentials.credentials)
        session_id = uuid.UUID(claims['session_id'])
        user_id = uuid.UUID(claims['sub'])
        device_id = uuid.UUID(claims['device_id'])
    except (InvalidTokenError, KeyError, ValueError):
        raise HTTPException(status_code=401, detail={'code': 'invalid_token'})
    session = db.get(Session, session_id)
    user = db.get(User, user_id)
    device = db.get(Device, device_id)
    if (
        session is None or user is None or device is None or
        session.user_id != user.id or session.device_id != device.id or
        session.revoked_at is not None or device.revoked_at is not None
    ):
        raise HTTPException(status_code=401, detail={'code': 'invalid_session'})
    if user.deletion_started_at is not None:
        raise HTTPException(status_code=410, detail={'code': 'account_deleted'})
    return AuthContext(user=user, device=device, session=session)


@router.post('/register', status_code=201)
def register(payload: RegisterRequest, db: DBSession = Depends(get_session)) -> dict:
    if db.scalar(select(User).where(User.email == payload.email)) is not None:
        raise HTTPException(status_code=409, detail={'code': 'email_in_use'})
    user = User(email=str(payload.email), password_hash=hash_password(payload.password))
    db.add(user)
    db.flush()
    try:
        upsert_device(
            db,
            user_id=user.id,
            device_id=payload.device_id,
            display_name=payload.display_name,
            platform=payload.platform,
            os_version=payload.os_version,
            public_key=payload.public_key,
        )
    except AuthError as error:
        db.rollback()
        raise _auth_http_error(error)
    db.commit()
    token = issue_email_action(db, user.id, 'verify_email', lifetime_minutes=60)
    send_verification_email(user.email, token)
    return {'verification_required': True}


@router.post('/verify-email')
def verify_email(payload: EmailTokenRequest, db: DBSession = Depends(get_session)) -> dict:
    try:
        consume_email_action(db, payload.token, 'verify_email')
        db.commit()
    except AuthError as error:
        db.rollback()
        raise _auth_http_error(error)
    return {'verified': True}


@router.post('/login', response_model=TokenPair)
def login(payload: LoginRequest, db: DBSession = Depends(get_session)) -> TokenPair:
    try:
        user = authenticate_password(db, str(payload.email), payload.password)
        device = upsert_device(
            db,
            user_id=user.id,
            device_id=payload.device_id,
            display_name=payload.display_name,
            platform=payload.platform,
            os_version=payload.os_version,
            public_key=payload.public_key,
        )
        pair = issue_session(db, user.id, device.id)
        db.commit()
        return pair
    except AuthError as error:
        db.rollback()
        raise _auth_http_error(error)


@router.post('/apple', response_model=TokenPair)
def apple_login(payload: AppleAuthRequest, db: DBSession = Depends(get_session)) -> TokenPair:
    try:
        identity = verify_apple_identity_token(payload.identity_token)
    except AppleAuthError as error:
        raise HTTPException(status_code=401, detail={'code': 'invalid_apple_identity', 'message': str(error)})

    user = db.scalar(select(User).where(User.apple_subject == identity.subject))
    if user is None:
        if not identity.email:
            raise HTTPException(status_code=400, detail={'code': 'apple_email_required_on_first_sign_in'})
        existing_email = db.scalar(select(User).where(User.email == identity.email))
        if existing_email is not None:
            raise HTTPException(status_code=409, detail={'code': 'account_link_required'})
        user = User(
            email=identity.email,
            email_verified=True,
            password_hash=None,
            apple_subject=identity.subject,
        )
        db.add(user)
        db.flush()
    try:
        device = upsert_device(
            db,
            user_id=user.id,
            device_id=payload.device_id,
            display_name=payload.display_name,
            platform=payload.platform,
            os_version=payload.os_version,
            public_key=payload.public_key,
        )
        pair = issue_session(db, user.id, device.id)
        db.commit()
        return pair
    except AuthError as error:
        db.rollback()
        raise _auth_http_error(error)


@router.post('/refresh', response_model=TokenPair)
def refresh(payload: RefreshRequest, db: DBSession = Depends(get_session)) -> TokenPair:
    try:
        return rotate_refresh_token(db, payload.refresh_token)
    except AuthError as error:
        db.rollback()
        raise _auth_http_error(error)


@router.post('/logout', status_code=204)
def logout(payload: LogoutRequest, db: DBSession = Depends(get_session)) -> Response:
    revoke_refresh_token(db, payload.refresh_token)
    return Response(status_code=204)


@router.post('/forgot-password', status_code=202)
def forgot_password(payload: ForgotPasswordRequest, db: DBSession = Depends(get_session)) -> dict:
    user = db.scalar(select(User).where(User.email == str(payload.email)))
    if user is not None and user.password_hash is not None:
        token = issue_email_action(db, user.id, 'reset_password', lifetime_minutes=30)
        send_reset_email(user.email, token)
    return {'accepted': True}


@router.post('/reset-password')
def password_reset(payload: ResetPasswordRequest, db: DBSession = Depends(get_session)) -> dict:
    try:
        reset_password(db, payload.token, payload.new_password)
    except AuthError as error:
        db.rollback()
        raise _auth_http_error(error)
    return {'reset': True}


@router.post('/change-password')
def password_change(
    payload: ChangePasswordRequest,
    context: AuthContext = Depends(current_session),
    db: DBSession = Depends(get_session),
) -> dict:
    try:
        change_password(db, context.user, payload.current_password, payload.new_password, keep_session_id=context.session.id)
    except AuthError as error:
        db.rollback()
        raise _auth_http_error(error)
    return {'changed': True}
