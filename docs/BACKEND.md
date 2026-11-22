# MyDay backend (Node + Express + MongoDB)

```bash
cp .env.example .env     # set JWT_SECRET (32+ chars) and MONGODB_URI
npm install
npm test                 # balance logic tests (no database needed)
npm run dev
```

Main endpoints (all except /auth/register|login need `Authorization: Bearer <token>`):
- POST /api/auth/register | login | logout, GET /api/auth/me
- GET /api/summary, PUT /api/profile/opening-balance
- CRUD /api/transactions, CRUD /api/routines, GET /api/routines/today?date=YYYY-MM-DD, POST /api/routines/:id/complete
- GET /api/reports/monthly?year&month, /yearly?year, /export?period&year&month&format=xlsx|pdf|csv
- POST /api/sync/push, GET /api/sync/pull?since=
