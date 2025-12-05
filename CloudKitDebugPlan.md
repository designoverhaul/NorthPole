# CloudKit Database Debugging Plan

## Problem Summary
- Mother's phone pulled in old/incomplete wishlist items
- Found old test child account that should have been deleted
- Wife's wishlist items didn't fully sync
- Suspect: Multiple accounts or phone number references in CloudKit

## Investigation Goals
1. Check if there are duplicate user records for the same phone number
2. Verify which wishlist items are associated with each phone number
3. Check if phone numbers are properly normalized in the cloud
4. Identify stale/orphaned data that should have been deleted
5. Verify wife's complete wishlist is in the cloud

## Method 1: CloudKit Dashboard (Recommended First Step)

### Access CloudKit Dashboard
1. Go to https://icloud.developer.apple.com/dashboard
2. Sign in with your Apple Developer account
3. Select your app: ChristmasWishlist
4. Select the appropriate container (usually starts with `iCloud.com.designoverhaul.ChristmasWishlist`)
5. Choose environment: **Development** or **Production** (check both!)

### What to Look For

#### Check User/Friend Records
1. Go to "Data" tab → Select "Users" or "Friend" record type
2. Look for records with your phone number
3. Check for duplicates:
   - Are there multiple records with variations of the same phone number?
   - Examples: `(205)-292-9663` vs `2052929663` vs `205-292-9663`
   - Check the `phoneNumber` field on each record

#### Check WishlistItem Records
1. Go to "Data" tab → Select "WishlistItem" record type
2. Look at the `ownerPhoneNumber` or similar field
3. Questions to answer:
   - How many items are associated with your phone number?
   - How many items are associated with your wife's phone number?
   - Are there old test items (like the child account)?
   - Check creation dates (`createdAt` field) - are old items still there?

#### Check Child Account Records
1. Look for child/dependent records
2. Check which parent phone number they're linked to
3. Are there old test children that should have been deleted?

### Export the Data
- Use CloudKit Dashboard's export feature to download all records
- This gives you a complete audit trail

## Method 2: Add Debug View to Your App

### Create a CloudKit Audit View
Add a debug view to your app that:
1. Queries all records from CloudKit
2. Displays counts and details
3. Shows phone number variations
4. Allows manual cleanup

### Implementation Steps
1. Create `CloudKitDebugView.swift`
2. Add CloudKit query functions
3. Display results in a list
4. Add to Settings → Developer Options

## Method 3: Use Xcode CloudKit Console

### Steps
1. Open Xcode
2. Window → Organizer → CloudKit Console
3. Select your container
4. Query records directly using CKQuery

## Expected Findings

### Scenario 1: Phone Number Not Normalized
```
Record 1: phoneNumber = "(205)-292-9663"
Record 2: phoneNumber = "2052929663"
```
**Problem**: Two separate user records for same person

### Scenario 2: Stale Data Not Deleted
```
WishlistItem created: 2024-01-15 (old test data)
Status: Active (should have been deleted)
```
**Problem**: Cleanup/delete operations didn't sync to cloud

### Scenario 3: Incomplete Sync
```
Wife's local items: 10
Wife's cloud items: 6
```
**Problem**: 4 items failed to sync to cloud

## Questions to Answer

1. **How many user records exist?**
   - Expected: One per unique phone number
   - Check: Are there duplicates?

2. **What phone number formats are stored?**
   - Are they normalized (digits only)?
   - Or raw format from Contacts?

3. **How many wishlist items per user?**
   - Your items: ___
   - Wife's items: ___
   - Child's items: ___

4. **Are there orphaned records?**
   - Items with no owner
   - Child accounts with no parent

5. **When were problematic records created?**
   - Old test data dates
   - Recent data dates
   - Helps identify what needs cleanup

## Next Steps After Investigation

Once you understand the current state:

1. **Document Findings**: Record what you find in this file
2. **Plan Cleanup**: Decide what needs to be deleted
3. **Fix Normalization**: Ensure all phone numbers are consistent
4. **Update Code**: Fix the sync logic to prevent future issues
5. **Test**: Verify fixes work before re-deploying

## Tools Needed

- [ ] Access to CloudKit Dashboard
- [ ] Apple Developer account credentials
- [ ] List of expected phone numbers for your family
- [ ] Date when you "thought" you cleared the data

## Safety Notes

⚠️ **IMPORTANT**:
- Work in Development environment first
- Don't delete Production data until you're sure
- Export all data before making changes
- Keep backup of current state

---

## Investigation Results (Fill this in)

### Date: _________

**User Records Found:**
- Total count: ___
- Your phone: ___
- Wife's phone: ___
- Mother's phone: ___
- Duplicates found: Yes/No

**WishlistItem Records Found:**
- Total count: ___
- Your items: ___
- Wife's items (expected vs actual): ___ vs ___
- Old test items: ___

**Phone Number Format Issues:**
- Are numbers normalized? Yes/No
- Variations found: ___

**Root Cause:**
(Document what you discover)

**Cleanup Plan:**
(List specific records to delete/fix)
