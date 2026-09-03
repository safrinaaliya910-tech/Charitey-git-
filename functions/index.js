const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const { Resend } = require("resend");

admin.initializeApp();

const RESEND_API_KEY = defineSecret("RESEND_API_KEY");
const FROM_EMAIL = "Fourth Idly <support@fourthidly.com>";

// ══════════════════════════════════════════════════════
// EXISTING: PUSH NOTIFICATIONS (unchanged)
// ══════════════════════════════════════════════════════

const notificationContent = {
  donation_offer: {
    title: "Donation Offer",
    body: (n) => n.message || "You have a new donation offer.",
  },
  tag: {
    title: "You were tagged",
    body: (n) => n.message || `${n.senderName || "Someone"} tagged you.`,
  },
  volunteer_accepted: {
    title: "Volunteer Assigned",
    body: (n) => n.message || `${n.senderName || "A volunteer"} accepted the task.`,
  },
  volunteer_expired: {
    title: "No Volunteer Found",
    body: (n) => n.message || "No volunteer accepted the pickup in time.",
  },
  new_task_available: {
    title: "New Pickup Task Available 🛵",
    body: (n) => n.message || "A new donation is ready for pickup.",
  },
  urgent_task: {
    title: "Urgent: Volunteer Needed! 🚨",
    body: (n) => n.message || "A donation needs urgent pickup.",
  },
  delivery_arrived: {
    title: "Delivery Arrived 📦",
    body: (n) => n.message || `${n.senderName || "Volunteer"} has delivered the items.`,
  },
  payment_pending: {
    title: "Payment Required",
    body: (n) => n.message || "Please complete the delivery payment.",
  },
  verify_payment: {
    title: "Verify Payment",
    body: (n) => n.message || "Please confirm if you received the payment.",
  },
  payment_rejected: {
    title: "Payment Under Review",
    body: (n) => n.message || "Volunteer reported payment not received.",
  },
  payment_verified: {
    title: "Payment Verified 🎉",
    body: (n) => n.message || "Volunteer confirmed receipt of payment.",
  },
  payment_dispute: {
    title: "Payment Dispute",
    body: (n) => n.message || "A payment dispute needs admin review.",
  },
  donation_cancelled: {
    title: "Donation Cancelled",
    body: (n) => n.message || `${n.senderName || "Donor"} cancelled the donation.`,
  },
  expired_request: {
    title: "Request Expired",
    body: (n) => n.message || "Your request has expired.",
  },
  new_message: {
    title: "New Message",
    body: (n) => n.senderName ? `New message from ${n.senderName}` : "You have a new message.",
  },
};

function buildPushMessage(token, notification, content) {
  return {
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
        priority: "high",
        defaultSound: true,
        defaultVibrateTimings: true,
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          contentAvailable: true,
          badge: 1,
        },
      },
      headers: {
        "apns-priority": "10",
      },
    },
    data: {
      notificationId: String(notification.id || ""),
      notificationType: String(notification.type || "general"),
      relatedItemId: String(notification.relatedItemId || ""),
      click_action: "FLUTTER_NOTIFICATION_CLICK",
      title: content.title,
      message: content.body(notification),
    },
  };
}

