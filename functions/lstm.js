const axios = require("axios");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { db } = require("./firebaseInit");

const endpointUrl = "https://asia-southeast2-aiplatform.googleapis.com/v1/projects/firedetection-640fa/locations/asia-southeast2/endpoints/8477151087269249024:predict";

const minMaxValues = {
  carbon_monoxide: { min: 0.0, max: 16.3 },
  humidity_dht22: { min: 35.5, max: 82.4 },
  indoor_air_quality: { min: 0, max: 161 },
  smoke_level: { min: 0, max: 5 },
  temperature_dht22: { min: 30.4, max: 42.7 },
  temperature_mlx90614: { min: 28.45, max: 40.29 },
};

exports.predictEvery1Minute = onSchedule(
  {
    schedule: "every 1 minutes",
    region: "asia-southeast1",
    timeZone: "Asia/Singapore",
  },
  async (event) => {
    try {
      const sensorDataRef = db.collection("SensorData").doc("FireAlarm");
      const productCodesSnapshot = await sensorDataRef.listCollections();

      for (const productCodeCollection of productCodesSnapshot) {
        const productCode = productCodeCollection.id;
        const snapshot = await productCodeCollection
          .orderBy("timestamp", "desc")
          .limit(4)
          .get();

        if (snapshot.empty) {
          console.log(`No sensor data found for product code: ${productCode}`);
          continue;
        }

        const latestDocTimestamp = snapshot.docs[0].data().timestamp;
        const lastProcessedRef = db
          .collection("LSTM")
          .doc("Metadata")
          .collection(productCode)
          .doc("lastProcessed");
        const lastProcessedDoc = await lastProcessedRef.get();

        if (lastProcessedDoc.exists && lastProcessedDoc.data().timestamp === latestDocTimestamp) {
          console.log(`No new data to process for product code: ${productCode}. Latest data already processed.`);
          continue;
        }

        const sensorData = [];
        snapshot.docs.reverse().forEach((doc) => {
          const data = doc.data();
          sensorData.push([
            scaleValue(data.carbon_monoxide, minMaxValues.carbon_monoxide),
            scaleValue(data.humidity_dht22, minMaxValues.humidity_dht22),
            scaleValue(data.indoor_air_quality, minMaxValues.indoor_air_quality),
            scaleValue(data.smoke_level, minMaxValues.smoke_level),
            scaleValue(data.temperature_dht22, minMaxValues.temperature_dht22),
            scaleValue(data.temperature_mlx90614, minMaxValues.temperature_mlx90614),
          ]);
        });

        if (sensorData.length !== 4) {
          console.log(`Not enough sensor data for product code: ${productCode}. Need exactly 4 timesteps.`);
          continue;
        }

        console.log(`Scaled Sensor Data for ${productCode}:`, JSON.stringify(sensorData, null, 2));

        const instances = [sensorData];
        const requestBody = { instances: instances };
        console.log("Request Body:", JSON.stringify(requestBody, null, 2));

        const accessToken = await getAccessToken();
        console.log("Access Token:", accessToken);

        const response = await axios.post(endpointUrl, requestBody, {
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
        });

        console.log("Predictions from Vertex AI:", JSON.stringify(response.data.predictions, null, 2));

        const predictions = response.data.predictions[0];
        if (predictions && predictions.length > 0) {
          const batch = db.batch();
          const predictionsRef = db.collection("LSTM").doc("Predictions").collection(productCode);

          for (let i = 0; i < predictions.length; i++) {
            const unscaledPrediction = {
              carbon_monoxide: roundToDecimal(unscaleValue(predictions[i][0], minMaxValues.carbon_monoxide), 1),
              humidity_dht22: roundToDecimal(unscaleValue(predictions[i][1], minMaxValues.humidity_dht22), 1),
              indoor_air_quality: Math.round(unscaleValue(predictions[i][2], minMaxValues.indoor_air_quality)),
              smoke_level: roundToDecimal(unscaleValue(predictions[i][3], minMaxValues.smoke_level), 2),
              temperature_dht22: roundToDecimal(unscaleValue(predictions[i][4], minMaxValues.temperature_dht22), 1),
              temperature_mlx90614: roundToDecimal(unscaleValue(predictions[i][5], minMaxValues.temperature_mlx90614), 1),
              timestamp: new Date(Date.now() + (i + 1) * 10000).toISOString(), // Changed to 10s intervals
            };
            batch.set(predictionsRef.doc(), unscaledPrediction);
            console.log(`Unscaled Prediction ${i + 1} stored in Firestore for ${productCode}:`, JSON.stringify(unscaledPrediction, null, 2));
          }
          await batch.commit();
        } else {
          console.log("No predictions returned from Vertex AI.");
        }

        await lastProcessedRef.set({ timestamp: latestDocTimestamp });
        console.log(`Updated last processed timestamp for product code: ${productCode}`);
      }
      console.log("Processing completed for all product codes.");
    } catch (error) {
      console.error("Error in Cloud Function:", error);
      if (error.response) {
        console.error("Response Data:", error.response.data);
        console.error("Response Status:", error.response.status);
        console.error("Response Headers:", error.response.headers);
      } else if (error.request) {
        console.error("Request Data:", error.request);
      } else {
        console.error("Error Message:", error.message);
      }
    }
  }
);

async function getAccessToken() {
  const { GoogleAuth } = require("google-auth-library");
  const auth = new GoogleAuth({
    scopes: "https://www.googleapis.com/auth/cloud-platform",
  });
  return await auth.getAccessToken();
}

function scaleValue(value, minMax) {
  return (value - minMax.min) / (minMax.max - minMax.min);
}

function unscaleValue(scaledValue, minMax) {
  return scaledValue * (minMax.max - minMax.min) + minMax.min;
}

function roundToDecimal(value, decimalPlaces) {
  const factor = Math.pow(10, decimalPlaces);
  return Math.round(value * factor) / factor;
}