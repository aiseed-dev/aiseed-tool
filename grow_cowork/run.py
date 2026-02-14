#!/usr/bin/env python3
"""Grow Desktop Server 起動スクリプト"""

import uvicorn

from app.config import PORT

if __name__ == "__main__":
    uvicorn.run("app.main:app", host="127.0.0.1", port=PORT, reload=True)
