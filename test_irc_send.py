#!/usr/bin/env python3
"""
Two-client IRC test: one receiver, one sender.
Receiver joins #global, sender sends messages, receiver should see them.
"""
import socket
import time
import threading
import sys

SERVER = "ceres.globalchat.org"
PORT = 6667
CHANNEL = "#global"
received_messages = []

def irc_connect(nick, user):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(10)
    s.connect((SERVER, PORT))
    s.send(f"NICK {nick}\r\n".encode())
    s.send(f"USER {user} 0 * :{user}\r\n".encode())
    time.sleep(1)
    # flush + PING
    s.settimeout(2)
    try:
        while True:
            data = s.recv(4096).decode(errors="replace")
            for line in data.strip().split("\r\n"):
                if line.startswith("PING"):
                    pong = line.split(" ", 1)[1] if " " in line else ""
                    s.send(f"PONG {pong}\r\n".encode())
    except socket.timeout:
        pass
    s.send(f"JOIN {CHANNEL}\r\n".encode())
    time.sleep(2)
    # flush join
    s.settimeout(2)
    try:
        while True:
            s.recv(4096)
    except socket.timeout:
        pass
    return s

def receiver_thread(s):
    """Listen for messages for 15 seconds"""
    s.settimeout(15)
    try:
        while True:
            data = s.recv(4096).decode(errors="replace")
            for line in data.strip().split("\r\n"):
                if "PRIVMSG" in line and "Receptor" not in line:
                    print(f"  🔵 RECV: {line}")
                    received_messages.append(line)
                elif line.startswith("PING"):
                    pong = line.split(" ", 1)[1] if " " in line else ""
                    s.send(f"PONG {pong}\r\n".encode())
    except socket.timeout:
        pass

print("=== Connecting RECEIVER ===")
recv_sock = irc_connect("Receptor", "Receptor")
t = threading.Thread(target=receiver_thread, args=(recv_sock,))
t.daemon = True
t.start()

time.sleep(1)

print("\n=== Connecting SENDER ===")
send_sock = irc_connect("Sender", "Sender")

time.sleep(1)

# TEST 1: Cloudinary URL
print(f"\n{'='*60}")
print("TEST 1: Cloudinary URL")
print(f"{'='*60}")
send_sock.send(f"PRIVMSG {CHANNEL} :https://res.cloudinary.com/dxwvhgy2r/image/upload/v1700000000/test-image.jpg\r\n".encode())
time.sleep(3)

# TEST 2: Caption + URL
print(f"\n{'='*60}")
print("TEST 2: Caption + Cloudinary URL")
print(f"{'='*60}")
send_sock.send(f"PRIVMSG {CHANNEL} :caption https://res.cloudinary.com/dxwvhgy2r/image/upload/v1700000000/test-image.jpg\r\n".encode())
time.sleep(3)

# TEST 3: Plain text (control)
print(f"\n{'='*60}")
print("TEST 3: Plain text control")
print(f"{'='*60}")
send_sock.send(f"PRIVMSG {CHANNEL} :Hello plain text test\r\n".encode())
time.sleep(3)

# TEST 4: URL with caption using newline (\x1E as in the webchat)
print(f"\n{'='*60}")
print("TEST 4: Caption + \\x1E separator + URL")
print(f"{'='*60}")
send_sock.send(f"PRIVMSG {CHANNEL} :caption\x1Ehttps://res.cloudinary.com/dxwvhgy2r/image/upload/v1700000000/test-image.jpg\r\n".encode())
time.sleep(3)

# Cleanup
print(f"\n{'='*60}")
print(f"SUMMARY: {len(received_messages)} messages received by Receiver")
for m in received_messages:
    print(f"  -> {m[:200]}")
print(f"{'='*60}")

send_sock.send(b"QUIT :bye\r\n")
time.sleep(0.5)
send_sock.close()
recv_sock.close()
print("Done.")