async function createAndBroadcastTaskNotifications({ donationId, type, title, message }) {
  const dispatchId = `${type}_${donationId}`;
  const dispatchRef = admin.firestore().collection("notification_broadcasts").doc(dispatchId);

  try {
    await admin.firestore().runTransaction(async (tx) => {
      const snap = await tx.get(dispatchRef);
      if (snap.exists) throw new Error("ALREADY_SENT");
      tx.create(dispatchRef, {
        type,
        relatedItemId: donationId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
  } catch (e) {
    if (e.message === "ALREADY_SENT") {
      console.log("Already broadcasted →", dispatchId);
      return;
    }
    throw e;
  }

  const volunteers = await admin.firestore()
    .collection("users")
    .where("role", "==", "volunteer")
    .get();

  const batch = admin.firestore().batch();
  const tokens = [];

  for (const doc of volunteers.docs) {
    const data = doc.data();
    const notifId = admin.firestore().collection("notifications").doc().id;

    batch.set(admin.firestore().collection("notifications").doc(notifId), {
      id: notifId,
      receiverId: doc.id,
      senderId: "system",
      senderName: type === "urgent_task" ? "Urgent Alert" : "New Task",
      type,
      title,
      message,
      relatedItemId: donationId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    });

    if (data.fcmToken && typeof data.fcmToken === "string" && data.fcmToken.length > 10) {
      tokens.push(data.fcmToken);
    }
  }

  await batch.commit();
  console.log(`Created ${volunteers.size} in-app notifications for ${type}`);

  const content = notificationContent[type];
  if (!content || tokens.length === 0) return;

  for (let i = 0; i < tokens.length; i += 500) {
    const batchTokens = tokens.slice(i, i + 500);
    const base = buildPushMessage(batchTokens[0], {
      id: donationId,
      type,
      relatedItemId: donationId,
      message,
    }, content);
    delete base.token;

    const res = await admin.messaging().sendEachForMulticast({
      tokens: batchTokens,
      ...base,
    });
    console.log(`${type} push → success: ${res.successCount}, fail: ${res.failureCount}`);
  }
}

exports.sendNotificationPush = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const data = event.data?.data();
    const notificationId = event.params.notificationId;
    if (!data) return null;

    const type = data.type;
    const content = notificationContent[type];
    if (!content) {
      console.log("Unsupported type, skipping:", type);
      return null;
    }

    if (type === "new_task_available" || type === "urgent_task") {
      return null;
    }

    const notification = { ...data, id: notificationId };

    try {
      const receiverId = data.receiverId;
      if (!receiverId) {
        console.log("No receiverId");
        return null;
      }

      const userDoc = await admin.firestore().collection("users").doc(receiverId).get();
      const user = userDoc.data() || {};

      if (type === "donation_offer" && (user.role || "").toLowerCase() === "ngo") {
        console.log("Skipping donation_offer for NGO (handled separately)");
        return null;
      }

      const token = user.fcmToken;
      if (!token || typeof token !== "string" || token.length < 10) {
        console.log("No valid FCM token for", receiverId);
        return null;
      }

      await admin.messaging().send(buildPushMessage(token, notification, content));
      console.log("✅ Push sent:", type, "→", receiverId);
    } catch (err) {
      console.error("❌ Push error:", err);
    }

    return null;
  }
);

exports.onDonationTaskFlag = onDocumentUpdated(
  "donations/{donationId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    const donationId = event.params.donationId;

    if (!after) return null;

    if (after.newTaskNotified === true && before?.newTaskNotified !== true) {
      await createAndBroadcastTaskNotifications({
        donationId,
        type: "new_task_available",
        title: "New Pickup Task Available 🛵",
        message: after.newTaskItemName
          ? `A new donation of ${after.newTaskItemName} in ${after.newTaskLocation || "your area"} is ready for pickup.`
          : "A new donation is ready for pickup.",
      });
    }

    if (after.urgentNotified === true && before?.urgentNotified !== true) {
      await createAndBroadcastTaskNotifications({
        donationId,
        type: "urgent_task",
        title: "Urgent: Volunteer Needed! 🚨",
        message: after.urgentItemName
          ? `A donation of ${after.urgentItemName} in ${after.urgentLocation || "your area"} needs pickup within 24 hours!`
          : "A donation needs urgent pickup.",
      });
    }

    return null;
  }
);

exports.sendDonationNotification = onDocumentCreated(
  "donations/{donationId}",
  async (event) => {
    const donation = event.data?.data();
    const donationId = event.params.donationId;
    if (!donation?.ngoId) return null;

    try {
      const ngoDoc = await admin.firestore().collection("users").doc(donation.ngoId).get();
      const token = ngoDoc.data()?.fcmToken;
      if (!token) return null;

      const itemName = donation.productName || donation.foodType || "items";
      const quantity = `${donation.quantity || ""} ${donation.unit || ""}`.trim();

      await admin.messaging().send({
        token,
        notification: {
          title: "New Donation Offer! 🎉",
          body: `A donor offered ${quantity} of ${itemName}.`,
        },
        android: {
          priority: "high",
          notification: {
            sound: "default",
            channelId: "high_importance_channel",
            priority: "high",
          },
        },
        apns: {
          payload: { aps: { sound: "default", contentAvailable: true } },
          headers: { "apns-priority": "10" },
        },
        data: {
          notificationId: donationId,
          notificationType: "donation_offer",
          relatedItemId: donationId,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      });
      console.log("✅ Donation push sent to NGO");
    } catch (e) {
      console.error(e);
    }
    return null;
  }
);

// ══════════════════════════════════════════════════════
// NEW: EMAIL FUNCTIONS (Resend)
// ══════════════════════════════════════════════════════

// ---------- 1. FORGOT PASSWORD (replaces Cloudflare Worker) ----------
exports.sendPasswordReset = onCall({ secrets: [RESEND_API_KEY] }, async (request) => {
  const email = request.data?.email?.trim();
  if (!email) {
    throw new HttpsError("invalid-argument", "Email is required.");
  }

  let resetLink;
  try {
    resetLink = await admin.auth().generatePasswordResetLink(email, {
      url: "https://fourthidly.com",
    });
  } catch (err) {
    console.error("generatePasswordResetLink error:", err.code, err.message);
    if (err.code === "auth/user-not-found") {
      throw new HttpsError("not-found", "No account found with this email address.");
    }
    if (err.code === "auth/invalid-email") {
      throw new HttpsError("invalid-argument", "The email address is not valid.");
    }
    throw new HttpsError("internal", "Something went wrong. Please try again.");
  }

  const resend = new Resend(RESEND_API_KEY.value());
  try {
    await resend.emails.send({
      from: FROM_EMAIL,
      to: email,
      subject: "Reset your Fourth Idly password",
      html: buildPasswordResetHtml(resetLink),
    });
  } catch (err) {
    console.error("Resend send error:", err);
    throw new HttpsError("internal", "Couldn't send the reset email. Please try again.");
  }

  return { success: true };
});

function buildPasswordResetHtml(link) {
  return `
  <div style="font-family: Arial, sans-serif; max-width:480px; margin:auto; padding:32px 24px; color:#2D3142;">
    <h2 style="color:#8C4149;">Reset your password</h2>
    <p>We received a request to reset the password for your Fourth Idly account.</p>
    <p style="text-align:center; margin:32px 0;">
      <a href="${link}" style="background:#8C4149;color:#fff;padding:14px 28px;border-radius:30px;text-decoration:none;font-weight:bold;display:inline-block;">
        Reset Password
      </a>
    </p>
    <p style="font-size:13px;color:#888;">If you didn't request this, you can safely ignore this email. This link will expire soon for your security.</p>
    <p style="font-size:13px;color:#888;">— The Fourth Idly Team</p>
  </div>`;
}

// ---------- 2. NGO / VOLUNTEER APPROVAL EMAIL ----------
exports.onUserApproved = onDocumentUpdated(
  { document: "users/{uid}", secrets: [RESEND_API_KEY] },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!before || !after) return;

    const role = (after.role || "").toLowerCase();
    if (role !== "ngo" && role !== "volunteer") return;

    const statusBefore = (before.status || "").toLowerCase();
    const statusAfter = (after.status || "").toLowerCase();

    const justApproved =
      statusBefore !== statusAfter &&
      (statusAfter === "approved" || statusAfter === "active");
    if (!justApproved) return;

    const email = after.email;
    const name = after.name || "there";
    if (!email) return;

    const resend = new Resend(RESEND_API_KEY.value());
    try {
      await resend.emails.send({
        from: FROM_EMAIL,
        to: email,
        subject: "You're verified! Welcome to Fourth Idly 🎉",
        html: buildApprovalHtml(name, role),
      });
      console.log("✅ Approval email sent to", email);
    } catch (err) {
      console.error("Resend approval email error:", err);
    }
  }
);

