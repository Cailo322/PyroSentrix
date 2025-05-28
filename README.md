# 🔥 PyroSentrix  
*A Mobile Monitoring Application with Multi-Sensor IoT Fire Detection Using LSTM Prediction*

---

## 🚀 Project Overview

**PyroSentrix** is a smart fire monitoring system that integrates a multi-sensor IoT device with a mobile application, enhanced by machine learning (LSTM). The system is designed to **advance traditional fire alarm systems** by providing **real-time sensor data, intelligent early warnings, and user-friendly mobile monitoring** — reducing fire-related risks before they escalate.

---

## 🎯 Objectives

- Improve fire detection accuracy and responsiveness
- Provide predictive fire risk alerts using LSTM
- Enable mobile monitoring of real-time sensor data
- Assist in proactive decision-making through smart insights and visualizations

---

## 📦 Key Features

### 🔧 IoT Device (ESP32-based)
- Equipped with **5 sensors**:  
  - 🔥 Temperature  
  - 💨 Smoke  
  - ☠️ Carbon Monoxide (CO)  
  - 🌫️ Air Quality  
  - 💧 Humidity  
- 📸 **Built-in Camera**: Automatically captures an image when the alarm is triggered.
- 📶 **Wi-Fi Setup via QR Code** for easy connectivity.

### 📱 Mobile Application (Flutter)
- **Live Sensor Dashboard**  
  - Displays real-time sensor values using color-coded levels based on thresholds.
- **Immediate Alarm Notification**  
  - Sounds an alarm on both the device and mobile app  
  - Captures and displays the image from the IoT device
- **Smart Prediction Alerts (LSTM-based)**  
  - LSTM model trained on 60,000+ real sensor readings (R² score: **85%**)  
  - Predicts **rising trends in sensor data** to alert users *before* danger thresholds are reached
- **Fire Station Locator**  
  - Uses **Google Maps API** to fetch contact info for the **4 nearest fire stations** based on user location
- **Alarm History**  
  - Saves past incident logs and alarm triggers
- **Device Controls**  
  - Remotely **reset** or **hush** the alarm from the mobile app
- **Household Sharing**  
  - Owners can **invite household members** to monitor the device from their own phones
- **Data Visualization & Insights**  
  - Built-in dashboard with user-friendly visualizations and analytics

---

## 🧠 LSTM Integration

- Trained using **Python on Google Colab**
- Deployed using **Google Cloud Platform (GCP)**
- Powered by data collected from the IoT device and stored in **BigQuery**
- Predicts sensor value trends to generate **early warning notifications** before critical levels are reached
- Achieved **85% R² score** on test data

---

## ☁️ Cloud Architecture

| Component              | Platform/Tool                 |
|------------------------|-------------------------------|
| Realtime DB            | Firebase Firestore            |
| Hosting & Functions    | Firebase / Google Cloud       |
| ML Model Deployment    | Google Cloud Platform (GCP)   |
| Data Storage for ML    | BigQuery                      |
| Maps & Location        | Google Maps API               |

---

## 🛠 Tech Stack

| Layer        | Tools Used                           |
|--------------|--------------------------------------|
| IoT Hardware | ESP32, DHT11, MQ2, MQ135, Camera     |
| Backend      | Firebase Firestore, Cloud Functions  |
| Frontend     | Flutter (Dart)                       |
| ML Model     | Python (LSTM, Google Colab)          |
| Cloud Tools  | Google Cloud Platform, BigQuery, Maps API |

---

## 📈 Future Improvements

- Fine-tune LSTM for multi-class fire risk classification  
- Add SMS or voice-call alert capabilities  
- Integrate auto emergency dialer for critical events  
- Offline mode & battery backup alerts  
- Expand maps/fire station database for rural areas

---

## 👨‍💻 Authors

**PyroSentrix Capstone Project**  
Capstone 2 — BS Information Technology  
Technological Institute of the Philippines (TIP)

Developed by:
- Cailo Nehru P. Ongsiako  
- Veronica Maxine D. Paragas  
- Jasper Casile

