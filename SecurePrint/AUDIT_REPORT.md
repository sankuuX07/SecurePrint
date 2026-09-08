# SecurePrint - Full-Stack Codebase Audit Report

## 1. Executive Summary
An extensive read-only audit of the SecurePrint Android and FastAPI backend was conducted. The architecture is solid, utilizing a split-stack design with Jetpack Compose/Retrofit on the client and FastAPI/SQLAlchemy on the backend. The core business logic is sound, but several critical bugs, API contract mismatches, and native library alignment issues were discovered.

## 2. Architecture & Security Review
- **Authentication**: JWT-based session management is correctly implemented on the backend and properly intercepted by `AuthInterceptor` on Android.
- **RBAC**: Role-based access control (`CUSTOMER`, `SHOP`, `ADMIN`) is strictly enforced at the routing level.
- **Security Weaknesses**: The backend securely hashes passwords with Argon2 and manages relationships safely (e.g. cascading deletes). No major P0 security flaws were identified in the business logic structure.

## 3. Bug Findings & API Contract Mismatches

### 3.1 Shop Registration `400 Bad Request` Root Cause
The root cause of the `400 Bad Request` error during Shop registration is a combination of two issues:
1. **Lack of Client-Side Validation**: The `ShopRegisterScreen` in Android does not perform client-side validation before submitting the `RegisterRequest`. If a user fails to completely fill out the optional shop details, the strings are passed as `""` (empty strings).
2. **Backend Truthiness Check**: In `backend/app/routes/auth.py`, the validation logic is:
   ```python
   if not user_in.shop_name or not user_in.address or not user_in.city:
       raise HTTPException(status_code=400, detail="Shop details are required")
   ```
   Empty strings evaluate to `False` in Python. Thus, even if a user provides partial shop details (or leaves them intentionally blank believing they are optional), the backend strictly rejects the request with a `400 Bad Request`.

### 3.2 `UserResponse` Serialization Bug (Backend)
In `backend/app/schemas/user.py`, the `UserResponse` schema inherits from `UserBase`, which includes `shop_name`, `address`, and `city`. However, `UserResponse.model_config` uses `from_attributes=True` and is validated against the `User` ORM model.
Because the `User` ORM model does NOT contain `shop_name`, `address`, or `city` (these reside in the `Shop` model), Pydantic falls back to their default values (`None`). Consequently, the backend silently drops the shop details in the JSON response, returning `null` for these fields. 

### 3.3 16 KB Native Library Alignment
The Android build is currently facing a 16 KB native library alignment issue for ML Kit components (`libbarhopper_v3.so` and `libimage_processing_util_jni.so`). This is caused by the default 4 KB alignment of these pre-built native libraries in the dependency tree, which conflicts with newer Android 15+ 16 KB page size enforcement.

## 4. Stability & Next Steps
We will proceed incrementally to fix these identified issues:
1. **Fix 16 KB Alignment**: Configure Gradle to ensure proper packaging of native libraries or set `android:extractNativeLibs="true"` in the manifest or gradle packaging options.
2. **Fix API Contracts**: Adjust the backend `UserResponse` to properly join or exclude Shop details, and implement client-side validation in `ShopRegisterScreen`.
3. **General Cleanup**: Remove any dead code identified during the audit.
