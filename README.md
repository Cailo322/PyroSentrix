# pyrosentrixapp

PyroSentrix Mobile Application
PyroSentrix is a mobile application that connects to a custom IoT-based multi-sensor fire alarm system through Firebase Firestore. It fetches and displays:

Sensor values (e.g., Carbon Monoxide, Humidity, IAQ, Smoke, Temperature)

Alarm logs

Smart notifications

Threshold values (researched and approved by an expert)

Device status

The app provides users with real-time monitoring, immediate alarms, predictive fire risk warnings, and emergency assistance tools — all designed to enhance fire safety.

Features
🔥 Real-Time Monitoring
Continuously displays live sensor data sent by the IoT device.

🔥 Smart Fire Detection (LSTM Integration)
Integrated with a Long Short-Term Memory (LSTM) model trained on 60,000+ rows of real-world sensor data.

Achieved an R² score of 83% during model evaluation.

Sends smart notifications when predicted sensor values show an upward trend, indicating an increased fire risk.

🔥 Threshold-Based Alarms
Instant alerts when actual sensor readings exceed predefined critical thresholds.

Thresholds are carefully researched and validated by an expert to ensure reliable fire detection.

🔥 Fire Station Locator
Integrated with Google APIs to automatically fetch the four nearest fire stations based on the user's address.

Displays the fire stations' names and contact numbers for quick emergency access.

About the IoT Device
The PyroSentrix IoT device is a custom-built multi-sensor fire detection unit designed for home and kitchen environments.
It continuously collects environmental data to detect early signs of fire through:

Direct threshold checks (immediate alarm)

Predictive trend analysis (smart warning)

The device sends sensor data to Firebase Firestore every 10 seconds, ensuring real-time updates to the mobile app.

Technologies Used
Flutter (Mobile Application)

Firebase Firestore (Real-time database)

Python (LSTM Model) (Cloud function integration)

Google APIs (Fire station locator)
