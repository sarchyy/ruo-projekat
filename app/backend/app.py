import os

import psycopg2
from flask import Flask, jsonify

app = Flask(__name__)


def veza():
    # parametri dolaze iz okoline (compose / .env), nikad iz koda
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        connect_timeout=3,
    )


@app.get("/api/posjete")
def posjete():
    conn = veza()
    try:
        with conn, conn.cursor() as cur:
            cur.execute(
                "CREATE TABLE IF NOT EXISTS posjete ("
                "id serial PRIMARY KEY, vrijeme timestamptz DEFAULT now())"
            )
            cur.execute("INSERT INTO posjete DEFAULT VALUES")
            cur.execute("SELECT count(*) FROM posjete")
            broj = cur.fetchone()[0]
    finally:
        conn.close()
    return jsonify(posjete=broj)


@app.get("/health")
def health():
    return "ok\n"
