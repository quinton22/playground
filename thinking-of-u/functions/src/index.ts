import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function currentDateKey(): string {
  const now = new Date();
  const year = now.getUTCFullYear();
  const month = String(now.getUTCMonth() + 1).padStart(2, "0");
  const day = String(now.getUTCDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

async function sendPushNotification(
  token: string,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<void> {
  if (!token) return;
  try {
    await admin.messaging().send({
      token,
      notification: { title, body },
      data: data ?? {},
      android: {
        notification: {
          channelId: "thinking_of_u_channel",
          priority: "high",
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    });
  } catch (err) {
    functions.logger.warn(`Failed to send push to token ${token}:`, err);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trigger: When a submission is created or updated, check for mutual matches
// ─────────────────────────────────────────────────────────────────────────────

export const onSubmissionWritten = functions.firestore
  .document("users/{submitterHash}/submissions/{targetHash}")
  .onWrite(async (change, context) => {
    const { submitterHash, targetHash } = context.params as {
      submitterHash: string;
      targetHash: string;
    };

    const newData = change.after.exists ? change.after.data() : null;
    if (!newData) return; // deletion — nothing to do

    const dateKey = (newData.dateKey as string | undefined) ?? "";
    if (!dateKey) return;

    functions.logger.info(
      `Checking match for submitter=${submitterHash}, target=${targetHash}, date=${dateKey}`
    );

    // Check if we've already recorded this match
    const matchId = [submitterHash, targetHash].sort().join("_");
    const matchRef = db
      .collection("matches")
      .doc(dateKey)
      .collection("match_records")
      .doc(matchId);

    const existingMatch = await matchRef.get();
    if (existingMatch.exists) return; // already processed

    // Check if target submitted the submitter
    const targetSubmissionRef = db
      .collection("users")
      .doc(targetHash)
      .collection("submissions")
      .doc(submitterHash);

    const targetSubmission = await targetSubmissionRef.get();
    if (!targetSubmission.exists) return;

    const targetData = targetSubmission.data();
    const targetDateKey = (targetData?.dateKey as string | undefined) ?? "";
    if (targetDateKey !== dateKey) return;

    // 🎉 It's a match!
    functions.logger.info(`Match found: ${submitterHash} <-> ${targetHash}`);

    // Fetch both users' display names and FCM tokens
    const [user1Doc, user2Doc] = await Promise.all([
      db.collection("users").doc(submitterHash).get(),
      db.collection("users").doc(targetHash).get(),
    ]);

    const user1Data = user1Doc.data();
    const user2Data = user2Doc.data();

    const user1Name: string = user1Data?.displayName ?? "Someone";
    const user2Name: string = user2Data?.displayName ?? "Someone";
    const user1Token: string = user1Data?.fcmToken ?? "";
    const user2Token: string = user2Data?.fcmToken ?? "";

    // Write the match record
    await matchRef.set({
      user1Hash: submitterHash,
      user2Hash: targetHash,
      user1DisplayName: user1Name,
      user2DisplayName: user2Name,
      matchedAt: admin.firestore.FieldValue.serverTimestamp(),
      notificationsSent: false,
      participants: [submitterHash, targetHash],
    });

    // Update match counts and streaks for both users
    await Promise.all([
      updateUserMatchStats(submitterHash),
      updateUserMatchStats(targetHash),
    ]);

    // Send push notifications to both users
    await Promise.all([
      sendPushNotification(
        user1Token,
        "💕 Thinking of U Match!",
        `${user2Name} was thinking of you too! 🎉`,
        { type: "match", dateKey, matchId }
      ),
      sendPushNotification(
        user2Token,
        "💕 Thinking of U Match!",
        `${user1Name} was thinking of you too! 🎉`,
        { type: "match", dateKey, matchId }
      ),
    ]);

    // Mark notifications as sent
    await matchRef.update({ notificationsSent: true });
  });

// ─────────────────────────────────────────────────────────────────────────────
// Scheduled: Daily reset at midnight UTC
// Resets dailySendsRemaining for all users, respects extension days
// ─────────────────────────────────────────────────────────────────────────────

export const dailyReset = functions.pubsub
  .schedule("0 0 * * *") // Every day at midnight UTC
  .timeZone("UTC")
  .onRun(async () => {
    functions.logger.info("Running daily reset...");

    const now = new Date();
    const tomorrow = new Date(now);
    tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
    tomorrow.setUTCHours(0, 0, 0, 0);

    // Batch process all users
    const usersSnapshot = await db.collection("users").get();
    const batch = db.batch();
    let count = 0;

    for (const userDoc of usersSnapshot.docs) {
      const data = userDoc.data();
      const extensionDays = (data.extensionDaysRemaining as number) ?? 0;
      const dailyLimit = (data.dailyLimit as number) ?? 3;

      let updates: Record<string, unknown>;

      if (extensionDays > 0) {
        // User has extensions — only decrement extension days, don't reset yet
        updates = {
          extensionDaysRemaining: extensionDays - 1,
          nextResetAt: tomorrow,
        };
        functions.logger.info(
          `User ${userDoc.id} has ${extensionDays} extension days remaining, skipping reset.`
        );
      } else {
        // Reset daily sends
        updates = {
          dailySendsRemaining: dailyLimit,
          nextResetAt: tomorrow,
        };
      }

      batch.update(userDoc.ref, updates);
      count++;

      // Firestore batch limit is 500
      if (count % 450 === 0) {
        await batch.commit();
      }
    }

    await batch.commit();
    functions.logger.info(`Daily reset complete. Processed ${count} users.`);
  });

// ─────────────────────────────────────────────────────────────────────────────
// Helper: update a user's match stats (totalMatches, streak)
// ─────────────────────────────────────────────────────────────────────────────

async function updateUserMatchStats(userHash: string): Promise<void> {
  const userRef = db.collection("users").doc(userHash);
  await db.runTransaction(async (t) => {
    const snap = await t.get(userRef);
    if (!snap.exists) return;

    const data = snap.data()!;
    const totalMatches = ((data.totalMatches as number) ?? 0) + 1;

    const lastMatchDate: string = data.lastMatchDate ?? "";
    const today = currentDateKey();

    let currentStreak: number = (data.currentStreak as number) ?? 0;
    let longestStreak: number = (data.longestStreak as number) ?? 0;

    // Check if this is a consecutive day
    const lastDate = lastMatchDate ? new Date(lastMatchDate + "T00:00:00Z") : null;
    const todayDate = new Date(today + "T00:00:00Z");
    const diffDays = lastDate
      ? Math.round(
          (todayDate.getTime() - lastDate.getTime()) / (1000 * 60 * 60 * 24)
        )
      : 0;

    if (!lastMatchDate || diffDays === 1) {
      currentStreak += 1;
    } else if (diffDays > 1) {
      currentStreak = 1;
    }
    // Same day match — don't double-count streak

    if (currentStreak > longestStreak) {
      longestStreak = currentStreak;
    }

    t.update(userRef, {
      totalMatches,
      currentStreak,
      longestStreak,
      lastMatchDate: today,
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Callable: Lookup a user's display name by phone hash
// Only returns the name if the user exists — never exposes other data
// ─────────────────────────────────────────────────────────────────────────────

export const getUserDisplayName = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
  }

  const { phoneHash } = data as { phoneHash: string };
  if (!phoneHash || typeof phoneHash !== "string") {
    throw new functions.https.HttpsError("invalid-argument", "phoneHash required.");
  }

  const userDoc = await db.collection("users").doc(phoneHash).get();
  if (!userDoc.exists) return { found: false };

  return {
    found: true,
    displayName: userDoc.data()?.displayName ?? "Friend",
  };
});
