const {onDocumentCreated} = require("firebase-functions/v2/firestore");
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
          console.error(
              `notificationRequests/${requestId}: geçerli hedef kullanıcı yok`,
          );
          await requestRef.delete();
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
          console.error(
              `notificationRequests/${requestId}: hiçbir hedef kullanıcının fcmToken'ı yok`,
          );
          await requestRef.delete();
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
        response.responses.forEach((result, index) => {
          if (result.success) return;

          const token = tokens[index];
          console.error(
              `notificationRequests/${requestId}: token gönderim hatası ` +
              `(${token}): ${result.error}`,
          );

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
        await requestRef.delete();
      } catch (error) {
        console.error(
            `notificationRequests/${requestId} işlenirken hata: ${error}`,
        );
        try {
          await requestRef.delete();
        } catch (deleteError) {
          console.error(
              `notificationRequests/${requestId} silinemedi: ${deleteError}`,
          );
        }
      }
    },
);
