# How to Import Exported Data to Production CloudKit

## Step-by-Step Guide

### Step 1: Access CloudKit Dashboard
1. Go to https://icloud.developer.apple.com/dashboard
2. Sign in with your Apple Developer account
3. Select your container: `iCloud.com.designoverhaul.ChristmasWishlist`
4. **Switch to PRODUCTION environment** (important!)

### Step 2: Import WishlistItem Records

For each WishlistItem from your export:

1. Go to "Data" → "WishlistItem" record type
2. Click "Create Record" or "+"
3. Fill in the fields from your export:
   - **name**: (from export)
   - **url**: (from export, if any)
   - **description**: (from export, if any)
   - **ownerID**: (from export - this is the user record ID)
   - **createdAt**: (from export)
4. Click "Save"

### Step 3: Import Child Records

For each Child from your export:

1. Go to "Data" → "Child" record type
2. Click "Create Record" or "+"
3. Fill in the fields:
   - **name**: (from export)
   - **parentUserRecordID**: (from export - this is the user record ID)
   - **createdAt**: (from export)
4. Click "Save"

### Step 4: Import Friend Records (if needed)

For each Friend from your export:

1. Go to "Data" → "Friend" record type
2. Click "Create Record" or "+"
3. Fill in the fields:
   - **name**: (from export)
   - **phoneNumber**: (from export, if any)
   - **email**: (from export, if any)
   - **friendUserRecordID**: (from export, if any)
   - **ownerID**: (your user record ID)
   - **addedAt**: (from export)
4. Click "Save"

## Important Notes

⚠️ **Critical:** Make sure you're in **PRODUCTION** environment, not Development!

⚠️ **ownerID and parentUserRecordID:** These must match exactly from your export. These are the user record IDs that identify who owns the data.

⚠️ **Record IDs:** The record IDs will be different in Production (CloudKit generates new ones). That's fine - just make sure the ownerID/parentUserRecordID match.

## Alternative: Have Users Recreate

If there are many records, it might be easier to:
1. Have Grace and Evan open the TestFlight app
2. They add their wishlist items again
3. This ensures everything is correct and in Production







