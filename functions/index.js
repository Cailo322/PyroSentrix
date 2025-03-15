const { onObjectFinalized } = require("firebase-functions/v2/storage");
const { getFirestore } = require("firebase-admin/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getStorage } = require("firebase-admin/storage");

initializeApp(); // Initialize Firebase Admin SDK
const db = getFirestore(); // Get Firestore instance
const storage = getStorage(); // Get Firebase Storage instance

exports.onImageUpload = onObjectFinalized(
  {
    region: "asia-southeast1",
    bucket: "firedetection-640fa.appspot.com",
  },
  async (event) => {
    try {
      const object = event.data;
      const filePath = object.name; // Full file path in the bucket
      const bucket = event.bucket;
      const imageName = filePath.split("/").pop(); // Extract the file name
      const pathParts = filePath.split("/"); // Split the file path into parts

      // Ensure the file is inside a folder
      if (pathParts.length < 2) {
        console.log(`Skipping file: ${filePath} (not inside a folder)`);
        return;
      }

      const folderName = pathParts[0]; // Get the first folder in the path
      const file = storage.bucket(bucket).file(filePath);

      // Make the file publicly accessible
      await file.makePublic();

      // Construct the public image URL
      const imageUrl = `https://storage.googleapis.com/${bucket}/${filePath}`;
      const timestamp = object.timeCreated; // Upload timestamp

      // Add metadata to Firestore under the collection matching the folder name
      await db.collection(folderName).add({
        imageName: imageName,
        imageUrl: imageUrl,
        timestamp: timestamp,
      });

      console.log(`Image metadata added to Firestore under '${folderName}' collection for ${imageName}`);
    } catch (error) {
      console.error("Error adding image metadata to Firestore:", error);
    }
  }
);
