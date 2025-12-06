from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)   # allow Flutter web + mobile

# --- LOGIN API ---
@app.post("/login")
def login():
    data = request.json
    email = data.get("email")
    password = data.get("password")

    # simple example
    if email == "test@gmail.com" and password == "1234":
        return jsonify({
            "status": "success",
            "name": "Basith",
            "userId": "user-1234"
        })
    return jsonify({"status": "fail"}), 401


# --- REGISTER API ---
@app.post("/register")
def register():
    data = request.json
    # save to database here (MySQL)
    return jsonify({"status": "success"}), 201


# Run server
if __name__ == "__main__":
    app.run(debug=True)
