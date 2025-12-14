from flask import Flask, request, jsonify
from flask_cors import CORS
import mysql.connector

app = Flask(__name__)
CORS(app)

# --- DATABASE ---
db = mysql.connector.connect(
    host="localhost",
    user="root",
    password="9744997775",
    database="mindgauge_db"
)

cursor = db.cursor(dictionary=True)

# --- LOGIN API ---
@app.post("/login")
def login():
    data = request.json
    email = data.get("email")
    password = data.get("password")

    cursor.execute(
        "SELECT * FROM users WHERE email=%s AND password=%s",
        (email, password)
    )
    user = cursor.fetchone()

    if user:
        return jsonify({
            "status": "success",
            "name": user["name"],
            "userId": user["id"],
            "age": user["age"],
            "location": user["location"]
        })

    return jsonify({"status": "fail"}), 401

# --- REGISTER API ---
@app.post("/register")
def register():
    data = request.json

    name = data.get("name")
    email = data.get("email")
    password = data.get("password")
    age = data.get("age")
    location = data.get("location")

    try:
        cursor.execute(
            """
            INSERT INTO users (name, email, password, age, location)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (name, email, password, age, location)
        )
        db.commit()
        return jsonify({"status": "success"}), 201

    except mysql.connector.IntegrityError:
        return jsonify({"status": "email_exists"}), 409

if __name__ == "__main__":
    app.run(debug=True)
