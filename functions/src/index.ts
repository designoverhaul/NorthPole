import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

/**
 * Normalize phone number to digits only
 */
function normalizePhone(phone: string): string {
  return phone.replace(/\D/g, '');
}

/**
 * Send push notification when a purchase is created
 * Triggers: When a document is created in /purchases/{purchaseId}
 */
export const onPurchaseCreated = functions.firestore
  .document('purchases/{purchaseId}')
  .onCreate(async (snap, context) => {
    const purchaseId = context.params.purchaseId;
    const purchaseData = snap.data();

    console.log(`[FCM] Purchase created: ${purchaseId}`, purchaseData);

    // Skip if not active or if notification already sent
    if (!purchaseData.isActive || purchaseData.notificationSent) {
      console.log(`[FCM] Skipping notification (isActive: ${purchaseData.isActive}, notificationSent: ${purchaseData.notificationSent})`);
      return null;
    }

    // Wait 5 seconds to let local notification fire first (if app is running)
    await new Promise(resolve => setTimeout(resolve, 5000));

    // Re-check if notification was sent by local listener
    const updatedSnap = await snap.ref.get();
    if (updatedSnap.data()?.notificationSent) {
      console.log(`[FCM] Local notification already sent, skipping push notification`);
      return null;
    }

    // Skip self-purchases
    const normalizedPurchaser = normalizePhone(purchaseData.purchaserPhone);
    const normalizedOwner = normalizePhone(purchaseData.ownerPhone);

    if (normalizedPurchaser === normalizedOwner) {
      console.log(`[FCM] Self-purchase detected, skipping notification`);
      return null;
    }

    // Try both phone number variations (10-digit and 11-digit with country code)
    const ownerPhoneVariations: string[] = [normalizedOwner];
    if (normalizedOwner.length === 10) {
      ownerPhoneVariations.push('1' + normalizedOwner);
    } else if (normalizedOwner.length === 11 && normalizedOwner.startsWith('1')) {
      ownerPhoneVariations.push(normalizedOwner.substring(1));
    }

    // Try to fetch owner's user document with phone number variations
    let ownerDoc = null;
    for (const phoneVariation of ownerPhoneVariations) {
      const doc = await admin.firestore().collection('users').doc(phoneVariation).get();
      if (doc.exists) {
        ownerDoc = doc;
        console.log(`[FCM] Found owner document with phone: ${phoneVariation}`);
        break;
      }
    }

    if (!ownerDoc || !ownerDoc.exists) {
      console.error(`[FCM] Owner user document not found for phones: ${ownerPhoneVariations.join(', ')}`);
      return null;
    }

    const ownerData = ownerDoc.data();

    // Check if notifications enabled for this user
    if (!ownerData?.settings?.notificationsEnabled) {
      console.log(`[FCM] Notifications disabled for user: ${normalizedOwner}`);
      return null;
    }

    // Get FCM tokens
    const fcmTokens: string[] = ownerData?.fcmTokens || [];
    if (fcmTokens.length === 0) {
      console.log(`[FCM] No FCM tokens found for user: ${normalizedOwner}`);
      return null;
    }

    // Look up purchaser's name from friends collection with phone number variations
    let friendName = 'Someone';

    // Try to find friend with different phone number variations
    const purchaserPhoneVariations: string[] = [normalizedPurchaser];
    if (normalizedPurchaser.length === 10) {
      purchaserPhoneVariations.push('1' + normalizedPurchaser);
    } else if (normalizedPurchaser.length === 11 && normalizedPurchaser.startsWith('1')) {
      purchaserPhoneVariations.push(normalizedPurchaser.substring(1));
    }

    // Query with owner phone and try all purchaser phone variations
    for (const ownerPhoneVariation of ownerPhoneVariations) {
      for (const purchaserPhoneVariation of purchaserPhoneVariations) {
        const friendsQuery = await admin.firestore()
          .collection('friends')
          .where('userPhone', '==', ownerPhoneVariation)
          .where('friendPhone', '==', purchaserPhoneVariation)
          .limit(1)
          .get();

        if (!friendsQuery.empty) {
          const friendData = friendsQuery.docs[0].data();
          friendName = friendData.friendName || 'Someone';
          console.log(`[FCM] Found friend name: ${friendName}`);
          break;
        }
      }
      if (friendName !== 'Someone') break;
    }

    // Build notification payload
    const itemName = purchaseData.itemName;
    const payload = {
      notification: {
        title: 'Gift Purchased!',
        body: `🎁 Someone purchased ${itemName} for you!`,
      },
      data: {
        type: 'item_purchased',
        itemName: itemName,
        friendName: friendName,
        purchaseId: purchaseId,
        itemId: purchaseData.itemId,
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    // Send to all user's devices
    const promises = fcmTokens.map(async (token) => {
      try {
        await admin.messaging().send({ ...payload, token });
        console.log(`[FCM] ✅ Sent notification to token: ${token.substring(0, 10)}...`);
      } catch (error: any) {
        console.error(`[FCM] ❌ Failed to send to token ${token.substring(0, 10)}:`, error.message);

        // Remove invalid tokens
        if (error.code === 'messaging/invalid-registration-token' ||
            error.code === 'messaging/registration-token-not-registered') {
          await ownerDoc.ref.update({
            fcmTokens: admin.firestore.FieldValue.arrayRemove(token),
          });
          console.log(`[FCM] Removed invalid token: ${token.substring(0, 10)}...`);
        }
      }
    });

    await Promise.all(promises);

    // Mark notification as sent
    await snap.ref.update({
      notificationSent: true,
      notificationSentAt: admin.firestore.FieldValue.serverTimestamp(),
      sentBy: 'cloud_function',
    });

    console.log(`[FCM] ✅ Notification sent for purchase: ${purchaseId}`);
    return null;
  });
