#!/bin/bash

echo "=========================================="
echo "  PX4 SITL Diagnostic"
echo "=========================================="
echo ""

PX4_DIR="${PX4_DIR:-$HOME/workspace/PX4-Autopilot}"

echo "1. Checking PX4 directory..."
if [ ! -d "$PX4_DIR" ]; then
    echo "   ✗ PX4 directory not found: $PX4_DIR"
    exit 1
fi
echo "   ✓ Found: $PX4_DIR"

echo ""
echo "2. Checking PX4 build..."
if [ ! -f "$PX4_DIR/build/px4_sitl_default/bin/px4" ]; then
    echo "   ✗ PX4 binary not found"
    echo "   Run: cd $PX4_DIR && make px4_sitl_default"
    exit 1
fi
echo "   ✓ Binary exists"

echo ""
echo "3. Testing PX4 startup..."
cd "$PX4_DIR"

# Try to start PX4 with minimal config
echo "   Starting PX4 with no scripts..."
timeout 10 ./build/px4_sitl_default/bin/px4 -d 2>&1 | head -20

echo ""
echo "4. Checking for ROMFS..."
if [ -d "$PX4_DIR/ROMFS" ]; then
    echo "   ✓ ROMFS directory exists"
    ls -la "$PX4_DIR/ROMFS/px4fmu_common/init.d-posix/" | head -10
else
    echo "   ✗ ROMFS directory not found"
fi

echo ""
echo "5. Checking build modules..."
if [ -d "$PX4_DIR/build/px4_sitl_default/bin" ]; then
    echo "   Modules in build/px4_sitl_default/bin:"
    ls "$PX4_DIR/build/px4_sitl_default/bin" | head -20
else
    echo "   ✗ Build bin directory not found"
fi

echo ""
echo "6. Test MAVLink standalone (no sim)..."
cd "$PX4_DIR"
echo "   Launching PX4 in standalone mode for 15 seconds..."
timeout 15 ./build/px4_sitl_default/bin/px4 -d \
    -s ROMFS/px4fmu_common/init.d-posix/10040 \
    > /tmp/px4_test.log 2>&1 &

PID=$!
sleep 10

if kill -0 $PID 2>/dev/null; then
    echo "   ✓ PX4 is running (PID: $PID)"
    kill $PID 2>/dev/null
    wait $PID 2>/dev/null
else
    echo "   ✗ PX4 stopped"
fi

echo ""
echo "Log output:"
cat /tmp/px4_test.log | head -50

echo ""
echo "=========================================="
echo "Diagnostic complete"
echo "=========================================="
