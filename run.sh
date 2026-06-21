#!/bin/bash
# Build and run QuickNotes floating window app
cd "$(dirname "$0")/app"
swift build -c release 2>&1 && .build/release/QuickNotes
