# SkillForge AI — Commerce System Architecture Guide

*An engineering walkthrough designed for the Product Owner / CEO.*

---

## SECTION 1: Complete User Journey

Imagine a customer wants to hire a talented logo designer (a freelancer) on SkillForge AI. Here is the exact path the money and the order take, from start to finish:

1. **Customer Login** ➔ The customer logs into their lightweight Customer Workspace.
2. **Marketplace** ➔ They browse the marketplace and find a great freelancer.
3. **Service Detail** ➔ They view the freelancer’s gig, read reviews, and check packages.
4. **Request Service / Checkout** ➔ The customer clicks "Hire". They enter their project requirements.
5. **Order Created** ➔ A new Order is generated in the system. It sits at `pending` waiting for money.
6. **Payment** ➔ The customer pays (currently using our Sandbox/Demo payment gateway).
7. **Escrow** ➔ The money does **not** go to the freelancer. It is locked inside a secure platform "Vault" called **Escrow**. The order is now `active`.
8. **Freelancer Works** ➔ The freelancer gets a notification: *"You got an order! The money is secure in Escrow."* They begin working.
9. **Delivery** ➔ The freelancer submits the final logo. The order is marked `delivered`.
10. **Approval** ➔ The customer reviews the logo and clicks "Approve". The order is now `completed`.
11. **Wallet** ➔ The system magically unlocks the Escrow vault. It takes out the platform commission (e.g., 10%) and sends the rest straight into the freelancer's **Wallet**.
12. **Withdrawal (Payout)** ➔ The freelancer clicks "Withdraw" to move money from their Wallet to their real bank account.
13. **Admin** ➔ You (the admin) oversee all of this from the Finance Dashboard, watching the platform commission grow.

---

## SECTION 2: Customer Journey

**What exactly happens when the customer presses "Hire" and pays?**

Behind the scenes, we don't just "move numbers." We create a highly structured paper trail:
- **Models Created:** A `ServiceOrderModel` is born. 
- **Collections Written:** It is saved to the `service_orders` database collection.
- **Statuses Change:** The order's payment status becomes `demoPaid` (or `paid`), and its order status becomes `active`.
- **Escrow Creation:** An `EscrowHoldModel` is automatically generated to physically track those locked funds. 
- **Invoices:** A receipt (Invoice) is generated for the customer.
- **Notifications:** The system triggers an alert to the freelancer to wake them up and start working.
- **Screens Involved:** The customer is redirected back to their **Customer Workspace ➔ My Orders** screen, where they can track the progress of their logo design.

---

## SECTION 3: Freelancer Journey

**What the freelancer experiences:**

- **How the request arrives:** They see a new active order pop up on their Freelancer Dashboard. 
- **Money Visibility:** They see exactly how much they will earn, but they **cannot touch it yet**. 
- **Why money goes to Escrow:** If the money went straight to the freelancer's wallet, they could withdraw it and disappear without doing the work. Escrow protects the customer.
- **Why it doesn't immediately reach the Wallet:** The freelancer must prove they did the work by delivering it, and the customer must legally accept it. Only then is the money unlocked.
- **How earnings appear:** Once the customer approves, the funds teleport from Escrow into the freelancer's Wallet as "Earnings".

---

## SECTION 4: Escrow (Explained for a 10-Year-Old)

Imagine you want to buy a rare Pokémon card from a kid across the street, but you don't trust him. 
You give your $10 to your trusted teacher (SkillForge AI). 
The teacher says: *"I have the money securely. Give him the card."*
The kid gives you the card. You look at it and say, *"Yep, it's real!"*
Only then does the teacher hand the $10 to the kid. 

That teacher is **Escrow**.

- **Who owns Escrow?** SkillForge AI owns it. It's a secure holding tank.
- **Can the freelancer spend Escrow money?** Absolutely not. They can only stare at it and use it as motivation to finish the job.
- **Can the customer cancel after payment?** Not easily. Because the freelancer is already working, the customer can't just snatch their money back. They have to request a cancellation or open a dispute.
- **What happens if a dispute occurs?** The money stays frozen in the teacher's hand until the Admin (the Principal) decides who gets it.
- **What happens after completion?** The Escrow hold is destroyed, and the money is released to the freelancer.

---

## SECTION 5: Wallet

