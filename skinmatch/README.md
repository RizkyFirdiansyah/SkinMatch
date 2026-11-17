# SkinMatch Flutter App

## Run with the backend

Start the backend from `backend/` after applying database migrations:

```powershell
alembic upgrade head
uvicorn app.main:app --reload --host 0.0.0.0
```

Then run the app from `skinmatch/`:

```powershell
flutter run
```

The app uses `http://10.0.2.2:8000` by default on the Android emulator and
`http://localhost:8000` on web and other platforms. Override the API address
with `--dart-define=API_BASE_URL=http://<backend-host>:8000`; use the computer's
LAN address when connecting a physical device. The backend must be reachable
from the device. Use HTTPS rather than cleartext HTTP for production.

The app uses the backend for registration, login, profile retrieval and updates,
image scans, scan details, and scan history. Uploaded images must be JPG, PNG,
or WEBP and no larger than 2 MB.
