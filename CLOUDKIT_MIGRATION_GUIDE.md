# Copying Data from Development to Production CloudKit

## The Problem
Grace and Evan's wishlists were created in the **Development** CloudKit database, but you're now using **Production** (from TestFlight). Development and Production are completely separate databases.

## Option 1: Manual Copy via CloudKit Dashboard (Recommended for Small Amounts)

### Steps:
1. **Export from Development:**
   - Go to https://icloud.developer.apple.com/dashboard
   - Select your container: `iCloud.com.designoverhaul.ChristmasWishlist`
   - Switch to **Development** environment
   - Go to "Data" → Find Grace and Evan's records:
     - `WishlistItem` records (their wishlist items)
     - `Child` records (if they have children)
     - `Friend` records (if needed)
   - For each record, click "Export" or manually note down:
     - Record ID
     - All field values (name, url, description, etc.)
     - ownerID (user record ID)

2. **Import to Production:**
   - Switch to **Production** environment in CloudKit Dashboard
   - Go to "Data" → Create new records
   - Manually recreate each record with the same data
   - ⚠️ **Important:** Use the same `ownerID` (user record ID) from Development

### Limitations:
- Very tedious for many records
- Can't copy images/attachments easily
- Time-consuming

## Option 2: Have Grace and Evan Recreate Their Lists (Simplest)

Since they're real users:
1. **Have them open the TestFlight app** (Production)
2. **They add their wishlist items again**
3. **This ensures data is correct** and in Production

### Pros:
- ✅ Data is fresh and correct
- ✅ No migration complexity
- ✅ They can verify everything is correct

### Cons:
- They have to re-enter data
- Takes time

## Option 3: Create a Migration Script (For Large Amounts)

If there are many records, we can create a one-time migration script that:
1. Runs in Debug mode (Development CloudKit)
2. Fetches all records for Grace and Evan
3. Saves them to Production CloudKit

**Note:** This requires special handling because you can't easily switch between Development and Production in the same app instance.

## Recommendation

For Grace and Evan specifically:
- **If they have < 10 items each:** Use Option 1 (manual copy)
- **If they have many items:** Use Option 2 (have them recreate)
- **If you need to migrate frequently:** Consider Option 3 (migration script)

## Preventing This in the Future

1. **Always test with TestFlight builds** when testing with real users
2. **Use Development only for:** Testing new features, debugging, internal testing
3. **Use Production for:** Real users, family members, final testing

## Quick Check: Which Environment Am I Using?

- **Xcode installs (Debug/Release):** Development CloudKit
- **TestFlight/App Store:** Production CloudKit

The app logs will show:
- `⚠️ Using DEVELOPMENT CloudKit database` (Xcode installs)
- `✅ Using PRODUCTION CloudKit database` (TestFlight/App Store)







