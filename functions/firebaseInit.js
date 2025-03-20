// firebaseInit.js
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");

// Initialize Firebase Admin SDK
const app = initializeApp();

// Initialize Firestore and Storage
const db = getFirestore(app);
const storage = getStorage(app);

// Export the initialized services
module.exports = { app, db, storage };