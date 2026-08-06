# SkillForge AI — System Guide (Roman Urdu)

Yeh file aasan lafzon mein banayi gayi hai taake aapko apne platform ka poora system samajh aa jaye, bilkul wese hi jaise aapne poocha tha. Isme Fiverr aur Upwork ka concept use kiya gaya hai.

## 1. Order aur Paise ka Safar (Order Journey)
Jab koi customer kisi freelancer ko hire karta hai to asal mein kya hota hai?
1. **Order Placed:** Customer freelancer ki profile dekhta hai aur "Hire" pe click karta hai. Order banta hai aur "Pending" status mein chala jata hai.
2. **Payment & Escrow:** Customer apni pocket se paise pay karta hai. Lekin dhayan rahay, yeh paise direct freelancer ko **nahi** milte. Yeh paise system ke ek mehfooz (secure) locker mein chale jate hain jise **"Escrow"** kehte hain. Order ab "Active" ho jata hai.
3. **Delivery:** Freelancer apna kaam start karta hai, mukammal karta hai aur file bhej deta hai (Order status: Delivered).
4. **Approval:** Customer wo file dekhta hai aur agar pasand aa jaye to usko "Approve" kar leta hai.
5. **Wallet:** Approve hote hi, Escrow ka locker khulta hai. SkillForge platform apni commission (fees) kat'ta hai, aur baqi paise nikal kar direct freelancer ke **Wallet** mein daal deta hai.

## 2. Escrow Kya Hai? (Bichola / Amanat)
Aasan lafzon mein samjhein: Escrow ek 'Amanat' ya 'Third-Party Vault' hai. 
- **Kyu zaroori hai?** Agar customer direct paise de de, to freelancer kaam kiye bina bhaag sakta hai. Aur agar customer pehle kaam le le aur kahe ke baad mein paise dunga, to ho sakta hai wo kaam le kar bhaag jaye.
- Escrow dono ko secure karta hai. Customer paise pay karta hai to usay tasalli hoti hai ke paise platform ke pas safe hain, aur freelancer ko tasalli hoti hai ke paise sach mein aagaye hain, ab mujhe bas tension-free ho kar kaam karna hai. Jab kaam theek se mukammal hota hai, tabhi platform paise freelancer ke hawale karta hai.

## 3. Wallet aur Balances (Freelancer ka Khata)
Freelancer ke wallet mein mukhtalif (different) kism ke balances hote hain:
- **Escrow Balance:** Yeh wo paise hain jo abhi tak lock hain kyunke freelancer us project pe kaam kar raha hai. Yeh uske apne paise nahi hain abhi, bas usay show ho rahe hote hain ke "itne paise ka kaam chal raha hai".
- **Pending Balance:** Kaam approve hone ke baad paise aksar foran nikalwane ke qabil nahi hote, wo Pending mein aate hain. (Jaise Fiverr 14 din ka time leta hai clearance ke liye taake customer bank se fraud ka case ya chargeback na kar de).
- **Available Balance:** Yeh wo clear aur safe paise hain jo freelancer kisi bhi waqt apne bank account (ya Easypaisa/Jazzcash) mein nikalwa sakta (Withdraw kar sakta) hai.

## 4. Payout (Paise Nikalwana)
Jab freelancer ke pas Available Balance mein paise aate hain, to wo **"Withdraw"** ka button dabata hai.
- Is se ek **Payout Request** ban jati hai jo Admin ke pas aati hai.
- Admin usko check karta hai aur uske real bank mein paise transfer kar deta hai. 
- Jab future mein Stripe ya PayPal jesi real cheezein lagengi, to ye withdrawal ka kaam automatically ho jayega.

