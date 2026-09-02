const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Builds a Turkish title/body for a notification request that has no
 * title/body of its own, based on its `type` field.
 * @param {Object} data notificationRequests document data.
 * @return {{title: string, body: string}} Fallback title and body.
 */
function buildFallbackMessage(data) {
  const groupName = data.groupName || "";

  switch (data.type) {
    case "expense_added":
      return {
        title: "Yeni Harcama",
        body: groupName ?
          `${groupName} grubuna yeni harcama eklendi.` :
          "Grubunuza yeni bir harcama eklendi.",
      };
    case "debt_reminder":
      return {
        title: "Borç Hatırlatması",
        body: "Bir borç hatırlatmanız var.",
      };
    case "payment_request":
      return {
        title: "Ödeme Talebi",
        body: "Onayınızı bekleyen bir ödeme talebi var.",
      };
    case "payment_approved":
      return {
        title: "Ödeme Onaylandı",
        body: "Bildirdiğiniz ödeme onaylandı.",
      };
    case "payment_rejected":
      return {
        title: "Ödeme Reddedildi",
        body: "Bildirdiğiniz ödeme reddedildi.",
      };
    case "payment_received_info":
      return {
        title: "Ödeme Bildirimi",
        body: "Bir ödeme aldığınız bildirildi.",
      };
    default:
      return {
        title: "Bildirim",
        body: "Yeni bir bildiriminiz var.",
      };
  }
}

exports.sendNotificationRequest = onDocumentCreated(
    "notificationRequests/{requestId}",
    async (event) => {
      const snap = event.data;
      if (!snap) return;

      const requestId = event.params.requestId;
      const requestRef = snap.ref;

      try {
        const data = snap.data();
        const fromEmail = (data.fromEmail || "").trim().toLowerCase();

        const rawRecipients = Array.isArray(data.toEmails) ?
          data.toEmails :
          (data.toEmail ? [data.toEmail] : []);

        const toEmails = [...new Set(
            rawRecipients
                .map((email) => (email || "").trim().toLowerCase())
                .filter((email) => email && email !== fromEmail),
        )];

        if (toEmails.length === 0) {
          const message =
              `notificationRequests/${requestId}: geçerli hedef kullanıcı yok`;
          console.error(message);
          await requestRef.update({
            status: "failed",
            error: message,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return;
        }

        const userQueries = await Promise.all(
            toEmails.map((email) =>
              admin.firestore()
                  .collection("users")
                  .where("email", "==", email)
                  .limit(1)
                  .get(),
            ),
        );

        const tokens = [];
        const tokenToUserRef = new Map();

        for (const querySnap of userQueries) {
          if (querySnap.empty) continue;
          const userDoc = querySnap.docs[0];
          const token = userDoc.data().fcmToken;
          if (token) {
            tokens.push(token);
            tokenToUserRef.set(token, userDoc.ref);
          }
        }

        if (tokens.length === 0) {
          const message =
              `notificationRequests/${requestId}: hiçbir hedef kullanıcının ` +
              `fcmToken'ı yok`;
          console.error(message);
          await requestRef.update({
            status: "failed",
            error: message,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return;
        }

        const fallback = buildFallbackMessage(data);
        const title = data.title || fallback.title;
        const body = data.body || fallback.body;

        const response = await admin.messaging().sendEachForMulticast({
          tokens,
          notification: {title, body},
          apns: {
            payload: {
              aps: {
                sound: "coin.wav",
              },
            },
          },
          android: {
            notification: {
              sound: "coin",
              channelId: "ortakhesap_sound_v3",
            },
          },
        });

        const cleanupTasks = [];
        const errorMessages = [];
        response.responses.forEach((result, index) => {
          if (result.success) return;

          const token = tokens[index];
          const errorMessage =
              `notificationRequests/${requestId}: token gönderim hatası ` +
              `(${token}): ${result.error}`;
          console.error(errorMessage);
          errorMessages.push(errorMessage);

          if (result.error &&
              result.error.code ===
                "messaging/registration-token-not-registered") {
            const userRef = tokenToUserRef.get(token);
            if (userRef) {
              cleanupTasks.push(
                  userRef.update({
                    fcmToken: admin.firestore.FieldValue.delete(),
                  }),
              );
            }
          }
        });

        await Promise.all(cleanupTasks);

        if (response.successCount > 0) {
          await requestRef.update({
            status: "sent",
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } else {
          await requestRef.update({
            status: "failed",
            error: errorMessages.join(" | "),
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      } catch (error) {
        const message =
            `notificationRequests/${requestId} işlenirken hata: ${error}`;
        console.error(message);
        try {
          await requestRef.update({
            status: "failed",
            error: message,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } catch (updateError) {
          console.error(
              `notificationRequests/${requestId} güncellenemedi: ` +
              `${updateError}`,
          );
        }
      }
    },
);

exports.cleanupOldNotificationRequests = onSchedule(
    {
      schedule: "every day 03:00",
      timeZone: "Europe/Istanbul",
    },
    async () => {
      const cutoff = admin.firestore.Timestamp.fromMillis(
          Date.now() - 30 * 24 * 60 * 60 * 1000,
      );

      const snapshot = await admin.firestore()
          .collection("notificationRequests")
          .where("createdAt", "<", cutoff)
          .get();

      if (snapshot.empty) {
        console.log("Silinecek eski notificationRequests dokümanı yok.");
        return;
      }

      const commits = [];
      let batch = admin.firestore().batch();
      let count = 0;

      for (const doc of snapshot.docs) {
        batch.delete(doc.ref);
        count++;
        if (count === 500) {
          commits.push(batch.commit());
          batch = admin.firestore().batch();
          count = 0;
        }
      }
      if (count > 0) {
        commits.push(batch.commit());
      }

      await Promise.all(commits);
      console.log(
          `${snapshot.size} adet eski notificationRequests dokümanı silindi.`,
      );
    },
);
