const functions = require("firebase-functions");
const { onObjectFinalized } = require("firebase-functions/v2/storage");

// Import the shared Firebase initialization
const { db, storage } = require("./firebaseInit");

// Import the predictEvery1Minute function from lstm.js
const { predictEvery1Minute } = require("./lstm");

// Image Upload Function
exports.onImageUpload = onObjectFinalized(
  {
    region: "asia-southeast1",
    bucket: "firedetection-640fa.appspot.com",
  },
  async (event) => {
    try {
      const object = event.data;
      const filePath = object.name;
      const bucket = event.bucket;
      const pathParts = filePath.split("/");

      // Validate path structure
      if (pathParts.length < 2) {
        console.log(`Skipping file: ${filePath} (not inside a folder)`);
        return;
      }

      const folderName = pathParts[0];
      const imageName = pathParts.pop();
      const fileExtension = imageName.split('.').pop().toLowerCase();
      const validExtensions = ['jpg', 'jpeg', 'png', 'gif'];

      // Validate image type
      if (!validExtensions.includes(fileExtension)) {
        console.log(`Skipping non-image file: ${filePath}`);
        return;
      }

      const file = storage.bucket(bucket).file(filePath);

      // Make public if needed (consider security implications)
      await file.makePublic();

      const imageUrl = `https://storage.googleapis.com/${bucket}/${filePath}`;
      const timestamp = object.timeCreated;

      // Use image name as document ID to prevent duplicates
      await db.collection(folderName).doc(imageName).set({
        imageName: imageName,
        imageUrl: imageUrl,
        timestamp: timestamp,
        contentType: object.contentType,
        size: object.size,
        updated: new Date() // Add last updated timestamp
      }, { merge: true });

      console.log(`Image metadata added/updated in '${folderName}' collection for ${imageName}`);
    } catch (error) {
      console.error("Error processing image upload:", error);
      // Consider throwing error to retry for certain error types
      if (error.code === 429 || error.code === 500) {
        throw new functions.https.HttpsError('internal', 'Retryable error', error);
      }
    }
  }
);

// Export the predictEvery1Minute function
exports.predictEvery1Minutes = predictEvery1Minute;