## 5. Dispute (Jhagda ya Masla)
Agar customer aur freelancer ke darmian kisi baat pe ikhtilaf (disagreement) ho jaye (maslan customer ko kaam pasand nahi aya aur freelancer keh raha hai mene theek kiya hai):
- Dono mein se koi bhi **Dispute** open kar sakta hai. 
- Order wahin freeze (ruk) jata hai aur paise Escrow mein mazeed phans jate hain.
- **Admin (Yani Aap):** Ab aap (Admin) as a Judge (Munsif) enter hote hain. Aap unki messages aur kaam dekhte hain.
- Aapke paas 3 options hote hain:
  1. **Refund:** Pura paisa customer ko wapas kar dein.
  2. **Release:** Pura paisa freelancer ko de dein kyunke uski ghalti nahi thi usne theek kaam kiya tha.
  3. **Split (Darmiyani Rasta):** 50% paise freelancer ko uski mehnat ke de dein, aur 50% customer ko wapas kar dein.

## 6. Revision (Kaam mein Tabdeeli)
Jab freelancer kaam "Deliver" karta hai, to zaroori nahi ke customer ko pehli baar mein pasand aa jaye. Wo usay reject karke **"Request Revision"** kar sakta hai.
- **Iska Matlab:** Customer kehta hai "Mujhe isme thori changes chahiye, logo ka rang badal do ya font chota kar do."
- Order "Delivered" se wapas "Active" status mein chala jata hai. Freelancer changes karke dobara deliver karta hai.
- Freelancer apni setting mein set kar sakta hai ke wo kitni Revisions muft dega (maslan 2 ya 3). Agar limit puri ho jaye to customer aur tang nahi kar sakta.

## 7. My Cases / Support Tickets
Agar system mein koi technical masla aye, payment atak jaye, ya account ban ho jaye:
- User ek **Support Request** (ticket) generate karta hai jo "My Cases" mein show hoti hai.
- Admin in tickets ko Support dashboard mein dekh ke user ka masla hal karta hai. 
- *Faraq samjhein:* Dispute project aur users ke aapas ke jhagde ke liye hota hai. Support/Cases system ke technical problems ya platform ki help lene ke liye hote hain.

## 8. Transactions & Invoices (Raseedein aur Hisaab)
- **Transactions:** Yeh ek aisi history (Ledger) hai jo kabhi delete nahi ho sakti. Agar kisi ke wallet mein $100 aye hain, to transactions mein hamesha ke liye likh diya jata hai ke ye paise kahan se aaye. Agar platform se koi ghalti ho jaye, to aap pehli transaction ko "Edit" nahi kar sakte (ye strict rule hota hai accounting ka), aapko us ghalti ko theek karne ke liye ek *nai* transaction banani parti hai. Yeh fraud aur chori rokne ka sab se behtareen tareeqa hai.
- **Invoices (Raseed):** Customer aur Freelancer dono ko alag alag PDF Invoices milti hain. Customer ki raseed pe usne jo total pay kiya hota hai wo likha hota hai (e.g. $100), aur freelancer ki raseed pe usay platform fees katne ke baad jo milta hai wo likha hota hai (e.g. $90).

## 9. Commission (SkillForge ki Kamai)
Aapka platform jo fees (cut) rakhta hai (maslan 10%), wo freelancer ke wallet mein bilkul nahi jata. Wo paise platform ke ek apne alag khate mein chale jate hain jise **Commission Ledger** kehte hain. 
Iska faida ye hai ke aap kisi bhi waqt dekh sakte hain ke SkillForge platform ne total kitna profit (net income) kamaya hai, aur user ke funds aapke apne funds ke sath mix nahi hote.

---
**Aakhri Khulasa (Final Summary):**
System bilkul enterprise-grade hai. 
Customer order de kar paise pay karta hai ➔ Paise system ke "Escrow locker" mein amanat rakhe jate hain ➔ Freelancer tension-free kaam karta hai ➔ Customer approve karta hai ➔ Platform apna commission (SkillForge ki kamai) rakhta hai ➔ Baki paise Freelancer ke "Wallet" mein daal diye jate hain ➔ Jaha se wo bank mein nikalwa sakta hai.
Kisi bhi kisam ke jhagde ko Admin "Dispute" screen se handle karta hai.
