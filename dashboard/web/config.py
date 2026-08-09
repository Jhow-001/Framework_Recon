import os

ROOT_DIR = os.environ.get(
    "ROOT_DIR",
    os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")),
)
RESULTS_DIR = os.path.join(ROOT_DIR, "results")
POLL_SECONDS = 2
WS_WATCH_INTERVAL = 1.0
HOST = "127.0.0.1"
PORT = 8080
DEBUG = False
