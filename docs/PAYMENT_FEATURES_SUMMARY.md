# Payment Features Summary

SkillForge uses **PayFast Pakistan** for real hosted checkout (Card / JazzCash / Easypaisa / Raast).

See [PAYFAST_SETUP.md](PAYFAST_SETUP.md) for merchant keys and `skillforge_ai_gateway` setup.

## Flows

- Teacher plans, AI credit packs, student course purchases
- Student paid-course history, receipts, access, and continue-learning hub (`/student/courses/paid`)
- Teacher course-sale wallet (`/teacher/wallet`): pending/available balances synced from purchases, demo release, and demo withdraw
- Customer commerce order escrow funding
- Customer wallet top-up
- Cancel-at-period-end for teaching plans
- Platform fee on every charge (ledger + admin Super Transactions)

## Screens

- Shared PayFast checkout sheet (all roles)
- My Transactions (`/billing/transactions`)
- Admin Super Transactions (`/admin/super-transactions`)
- Teacher Earnings & Billing
- Teacher Wallet (`/teacher/wallet`)
- Student Paid Courses (`/student/courses/paid`)

## Demo note

Until `PAYFAST_MERCHANT_ID` / `PAYFAST_SECURED_KEY` are configured, checkout returns a clear “gateway not configured” error (no dummy cards).

Teacher Wallet release and withdraw controls are sandbox bookkeeping only: they persist `courseWallet` and `courseWalletTransactions` under `teachers/{uid}` and do **not** send a real bank payout.
