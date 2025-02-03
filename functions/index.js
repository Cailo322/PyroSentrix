const { onObjectFinalized } = require("firebase-functions/v2/storage");
const { getFirestore } = require("firebase-admin/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getStorage } = require("firebase-admin/storage");

initializeApp(); // Initialize Firebase Admin SDK
const db = getFirestore(); // Get Firestore instance
const storage = getStorage(); // Get Firebase Storage instance

exports.onImageUpload = onObjectFinalized(
  {
    region: "asia-southeast1", // Match the bucket's region
    bucket: "firedetection-640fa.appspot.com", // Your bucket name
  },
  async (event) => {
    try {
      const object = event.data; // Get the uploaded object metadata
      const filePath = object.name; // Path of the uploaded file in the bucket
      const bucket = event.bucket; // The bucket where the file resides
      const imageName = filePath.split("/").pop(); // Extract the image file name
      const file = storage.bucket(bucket).file(filePath); // Get the file reference

      // Make the file publicly accessible
      await file.makePublic();

      // Construct the public image URL
      const imageUrl = `https://storage.googleapis.com/${bucket}/${filePath}`;
      const timestamp = object.timeCreated; // Upload timestamp

      // Add metadata to Firestore under the 'camera' collection
      await db.collection("camera").add({
        imageName: imageName,
        imageUrl: imageUrl,
        timestamp: timestamp,
      });

      console.log(`Image metadata added to Firestore for ${imageName}`);
    } catch (error) {
      console.error("Error adding image metadata to Firestore:", error);
    }
  }
);
