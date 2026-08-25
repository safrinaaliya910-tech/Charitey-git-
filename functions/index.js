//functions/index.js:
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

const notificationContent = {
  donation_offer: {
    title: "Donation confirmed",
    body: (notification) => notification.message || "Your donation offer was recorded.",
  },
  tag: {
    title: "You were tagged in a post",
    body: (notification) => notification.message || `${notification.senderName || "Someone"} tagged you in a post.`,
  },
  volunteer_accepted: {
    title: "Volunteer assigned",
    body: (notification) => notification.message || `${notification.senderName || "A volunteer"} accepted the pickup task.`,
  },
  volunteer_expired: {
    title: "Pickup task expired",
    body: (notification) => notification.message || "No volunteer accepted the pickup task in time.",
  },
  new_task_available: {
    title: "New pickup task available",
    body: (notification) => notification.message || "A new donation is ready for pickup.",
  },
  urgent_task: {
    title: "Urgent volunteer task",
    body: (notification) => notification.message || "A donation needs urgent pickup.",
  },
  delivery_arrived: {
    title: "Delivery arrived",
    body: (notification) => notification.message || `${notification.senderName || "The volunteer"} delivered the donation.`,
  },
  payment_pending: {
    title: "Payment required",
    body: (notification) => notification.message || "Please complete the volunteer delivery payment.",
  },
  verify_payment: {
    title: "Payment verification requested",
    body: (notification) => notification.message || `${notification.senderName || "The donor"} requested payment verification.`,
  },
  payment_rejected: {
    title: "Payment not received",
    body: (notification) => notification.message || "The volunteer reported that payment was not received.",
  },
  payment_verified: {
    title: "Payment verified",
    body: (notification) => notification.message || "The volunteer confirmed receipt of payment.",
  },
  donation_cancelled: {
    title: "Donation cancelled",
    body: (notification) => notification.message || `${notification.senderName || "The donor"} cancelled the donation.`,
  },
  expired_request: {
    title: "Request expired",
    body: (notification) => notification.message || "Your donation request has expired.",
  },
  new_message: {
    title: "New message",
    body: (notification) => notification.senderName
      ? `You have a new message from ${notification.senderName}.`
      : "You have a new message.",
  },
};

const pushMessage = (token, notification, content) => ({
  token,
  notification: {
    title: content.title,
    body: content.body(notification),
  },
  android: {
    priority: "high",
    notification: {
      sound: "default",
      channelId: "high_importance_channel",
    },
  },
  apns: {
    payload: {
      aps: {
        sound: "default",
        contentAvailable: true,
      },
    },
  },
  data: {
    notificationId: notification.id || "",
    notificationType: notification.type || "general",
    relatedItemId: notification.relatedItemId || "",
    click_action: "FLUTTER_NOTIFICATION_CLICK",
  },
});

async function sendVolunteerBroadcast(notification) {
  const dispatchId = `${notification.type}_${notification.relatedItemId || notification.id}`;
  const dispatchRef = admin.firestore().collection("notification_broadcasts").doc(dispatchId);

  try {
    await admin.firestore().runTransaction(async (transaction) => {
      const dispatch = await transaction.get(dispatchRef);
      if (dispatch.exists) throw new Error("Broadcast already dispatched");
      transaction.create(dispatchRef, {
        type: notification.type,
        relatedItemId: notification.relatedItemId || null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
  } catch (error) {
    if (error.message === "Broadcast already dispatched") return;
    throw error;
  }

  const volunteerSnapshot = await admin.firestore()
    .collection("users")
    .where("role", "==", "volunteer")
    .get();
  const tokens = volunteerSnapshot.docs
    .map((doc) => doc.data()?.fcmToken)
    .filter((token) => typeof token === "string" && token.length > 0);

  for (let index = 0; index < tokens.length; index += 500) {
    const batchTokens = tokens.slice(index, index + 500);
    if (batchTokens.length === 0) continue;

    const multicastMessage = pushMessage(
      batchTokens[0],
      notification,
      notificationContent[notification.type],
    );
    delete multicastMessage.token;

    const response = await admin.messaging().sendEachForMulticast({
      tokens: batchTokens,
      ...multicastMessage,
    });
    console.log(`Sent ${response.successCount} ${notification.type} push notifications.`);
  }
}

exports.sendDonationNotification = onDocumentCreated(
  "donations/{donationId}",
  async (event) => {
    const donation = event.data?.data();
    const donationId = event.params.donationId;

    if (!donation?.ngoId) return null;

    try {
      const ngoDoc = await admin.firestore()
        .collection("users")
        .doc(donation.ngoId)
        .get();

      const fcmToken = ngoDoc.data()?.fcmToken;

      if (!fcmToken) {
        console.log("No FCM token found for NGO:", donation.ngoId);
        return null;
      }

      const itemName = donation.productName || donation.foodType || "items";
      const quantity = `${donation.quantity || ""} ${donation.unit || ""}`.trim();

      const message = {
        token: fcmToken,
        notification: {
          title: "New Donation Request! 🎉",
          body: `A donor has offered ${quantity} of ${itemName}. Open the app to view details.`,
        },
        android: {
          priority: "high",
          notification: {
            sound: "default",
            channelId: "high_importance_channel",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              contentAvailable: true,
            },
          },
        },
        data: {
          notificationId: donationId,
          notificationType: "donation_offer",
          relatedItemId: donationId,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      };

      await admin.messaging().send(message);
      console.log("Donation notification sent successfully to", donation.ngoId);
    } catch (error) {
      console.error("Error sending notification:", error);
    }

    return null;
  },
);

exports.sendNotificationPush = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const notification = event.data?.data();
    const notificationId = event.params.notificationId;
    const type = notification?.type;
    const content = notificationContent[type];

    if (!content) {
      console.log("Skipping unsupported notification type:", type);
      return null;
    }

    try {
      if (type === "new_task_available" || type === "urgent_task") {
        await sendVolunteerBroadcast({
          ...notification,
          id: notificationId,
        });
        return null;
      }

      const recipientId = notification?.receiverId;
      if (!recipientId) {
        console.log("Skipping notification without receiverId:", notificationId);
        return null;
      }

      const recipientDoc = await admin.firestore()
        .collection("users")
        .doc(recipientId)
        .get();
      const recipient = recipientDoc.data() || {};

      if (type === "donation_offer" && recipient.role?.toLowerCase() === "ngo") {
        return null;
      }

      const token = recipient.fcmToken;
      if (!token) {
        console.log("No FCM token for notification recipient:", recipientId);
        return null;
      }

      await admin.messaging().send(
        pushMessage(
          token,
          {
            ...notification,
            id: notificationId,
          },
          content,
        ),
      );

      console.log("Notification push sent:", type, "to", recipientId);
    } catch (error) {
      console.error("Error sending notification push:", error);
    }

    return null;
  },
);