function buildApprovalHtml(name, role) {
  const roleLabel = role === "ngo" ? "NGO" : "Volunteer";
  return `
  <div style="font-family: Arial, sans-serif; max-width:480px; margin:auto; padding:32px 24px; color:#2D3142;">
    <h1 style="color:#8C4149;">You're verified, ${name}! 🎉</h1>
    <p>Great news — your ${roleLabel} account on <strong>Fourth Idly</strong> has been reviewed and approved.</p>
    <p>You're all set to jump back into the app and start making a real difference in your community.</p>
    <p style="text-align:center; margin:32px 0;">
      <a href="https://fourthidly.com" style="background:#8C4149;color:#fff;padding:14px 28px;border-radius:30px;text-decoration:none;font-weight:bold;display:inline-block;">
        Open Fourth Idly
      </a>
    </p>
    <p>Thank you for being part of this mission — let's make an impact together.</p>
    <p style="font-size:13px;color:#888;">— The Fourth Idly Team</p>
  </div>`;
}

// ---------- 3. DONOR / TRAVEL AGENCY WELCOME EMAIL ----------
exports.sendWelcomeEmail = onCall({ secrets: [RESEND_API_KEY] }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }

  const userRef = admin.firestore().collection("users").doc(uid);
  const userDoc = await userRef.get();
  if (!userDoc.exists) {
    throw new HttpsError("not-found", "User profile not found.");
  }

  const data = userDoc.data();
  const email = data.email;
  const name = data.name || "there";

  if (!email) {
    throw new HttpsError("failed-precondition", "No email on file.");
  }

  if (data.welcomeEmailSent === true) {
    return { success: true, alreadySent: true };
  }

  const resend = new Resend(RESEND_API_KEY.value());
  try {
    await resend.emails.send({
      from: FROM_EMAIL,
      to: email,
      subject: "Welcome to Fourth Idly! 🎉",
      html: buildWelcomeHtml(name),
    });
    await userRef.update({ welcomeEmailSent: true });
  } catch (err) {
    console.error("Resend welcome email error:", err);
    throw new HttpsError("internal", "Couldn't send the welcome email.");
  }

  return { success: true };
});

function buildWelcomeHtml(name) {
  return `
  <div style="font-family: Arial, sans-serif; max-width:480px; margin:auto; padding:32px 24px; color:#2D3142;">
    <h1 style="color:#8C4149;">Welcome to Fourth Idly, ${name}! 🎉</h1>
    <p>Your account is verified and ready to go.</p>
    <p>You're now part of a community connecting donors, NGOs, and volunteers to make real change happen — one act of generosity at a time.</p>
    <p style="text-align:center; margin:32px 0;">
      <a href="https://fourthidly.com" style="background:#8C4149;color:#fff;padding:14px 28px;border-radius:30px;text-decoration:none;font-weight:bold;display:inline-block;">
        Start Making an Impact
      </a>
    </p>
    <p style="font-size:13px;color:#888;">— The Fourth Idly Team</p>
  </div>`;
}