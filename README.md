# 🔥 PyroSentrix  
Mobile Application with Multi-Sensor Internet of Things (IoT) Device for Smoke and Heat Detection Using Long Short-Term Memory (LSTM)


---

## 🚀 Project Overview

**PyroSentrix** is a smart fire monitoring system that integrates a multi-sensor IoT device with a mobile application, enhanced by machine learning (LSTM). The system is designed to **advance traditional fire alarm systems** by providing **real-time sensor data, intelligent early warnings, and user-friendly mobile monitoring** — reducing fire-related risks before they escalate

---

## 🎯 Objectives

- Improve fire detection accuracy and responsiveness
- Provide predictive fire risk alerts using LSTM
- Enable mobile monitoring of real-time sensor data
- Assist in proactive decision-making through smart insights and data visualizations

---

## 📦 Key Features

### 📊 LSTM Integration
- Trained on **60,000 rows** of sensor data using Python in Google Colab.
- Analyzed sensor data to identify upward trends indicating rising sensor values.
- Deployed using **Google Cloud Platform (GCP)**
- Powered by data collected from the IoT device and stored in **BigQuery**
- Predicts sensor value trends to generate **early warning notifications** before critical levels are reached
- Achieved **85% R² score** on test data
  

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
- **Data Visualization & Insights**  
  - Built-in dashboard with user-friendly visualizations and analytics
- **Alarm Notification**  
  - Sounds an alarm on both the device and mobile app  
  - Captures and displays the image from the IoT device
  - Shows a popup for what sensor is triggered, image captured, and call button to call the nearest firestation
- **Smart Prediction Alerts (LSTM-based)**  
  - LSTM model trained on 60,000+ real sensor data (R² score: **83%**)  
  - Predicts **rising trends in sensor data** to alert users *before* danger thresholds are reached
- **Fire Station Locator**  
  - Uses **Google Maps API** to fetch contact info for the **4 nearest fire stations** based on user location
- **Alarm History**  
  - Saves past incident logs and alarm triggers
- **Device Controls**  
  - Remotely **reset** or **hush** the alarm from the mobile app
- **Household Sharing**  
  - Owners can **invite household members** to monitor the device from their own phones
    
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

## 👨‍💻 Developers

**PyroSentrix Capstone Project**  
Capstone 2 — BS Information Technology  
Technological Institute of the Philippines (TIP)

Developed by:
- Cailo Nehru P. Ongsiako  
- Veronica Maxine D. Paragas  
- Jasper Casile