The `FreelancerWalletModel` tracks a freelancer's financial life. Like Upwork, it has multiple balances:

- **Escrow Balance:** Money currently locked in active orders. (e.g., Working on a $500 job? Escrow Balance shows $500).
- **Pending Balance:** Money that was released from Escrow but is waiting out a "security clearance" period (like Fiverr's 14-day clearance to prevent credit card chargebacks).
- **Available Balance:** Real, cleared money they can withdraw to their bank *right now*.
- **Lifetime Earnings:** The total amount of money they have ever successfully earned on SkillForge AI.
- **Lifetime Withdrawn:** The total money they have safely transferred to their bank account over their lifetime.
- **Monthly/Weekly Earnings & Orders:** Quick stats updated automatically to power the beautiful charts on their dashboard.

---

## SECTION 6: Transactions

**What is a transaction?**
A transaction is an un-deletable digital receipt. 

**Why do transactions exist if a Wallet already holds the balance?**
Imagine your bank account says you have $100. You would ask: *"Wait, where did that $100 come from? Who paid me?"* The wallet only shows the *current state*. The `commerce_transactions` collection acts as the *history book*. Every time money moves, a new receipt is printed.

**The Immutable Ledger:**
Immutable means **"cannot be changed or deleted"**. If an order is completed, we write a transaction: "+$100 to Wallet". If we made a mistake, we are strictly forbidden from editing that receipt. Instead, we must write a *new* receipt: "-$100 Correction". This is enterprise-grade accounting. It prevents fraud and makes audits incredibly easy.

---

## SECTION 7: Invoices

- **When is it created?** The moment money changes hands (usually upon checkout and upon completion).
- **Client vs. Freelancer Invoices:** 
  - The **Customer** receives an invoice that says: *"Service: $100. Tax: $5. Total Paid: $105."*
  - The **Freelancer** receives an entirely different invoice that says: *"Service: $100. Platform Fee Deduction: -$10. Total Earned: $90."*
- **Why are they immutable?** Because invoices are legal tax documents. Once generated, they are frozen in time for accounting and PDF generation.

---

## SECTION 8: Payout

- **Why the Wallet exists:** If we automatically wired money to a freelancer's bank every time they finished a $5 gig, the bank wire fees would bankrupt us. The Wallet groups their earnings together.
- **Pressing Withdraw:** When they hit "Withdraw", a `PayoutModel` is created.
- **What the Admin sees:** The Admin sees a pending payout request in their Finance Dashboard.
- **Sandbox Mode:** Right now, in testing, pressing withdraw instantly marks it as "Paid" and magically deducts it from the Wallet for demonstration purposes.
- **The Future (Stripe/PayPal):** Later, we will plug Stripe Connect into this exact spot. Pressing "Withdraw" will tell Stripe to digitally wire the actual funds to their real-world checking account.

---

## SECTION 9: Commission

- **Platform Fee:** SkillForge AI takes a cut (e.g., 10%) of every job. 
- **Commission Ledger:** We do not put this money in the freelancer's wallet, nor do we just let it vanish. We write it to the `commission_ledgers` database collection.
- **Why it is separated:** This represents the company's gross revenue. By keeping it in its own isolated ledger, you (the CEO) can instantly see exactly how much profit SkillForge AI has made today, this week, or this year, without mixing it up with user funds.

---

## SECTION 10: Refunds

If a customer is unhappy and the freelancer agrees to cancel:
- **Order:** Changes status to `refunded`.
- **Escrow:** The Escrow hold is destroyed/released.
- **Wallet:** The freelancer's Wallet is untouched (because the money was stuck in Escrow and never actually reached them).
- **Transactions:** A new transaction is logged stating "Funds returned to Customer".

---

## SECTION 11: Disputes

Sometimes people fight. 
- **Who can open:** Either the Customer or Freelancer can smash the "Dispute" button.
- **What happens:** The order freezes. The money is locked in Escrow. 
- **The Judge:** The Admin steps in, reads the chat history, and makes a final ruling.
- **Outcomes:** 
  1. *100% Refund:* Admin gives it all back to the customer.
  2. *Release Escrow:* Admin forces the money through to the freelancer.
  3. *Split:* Admin compromises (e.g., $50 to freelancer for time spent, $50 back to customer).

---

## SECTION 12: Revision Workflow

Like Fiverr, a customer can ask for changes instead of outright rejecting the delivery.
- **Request:** Customer clicks "Request Revision". The order leaves `delivered` status and goes back to `active`.
- **Limits:** If the freelancer's gig only includes 2 revisions, the system tracks `revisionCount`. Once they hit 2, the customer cannot ask for more free changes. 
- **Completion:** The freelancer re-delivers the files, and the cycle repeats until approval.

---

## SECTION 13: Admin

As the platform owner, the Admin has absolute oversight but is restricted from breaking the laws of physics (the immutable ledger).
- **What Admin CAN see:** The total volume of money in Escrow, total company Commission, all active orders, every freelancer's wallet balance, and a feed of every transaction.
- **What Admin CANNOT do:** The Admin cannot manually go in and edit a transaction receipt to hide money. They cannot manually "type" $1,000,000 into a freelancer's wallet. They must use proper platform actions (like issuing a bonus) which generates a paper trail.
- **Responsibilities:** Approving bank payouts, resolving disputes, and monitoring platform health.

---

## SECTION 14: Database Collections Map

Here is exactly where the data lives in your Firebase database:

| Collection Name | Purpose | Who Writes It | Who Reads It |
| :--- | :--- | :--- | :--- |
| `service_orders` | Tracks the gig, the buyer, the seller, and current status. | System / Customer | Customer, Freelancer, Admin |
| `escrow_holds` | Represents money locked safely in the "Vault". | System (Automatically) | Admin, System Logic |
| `freelancer_wallets`| Holds the current balances of a freelancer. | System (Automatically) | Freelancer, Admin |
| `commerce_transactions`| The immutable ledger. The receipt history of every penny. | System (Automatically) | Freelancer, Admin |
| `commission_ledgers`| Tracks the CEO's profit (platform fees). | System (Automatically) | Admin (Finance Dashboard) |
| `invoices` | Tax-compliant receipts for both parties. | System (Automatically) | Customer, Freelancer |
| `payouts` | Withdrawal requests to move money to a real bank. | Freelancer | Admin |
| `disputes` | Logs of fights between users needing Admin help. | Customer / Freelancer | Admin |

---

## SECTION 15: Flow Diagram

```text
  [ CUSTOMER ] 
       ↓ 
 (Browses Marketplace) 
       ↓ 
 [ REQUEST SERVICE ] 
       ↓ 
 [ PENDING ORDER ] 
       ↓ 
 (Pays with Credit Card)
       ↓ 
 [ ESCROW HOLD ]  ──────────────┐ (Platform Fee 10%)
       ↓                        ↓
(Freelancer Delivers)    [ COMMISSION LEDGER ]
       ↓                        ↓
(Customer Approves)        (CEO Profit)
       ↓ 
 [ ESCROW UNLOCKS ] 
       ↓ 
 [ FREELANCER WALLET ] 
       ↓ 
 (Freelancer clicks Withdraw)
       ↓ 
 [ PAYOUT REQUEST ] 
       ↓ 
 (Admin Approves / System Wires Funds)
       ↓ 
 [ REAL BANK ACCOUNT ]
```

---

## SECTION 16: The Future (Stripe, PayPal, PayFast)

One of the best things about this architecture is how "future-proof" it is. 

Right now, to simulate a payment, we use a `demoPaid` status. The system acts exactly as if real money moved.

**When we are ready to add real credit cards (Stripe) or mobile wallets (EasyPaisa/JazzCash):**
We do **NOT** need to rebuild the Wallet, Escrow, Orders, or Transactions. We simply replace the "Demo Payment" button with a "Pay with Stripe" button. 

When Stripe charges the card successfully, Stripe will send a hidden signal to our backend saying *"Payment Successful"*. Our system will then trigger the exact same code we use today for `demoPaid`. The order will activate, Escrow will be created, and the entire system will run flawlessly just like it does today. The core logic remains 100% untouched.

---

## SUMMARY: The First Three Steps (Until the money reaches the Freelancer)

1. **First:** The customer pays. The money is trapped by the system in an **Escrow Hold**. The freelancer is told to start working.
2. **Second:** The freelancer finishes the work and delivers it. The customer reviews it and clicks "Approve". 
3. **Third:** The system destroys the Escrow hold, extracts the company's platform fee, and deposits the remaining funds directly into the **Freelancer's Wallet** as "Available Balance".

*The end.*
