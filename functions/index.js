const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendNotificationRequest = functions.firestore
  .document("notificationRequests/{requestId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();

    const toEmail = data.toEmail;
    const title = data.title || "Bildirim";
    const body = data.body || "";

    if (!toEmail) {
      await snap.ref.update({ status: "failed", error: "toEmail missing" });
      return;
    }

    const usersSnapshot = await admin
      .firestore()
      .collection("users")
      .where("email", "==", toEmail)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      await snap.ref.update({ status: "failed", error: "user not found" });
      return;
    }

    const userData = usersSnapshot.docs[0].data();
    const token = userData.fcmToken;

    if (!token) {
      await snap.ref.update({ status: "failed", error: "fcmToken missing" });
      return;
    }

    await admin.messaging().send({
      token: token,
      notification: {
        title: title,
        body: body,
      },
    });

    await snap.ref.update({
      status: "sent",
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });